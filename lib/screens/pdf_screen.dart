import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../glass.dart';
import '../media_links.dart';
import '../theme.dart';
import '../widgets.dart';

/// Shows a lecture's PDF inside the app.
///  - Zoom with the + and - buttons or by pinching.
///  - Drag the handle on the right edge to scroll fast.
///  - Download it, or open it in another app (Drive PDF viewer, browser...).
/// Works with a direct .pdf link and a Google Drive share link.
class PdfScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final int lectureId;
  const PdfScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lectureId,
  });

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  static const double _renderWidth = 1400; // pixels each page is drawn at
  static const double _minZoom = 1.0;
  static const double _maxZoom = 5.0;
  static const double _gap = 8;
  static const double _thumbHeight = 56;

  PdfDocument? _doc;
  Uint8List? _bytes;
  String? _error;
  String? _openUrl; // the original link
  int _pages = 0;
  double _aspect = 1 / 1.414; // page width / height, taken from page 1

  double _zoom = 1.0;
  double _baseZoom = 1.0;
  int _pointers = 0;

  final _scroll = ScrollController();
  final _hScroll = ScrollController();
  final _tick = ValueNotifier<int>(0); // asks the handle to redraw
  final _images = <int, Uint8List>{};
  final _requested = <int>{};
  Future<void> _queue = Future.value(); // pages are drawn one at a time

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    _tick.dispose();
    _doc?.close();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---------------- loading ----------------
  Future<void> _load() async {
    setState(() {
      _error = null;
      _doc?.close();
      _doc = null;
      _images.clear();
      _requested.clear();
      _queue = Future.value();
      _zoom = 1.0;
    });
    try {
      final src = await Api.playSource(widget.lectureId, 'pdf');
      _openUrl = src.url;
      final r = await http
          .get(Uri.parse(directPdfUrl(src.url)), headers: src.headers)
          .timeout(const Duration(seconds: 90));
      final Uint8List bytes = r.bodyBytes;
      // Every PDF starts with "%PDF". Anything else is a web page, not a file.
      final isPdf = r.statusCode == 200 &&
          bytes.length > 4 &&
          bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
      if (!isPdf) {
        if (mounted) {
          setState(() => _error = 'This link is not a direct PDF file, so it cannot be shown here.');
        }
        return;
      }
      final doc = await PdfDocument.openData(bytes);
      final first = await doc.getPage(1);
      final aspect = first.width / first.height;
      await first.close();
      if (!mounted) {
        doc.close();
        return;
      }
      setState(() {
        _bytes = bytes;
        _doc = doc;
        _pages = doc.pagesCount;
        _aspect = aspect;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this PDF. Check your internet and try again.');
    }
  }

  /// Draws one page to an image. Pages are drawn one after another because the
  /// phone's PDF engine can only keep one page open at a time.
  void _ensure(int number) {
    if (number < 1 || number > _pages || !_requested.add(number)) return;
    _queue = _queue.then((_) async {
      final doc = _doc;
      if (doc == null) return;
      try {
        final page = await doc.getPage(number);
        try {
          final h = _renderWidth * page.height / page.width;
          final img = await page.render(
            width: _renderWidth,
            height: h,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 85,
          );
          if (img != null && mounted && identical(doc, _doc)) {
            setState(() => _images[number] = img.bytes);
          }
        } finally {
          await page.close();
        }
      } catch (_) {
        _requested.remove(number); // try again when it scrolls into view
      }
    });
  }

  // ---------------- zoom ----------------
  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() < 0.001) return;
    final ratio = next / _zoom;
    final offset = _scroll.hasClients ? _scroll.offset * ratio : 0.0;
    setState(() => _zoom = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent).toDouble());
      }
      if (_hScroll.hasClients) {
        _hScroll.jumpTo(
            next <= 1.001 ? 0.0 : _hScroll.offset.clamp(0.0, _hScroll.position.maxScrollExtent).toDouble());
      }
      _tick.value++;
    });
  }

  // ---------------- download / open ----------------
  String get _fileName {
    final clean = widget.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]+'), '').trim();
    return '${clean.isEmpty ? 'lecture' : clean}.pdf';
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(data: bytes, fileName: _fileName),
      );
      if (mounted) _toast(saved == null ? 'Download cancelled.' : 'PDF saved.');
    } catch (_) {
      if (mounted) _toast('Could not save the PDF.');
    }
  }

  Future<void> _openInApp() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/itachi_lecture.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final r = await OpenFilex.open(file.path, type: 'application/pdf');
      if (r.type != ResultType.done && mounted) {
        _toast('No PDF app found. Try "Open link in browser".');
      }
    } catch (_) {
      if (mounted) _toast('Could not open the PDF in another app.');
    }
  }

  Future<void> _openInBrowser() async {
    final url = _openUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _toast('Could not open the browser.');
    }
  }

  // ---------------- UI ----------------
  Widget _toolbar(AppPalette p) {
    final ready = _bytes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: ready ? _download : null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Open in',
            enabled: _openUrl != null,
            onSelected: (v) => v == 'app' ? _openInApp() : _openInBrowser(),
            itemBuilder: (_) => [
              if (ready)
                const PopupMenuItem(value: 'app', child: Text('Open in PDF app (Drive viewer...)')),
              const PopupMenuItem(value: 'browser', child: Text('Open link in browser')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 20),
                  SizedBox(width: 6),
                  Text('Open in', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewer(AppPalette p) {
    return LayoutBuilder(builder: (context, box) {
      final pageWidth = box.maxWidth * _zoom;
      final tileHeight = pageWidth / _aspect + _gap;

      return Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              _pointers++;
              if (_pointers == 2) setState(() {});
            },
            onPointerUp: (_) {
              _pointers = (_pointers - 1).clamp(0, 10);
              if (_pointers < 2) setState(() {});
            },
            onPointerCancel: (_) {
              _pointers = (_pointers - 1).clamp(0, 10);
              if (_pointers < 2) setState(() {});
            },
            child: GestureDetector(
              onScaleStart: (_) => _baseZoom = _zoom,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) _setZoom(_baseZoom * d.scale);
              },
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                physics: (_zoom > 1.001 && _pointers < 2)
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: pageWidth,
                  height: box.maxHeight,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _tick.value++;
                      });
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      physics: _pointers >= 2
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      cacheExtent: box.maxHeight,
                      itemCount: _pages,
                      itemBuilder: (_, i) {
                        final number = i + 1;
                        _ensure(number);
                        _ensure(number + 1);
                        final img = _images[number];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: _gap),
                          child: SizedBox(
                            width: pageWidth,
                            height: pageWidth / _aspect,
                            child: img != null
                                ? Image.memory(img, fit: BoxFit.fill, gaplessPlayback: true)
                                : ColoredBox(
                                    color: Colors.white,
                                    child: Center(
                                      child: SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: p.textDim),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Drag this handle to scroll quickly.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 34,
            child: LayoutBuilder(builder: (context, hb) {
              return ListenableBuilder(
                listenable: Listenable.merge([_scroll, _tick]),
                builder: (context, _) {
                  if (!_scroll.hasClients) return const SizedBox.shrink();
                  final max = _scroll.position.maxScrollExtent;
                  if (max <= 0) return const SizedBox.shrink();
                  final track = hb.maxHeight - _thumbHeight;
                  final top = (_scroll.offset / max).clamp(0.0, 1.0) * track;
                  return Stack(
                    children: [
                      Positioned(
                        top: top,
                        right: 4,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (d) {
                            final next = _scroll.offset + d.delta.dy * max / track;
                            _scroll.jumpTo(next.clamp(0.0, max).toDouble());
                          },
                          child: Container(
                            width: 28,
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xCC5B5BFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.unfold_more_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }),
          ),

          // Page number
          Positioned(
            left: 14,
            bottom: 18,
            child: ListenableBuilder(
              listenable: Listenable.merge([_scroll, _tick]),
              builder: (context, _) {
                final off = _scroll.hasClients ? _scroll.offset : 0.0;
                final page = ((off + box.maxHeight / 2) / tileHeight).floor() + 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${page.clamp(1, _pages)} / $_pages',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                );
              },
            ),
          ),

          // Zoom buttons
          Positioned(
            right: 44,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    color: Colors.white,
                    onPressed: _zoom > _minZoom + 0.001 ? () => _setZoom(_zoom / 1.25) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text('${(_zoom * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  IconButton(
                    tooltip: 'Zoom in',
                    color: Colors.white,
                    onPressed: _zoom < _maxZoom - 0.001 ? () => _setZoom(_zoom * 1.25) : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: BackHeader(caption: widget.subtitle, title: widget.title),
            ),
            _toolbar(p),
            Expanded(
              child: _doc != null
                  ? _viewer(p)
                  : Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: p.textDim, height: 1.5)),
                                  const SizedBox(height: 14),
                                  OutlinedButton(onPressed: _load, child: const Text('Try again')),
                                ],
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
