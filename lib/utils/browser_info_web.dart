// Web implementation: detect in-app browsers via user-agent heuristics.
// This helps avoid Google OAuth error 403: disallowed_useragent (Use secure browsers policy).

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

final _inAppMarkers = <Pattern>[
  // Meta/Facebook family
  'FBAN', 'FBAV', 'FB_IAB', 'FBAN/Messenger', 'Instagram',
  // LinkedIn
  'LinkedInApp', 'LIApp', 'LinkedIn', 'linkedin',
  // Twitter/X
  'Twitter', 'TwitterForIPhone', 'TwitterAndroid',
  // TikTok, Snapchat
  'Tiktok', 'TikTok', 'Snapchat',
  // Messaging
  'WhatsApp', 'Telegram', 'WeChat', 'Line/', 'Viber',
  // Generic Android WebView marker
  '; wv', 'Version/4.0 Mobile Safari/534.30',
  // Others
  'Pinterest', 'Reddit', 'DuckDuckGo', 'MiuiBrowser', 'VivoBrowser', 'OPR/mini',
];

bool _forceInAppFromQuery() {
  try {
    final uri = Uri.parse(html.window.location.href);
    final qp = uri.queryParameters;
    final v = qp['simulateInApp'] ?? qp['forceInApp'] ?? qp['debugInApp'];
    if (v == null) return false;
    return v == '1' || v.toLowerCase() == 'true' || v.toLowerCase() == 'yes';
  } catch (_) {
    return false;
  }
}

bool isInAppBrowser() {
  // Debug/testing override: allow forcing in-app behavior via query param.
  // Example: https://yourapp.com/?simulateInApp=1
  if (_forceInAppFromQuery()) return true;

  final ua = html.window.navigator.userAgent.toLowerCase();
  // Basic heuristic: if it's a known in-app UA marker OR Android WebView token ('; wv').
  for (final marker in _inAppMarkers) {
    if (ua.contains(marker.toString().toLowerCase())) return true;
  }
  // Additional heuristic: missing typical desktop/mobile browsers tokens
  final looksLikeRealBrowser = ua.contains('safari') || ua.contains('chrome') || ua.contains('firefox') || ua.contains('edg/');
  final isWebViewish = ua.contains('wv') && !looksLikeRealBrowser;
  return isWebViewish;
}

String userAgentString() => html.window.navigator.userAgent;
