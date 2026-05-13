// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Registers listeners for the browser's native `online` / `offline` events.
/// Returns a cancel function that removes both subscriptions.
void Function() listenBrowserNetwork({
  required void Function() onOnline,
  required void Function() onOffline,
}) {
  final onlineSub = html.window.onOnline.listen((_) => onOnline());
  final offlineSub = html.window.onOffline.listen((_) => onOffline());
  return () {
    onlineSub.cancel();
    offlineSub.cancel();
  };
}
