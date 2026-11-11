/// Helpers that look at a link and decide how the app should open it.

final _ytId = RegExp(r'^[A-Za-z0-9_-]{11}$');

String? _valid(String? id) => (id != null && _ytId.hasMatch(id)) ? id : null;

/// The 11-character video id when [url] is a YouTube link, otherwise null.
/// Works for watch?v=, youtu.be/, /shorts/, /embed/, /live/ and m.youtube.com.
String? youtubeId(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return null;
  final host = u.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
  final seg = u.pathSegments;
  if (host == 'youtu.be') return seg.isEmpty ? null : _valid(seg.first);
  if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    if (u.path == '/watch') return _valid(u.queryParameters['v']);
    if (seg.length >= 2 && const ['shorts', 'embed', 'live', 'v'].contains(seg[0])) {
      return _valid(seg[1]);
    }
  }
  return null;
}

/// Turns a Google Drive "share" link into a direct download link.
/// Any other link is returned unchanged.
String directPdfUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.host.toLowerCase().endsWith('drive.google.com')) return url;
  final m = RegExp(r'/file/d/([A-Za-z0-9_-]+)').firstMatch(u.path);
  final id = m?.group(1) ?? u.queryParameters['id'];
  if (id == null) return url;
  return 'https://drive.google.com/uc?export=download&id=$id';
}
