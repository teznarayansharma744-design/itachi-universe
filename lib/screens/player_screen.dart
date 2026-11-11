import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../data.dart';
import '../glass.dart';
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
