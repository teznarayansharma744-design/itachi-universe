import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../api.dart';
import '../data.dart';
import '../glass.dart';
import '../media_links.dart';
import '../theme.dart';
import '../widgets.dart';

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// Opens the player for a lecture. First asks the server where the video is
/// (and whether this student may watch it), then shows the player.
class PlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  /// Server id of the lecture. Null plays the built-in sample video.
  final int? lectureId;
  const PlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.lectureId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerLoaderState();
}

class _PlayerLoaderState extends State<PlayerScreen> {
  late Future<PlaySource> _source = _resolve();

  Future<PlaySource> _resolve() async {
    final id = widget.lectureId;
    if (id == null || !Api.isConfigured) {
      return const PlaySource(sampleVideoUrl, {});
    }
    return Api.playSource(id, 'video');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlaySource>(
      future: _source,
      builder: (context, snap) {
        if (snap.hasData) {
          final yt = youtubeId(snap.data!.url);
          if (yt != null) {
            return _YoutubeView(title: widget.title, subtitle: widget.subtitle, videoId: yt);
          }
          return _PlayerView(
            title: widget.title,
            subtitle: widget.subtitle,
            source: snap.data!,
          );
        }
        final p = AppPalette.of(context);
        return Scaffold(
          body: GlassBackground(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackHeader(caption: widget.subtitle, title: widget.title),
                  Expanded(
                    child: Center(
                      child: snap.hasError
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  snap.error is ApiException
                                      ? (snap.error as ApiException).message
                                      : 'Could not load this video.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: p.textDim, height: 1.5),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: () => setState(() => _source = _resolve()),
                                  child: const Text('Try again'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerView extends StatefulWidget {
  final String title;
  final String subtitle;
  final PlaySource source;
  const _PlayerView({
    required this.title,
    required this.subtitle,
    required this.source,
  });

  @override
  State<_PlayerView> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_PlayerView> {
  late final VideoPlayerController _c;
  Timer? _hideTimer;
  Timer? _flashTimer;
  bool _showControls = true;
  Offset _lastTap = Offset.zero;
  double _width = 1;
  double _speed = 1.0;
  double _volume = 1.0;
  String? _flash;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(
      Uri.parse(widget.source.url),
      httpHeaders: widget.source.headers,
    );
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _c.play();
      _scheduleHide();
    });
  }

  @override
  void dispose() {
    // Always leave the player in normal portrait mode with system bars back.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
    _flashTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _showFlash(String text) {
    _flashTimer?.cancel();
    setState(() => _flash = text);
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _seekBy(int seconds) async {
    final pos = _c.value.position;
    final total = _c.value.duration;
    var target = pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    await _c.seekTo(target);
  }

  void _togglePlay() {
    _c.value.isPlaying ? _c.pause() : _c.play();
    _scheduleHide();
  }

  /// Switch between vertical (portrait) and horizontal (fullscreen) playback.
  Future<void> _setFullscreen(bool full) async {
    if (full) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (mounted) {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    // Horizontal: the video fills the whole screen. Back press exits fullscreen first.
    if (landscape) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setFullscreen(false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildVideo(context),
        ),
      );
    }

    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: _buildVideo(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF19C3B1))),
                  const SizedBox(height: 6),
                  Text(widget.title,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    for (final (i, label) in ['Video', 'PDF', 'Notes'].indexed)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tab == i ? p.text.withAlpha(40) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _tab == i ? FontWeight.w600 : FontWeight.w500,
                                    color: _tab == i ? p.text : p.textDim)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: GlassCard(
                  radius: 24,
                  child: SizedBox.expand(
                    child: Center(
                      child: Text(
                        switch (_tab) {
                          0 => 'Double tap left or right to skip 10 seconds.\nSwipe up or down on the right side for volume.\nHold anywhere for 2x speed.',
                          1 => 'The PDF for this lecture will open here, right below the video. (Next step)',
                          _ => 'Your notes for this lecture will appear here. (Next step)',
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.6, color: p.textDim),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _width = cons.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (d) => _lastTap = d.localPosition,
        onDoubleTap: () {
          final left = _lastTap.dx < _width / 2;
          _seekBy(left ? -10 : 10);
          _showFlash(left ? '-10 s' : '+10 s');
        },
        onLongPressStart: (_) {
          _c.setPlaybackSpeed(2.0);
          _showFlash('2x speed');
        },
        onLongPressEnd: (_) => _c.setPlaybackSpeed(_speed),
        onVerticalDragUpdate: (d) {
          // Right half = volume. (Left half = brightness, added later.)
          if (d.localPosition.dx > _width / 2) {
            _volume = (_volume - d.delta.dy / 200).clamp(0.0, 1.0);
            _c.setVolume(_volume);
            _showFlash('Volume ${(_volume * 100).round()}%');
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Center(
              child: _c.value.hasError
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'This video cannot play right now.\nYour key may have expired, or the server is waking up. Go back and try again in a minute.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    )
                  : _c.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _c.value.aspectRatio,
                          child: VideoPlayer(_c),
                        )
                      : const CircularProgressIndicator(),
            ),
            if (_c.value.isInitialized && _c.value.isBuffering)
              const Center(child: CircularProgressIndicator(strokeWidth: 3)),
            Center(
              child: AnimatedOpacity(
                opacity: _flash == null ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_flash ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(ignoring: !_showControls, child: _controls(context)),
            ),
          ],
        ),
      );
    });
  }

  Widget _controls(BuildContext context) {
    final playing = _c.value.isPlaying;
    return Container(
      color: Colors.black26,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  color: Colors.white,
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  onSelected: (v) {
                    setState(() => _speed = v);
                    _c.setPlaybackSpeed(v);
                  },
                  itemBuilder: (_) => [
                    for (final v in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      PopupMenuItem(value: v, child: Text('${v}x')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_speed}x',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                iconSize: 34,
                color: Colors.white,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () => _seekBy(-10),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                iconSize: 48,
                color: Colors.white,
                icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Forward 10 seconds',
                iconSize: 34,
                color: Colors.white,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () => _seekBy(10),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Text(_fmt(_c.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(width: 10),
                Expanded(
                  child: VideoProgressIndicator(
                    _c,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF5B5BFF),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_fmt(_c.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: MediaQuery.orientationOf(context) == Orientation.landscape
                      ? 'Exit fullscreen'
                      : 'Fullscreen (horizontal)',
                  color: Colors.white,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(MediaQuery.orientationOf(context) == Orientation.landscape
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded),
                  onPressed: () => _setFullscreen(
                      MediaQuery.orientationOf(context) != Orientation.landscape),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// YouTube page that we load into a WebView. YouTube's own controls are switched off.
/// A transparent shield catches every touch so nothing of YouTube can be tapped, and
/// black covers hide YouTube's title bar, copy-link button, logo and big play button
/// while the video is not playing. Our own controls sit below the video in Flutter.
String _youtubeHtml(String videoId) => """
<!doctype html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
html,body{margin:0;height:100%;background:#000;overflow:hidden;-webkit-tap-highlight-color:transparent}
#player{position:absolute;left:0;top:0;width:100%;height:100%;border:0}
#shield{position:absolute;left:0;top:0;right:0;bottom:0;z-index:5}
.cover{position:absolute;left:0;right:0;background:#000;z-index:6;display:none;pointer-events:none}
body.cv .cover{display:block}
#top{top:0;height:17%}
#bottom{bottom:0;height:17%}
#mid{left:50%;top:50%;right:auto;width:84px;height:84px;margin:-42px 0 0 -42px;border-radius:50%;background:#000;opacity:.78}
#mid:after{content:"";position:absolute;left:33px;top:24px;border-style:solid;border-width:18px 0 18px 30px;border-color:transparent transparent transparent #fff}
#ttl{position:absolute;left:14px;right:14px;top:0;bottom:0;color:#fff;font:600 14px/1 sans-serif;display:flex;align-items:center;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
#flash{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);background:rgba(0,0,0,.7);color:#fff;padding:8px 14px;border-radius:14px;font:600 14px sans-serif;display:none;z-index:9}
</style></head><body class="cv">
<div id="player"></div>
<div id="shield"></div>
<div id="top" class="cover"><div id="ttl"></div></div>
<div id="bottom" class="cover"></div>
<div id="mid" class="cover"></div>
<div id="flash"></div>
<script>
var player=null, ready=false, tapTimer=null, flashTimer=null;
function post(o){try{Itachi.postMessage(JSON.stringify(o));}catch(e){}}
function setCovers(on){document.body.className=on?'cv':'';}
function setTitle(t){document.getElementById('ttl').textContent=t;}
function flash(t){var f=document.getElementById('flash');f.textContent=t;f.style.display='block';clearTimeout(flashTimer);flashTimer=setTimeout(function(){f.style.display='none';},700);}
function onYouTubeIframeAPIReady(){
  player=new YT.Player('player',{
    videoId:'$videoId',
    host:'https://www.youtube-nocookie.com',
    width:'100%',height:'100%',
    playerVars:{autoplay:1,controls:0,playsinline:1,rel:0,fs:0,disablekb:1,iv_load_policy:3,modestbranding:1,cc_load_policy:0,origin:'https://www.youtube-nocookie.com'},
    events:{
      onReady:function(){ready=true;post({t:'ready'});try{player.playVideo();}catch(e){}},
      onStateChange:function(e){post({t:'state',s:e.data});},
      onError:function(e){post({t:'error',c:e.data});}
    }
  });
}
setInterval(function(){
  if(ready&&player&&player.getCurrentTime){
    post({t:'time',p:player.getCurrentTime(),d:player.getDuration()});
  }
},500);
document.getElementById('shield').addEventListener('click',function(e){
  var x=e.clientX/window.innerWidth;
  if(tapTimer){clearTimeout(tapTimer);tapTimer=null;post({t:'dbl',x:x});}
  else{tapTimer=setTimeout(function(){tapTimer=null;post({t:'tap',x:x});},260);}
});
var tag=document.createElement('script');tag.src='https://www.youtube.com/iframe_api';document.head.appendChild(tag);
</script></body></html>
""";

/// Plays a YouTube link in our own player. Controls are ours and sit below the video.
class _YoutubeView extends StatefulWidget {
  final String title;
  final String subtitle;
  final String videoId;
  const _YoutubeView({required this.title, required this.subtitle, required this.videoId});

  @override
  State<_YoutubeView> createState() => _YoutubeViewState();
}

class _YoutubeViewState extends State<_YoutubeView> {
  static const _base = 'https://www.youtube-nocookie.com';
  late final WebViewController _web;

  int _state = -1; // YouTube: -1 not started, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  double? _drag; // slider value while the finger is on it
  double _speed = 1.0;
  bool _full = false;
  int? _error;
  Timer? _coverTimer;

  bool get _playing => _state == 1;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel('Itachi', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        // Stay on the video: no link inside the page may open another page.
        onNavigationRequest: (r) => (!r.isMainFrame || r.url.startsWith(_base) || r.url == 'about:blank')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
    _start();
  }

  Future<void> _start() async {
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    await _web.loadHtmlString(_youtubeHtml(widget.videoId), baseUrl: _base);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _coverTimer?.cancel();
    super.dispose();
  }

  // ---------- talking to the page ----------
  void _js(String code) => _web.runJavaScript(code);

  void _setCovers(bool on) => _js('setCovers(${on ? 'true' : 'false'})');

  void _onMessage(String raw) {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['t']) {
      case 'ready':
        _js('setTitle(${jsonEncode(widget.title)})');
      case 'state':
        final s = (m['s'] as num).toInt();
        _coverTimer?.cancel();
        if (s == 1) {
          // YouTube shows its title for a few seconds when playback starts. Keep covered.
          _coverTimer = Timer(const Duration(seconds: 5), () => _setCovers(false));
        } else if (s != 3) {
          _setCovers(true);
        }
        if (mounted) setState(() => _state = s);
      case 'time':
        if (_drag != null || !mounted) return;
        setState(() {
          _pos = Duration(milliseconds: ((m['p'] as num) * 1000).round());
          final d = (m['d'] as num?) ?? 0;
          if (d > 0) _dur = Duration(milliseconds: (d * 1000).round());
        });
      case 'tap':
        _togglePlay();
      case 'dbl':
        final x = (m['x'] as num).toDouble();
        if (x < 0.35) {
          _seekBy(-10);
        } else if (x > 0.65) {
          _seekBy(10);
        } else {
          _togglePlay();
        }
      case 'error':
        if (mounted) setState(() => _error = (m['c'] as num).toInt());
    }
  }

  // ---------- actions ----------
  void _togglePlay() => _js(_playing ? 'player.pauseVideo()' : 'player.playVideo()');

  void _seekBy(int seconds) {
    var t = _pos + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (_dur > Duration.zero && t > _dur) t = _dur;
    setState(() => _pos = t);
    _js('player.seekTo(${t.inMilliseconds / 1000.0}, true); flash("${seconds > 0 ? '+' : ''}$seconds s")');
  }

  void _setSpeed(double v) {
    setState(() => _speed = v);
    _js('player.setPlaybackRate($v)');
  }

  Future<void> _setFullscreen(bool full) async {
    if (full) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (mounted) setState(() => _full = full);
  }

  // ---------- UI ----------
  Widget _controls(AppPalette p) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'This video cannot be played here. Its owner may have turned off embedding, or it is private.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textDim, height: 1.5),
        ),
      );
    }
    final totalMs = _dur.inMilliseconds;
    final value = _drag ?? (totalMs <= 0 ? 0.0 : (_pos.inMilliseconds / totalMs).clamp(0.0, 1.0));
    final shownPos = _drag == null ? _pos : Duration(milliseconds: (totalMs * _drag!).round());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_fmt(shownPos), style: TextStyle(fontSize: 12, color: p.textDim)),
              Expanded(
                child: Slider(
                  value: value,
                  onChanged: totalMs <= 0 ? null : (v) => setState(() => _drag = v),
                  onChangeEnd: totalMs <= 0
                      ? null
                      : (v) {
                          final t = Duration(milliseconds: (totalMs * v).round());
                          setState(() {
                            _pos = t;
                            _drag = null;
                          });
                          _js('player.seekTo(${t.inMilliseconds / 1000.0}, true)');
                        },
                ),
              ),
              Text(_fmt(_dur), style: TextStyle(fontSize: 12, color: p.textDim)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<double>(
                tooltip: 'Speed',
                initialValue: _speed,
                onSelected: _setSpeed,
                itemBuilder: (_) => [
                  for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: v, child: Text('${v}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('${_speed}x', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    iconSize: 32,
                    onPressed: () => _seekBy(-10),
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton(
                    iconSize: 54,
                    onPressed: _togglePlay,
                    icon: _state == 3
                        ? const SizedBox(
                            width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3))
                        : Icon(_playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                  ),
                  IconButton(
                    iconSize: 32,
                    onPressed: () => _seekBy(10),
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _setFullscreen(!_full),
                icon: Icon(_full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: !_full,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFullscreen(false);
      },
      child: Scaffold(
        body: GlassBackground(
          child: Column(
            children: [
              // Offstage keeps the page alive when the header is hidden in fullscreen.
              Offstage(
                offstage: _full,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: BackHeader(caption: widget.subtitle, title: widget.title),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1.0, // the controls sit right under the video
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WebViewWidget(controller: _web),
                  ),
                ),
              ),
              _controls(p),
            ],
          ),
        ),
      ),
    );
  }
}
