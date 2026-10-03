//
// class Channel {
//   final String name;
//   final String logoUrl;
//   final String streamUrl;
//   final Map<String, String>? httpHeaders;
//   final String? drmLicenseKey; // "kid:key" hex string, or null
//   final bool isDash;
//
//   const Channel({
//     required this.name,
//     required this.logoUrl,
//     required this.streamUrl,
//     this.httpHeaders,
//     this.drmLicenseKey,
//     this.isDash = false,
//   });
// }

////////////////////////////////////////////////////////


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

  /// Text shown on screen.
  String get displayId => (tvgId == null || tvgId!.isEmpty) ? 'No ID' : tvgId!;
  String get displayGroup =>
      (groupTitle == null || groupTitle!.isEmpty) ? 'No Group' : groupTitle!;
}