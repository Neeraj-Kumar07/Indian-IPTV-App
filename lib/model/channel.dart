// class Channel {
//   final String name;
//   final String logoUrl;
//   final String streamUrl;
//
//   Channel({required this.name, required this.logoUrl, required this.streamUrl});
// }
/////////////////////////////////////////
// class Channel {
//   final String name;
//   final String logoUrl;
//   final String streamUrl;
//   final Map<String, String>? httpHeaders;
//   final String? drmLicenseKey; // "kid:key" hex string, or null
//   final bool isDash;
//
//   Channel({
//     required this.name,
//     required this.logoUrl,
//     required this.streamUrl,
//     this.httpHeaders,
//     this.drmLicenseKey,
//     this.isDash = false,
//   });
// }
/////////////////////////////////////////



class Channel {
  final String name;
  final String logoUrl;
  final String streamUrl;
  final Map<String, String>? httpHeaders;
  final String? drmLicenseKey; // "kid:key" hex string, or null
  final bool isDash;

  const Channel({
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    this.httpHeaders,
    this.drmLicenseKey,
    this.isDash = false,
  });
}