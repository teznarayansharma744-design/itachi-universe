import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../glass.dart';
import '../media_links.dart';
import '../theme.dart';
import '../widgets.dart';

/// Opens a lecture's PDF inside the app.
/// Works with a direct .pdf link and with a Google Drive share link. If the link turns
/// out to be a normal web page, it offers to open it in the browser instead.
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
  PdfControllerPinch? _controller;
  String? _error;
  String? _openUrl; // the original link, for "Open in browser"

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
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
      final c = PdfControllerPinch(document: PdfDocument.openData(bytes));
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => _controller = c);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this PDF. Check your internet and try again.');
    }
  }

  Future<void> _openInBrowser() async {
    final url = _openUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: BackHeader(caption: widget.subtitle, title: widget.title),
              ),
              Expanded(
                child: _controller != null
                    ? PdfViewPinch(controller: _controller!)
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
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        OutlinedButton(onPressed: _load, child: const Text('Try again')),
                                        if (_openUrl != null)
                                          FilledButton(
                                              onPressed: _openInBrowser,
                                              child: const Text('Open in browser')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
