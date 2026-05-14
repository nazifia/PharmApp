// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Reloads the browser page — used on web after network reconnection to
/// reinitialize the Flutter app from a clean state.
void reloadApp() => html.window.location.reload();
