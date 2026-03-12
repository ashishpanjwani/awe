// Platform-aware browser detection.
// On web: detects common in-app browsers that block Google OAuth (disallowed_useragent).
// On mobile/desktop: returns safe defaults.

export './browser_info_stub.dart' if (dart.library.html) './browser_info_web.dart';
