


// class Channel {
//   final String name;
//   final String logoUrl;
//   final String streamUrl;
//   final Map<String, String>? httpHeaders;
//   final String? drmLicenseKey; // "kid:key" hex string, or null
//   final bool isDash;
//
//   /// From tvg-id (falls back to tvg-chno). Null when the playlist has neither.
//   final String? tvgId;
//
//   /// From group-title. Null when the playlist has none.
//   final String? groupTitle;
//
//   const Channel({
//     required this.name,
//     required this.logoUrl,
//     required this.streamUrl,
//     this.httpHeaders,
//     this.drmLicenseKey,
//     this.isDash = false,
//     this.tvgId,
//     this.groupTitle,
//   });
//
//   /// Text shown on screen.
//   String get displayId => (tvgId == null || tvgId!.isEmpty) ? 'No ID' : tvgId!;
//   String get displayGroup =>
//       (groupTitle == null || groupTitle!.isEmpty) ? 'No Group' : groupTitle!;
// }
////////////////////////////////////////////////

class Channel {
  final String name;
  final String logoUrl;
  final String streamUrl;
  final Map<String, String>? httpHeaders;
  final String? drmLicenseKey; // "kid:key" hex string, or null
  final bool isDash;

  /// From tvg-id (falls back to tvg-chno). Null when the playlist has neither.
  final String? tvgId;

  /// From group-title. Null when the playlist has none.
  final String? groupTitle;

  const Channel({
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    this.httpHeaders,
    this.drmLicenseKey,
    this.isDash = false,
    this.tvgId,
    this.groupTitle,
  });

  /// Cleaned name for the UI. [name] is already the text after the comma in
  /// the #EXTINF line (the provider extracts it), so here we only:
  ///  1. remove anything after a '|'   ("DD News | GmaxHub" -> "DD News")
  ///  2. remove anything in parentheses ("Aaj Tak HD (1080p)" -> "Aaj Tak HD")
  String get displayName {
    var n = name;

    final pipe = n.indexOf('|');
    if (pipe != -1) n = n.substring(0, pipe);

    n = n.replaceAll(RegExp(r'\([^)]*\)'), '');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();

    return n.isEmpty ? name.trim() : n;
  }

  /// Text shown on screen.
  String get displayId => (tvgId == null || tvgId!.isEmpty) ? 'No ID' : tvgId!;
  String get displayGroup =>
      (groupTitle == null || groupTitle!.isEmpty) ? 'No Group' : groupTitle!;
}