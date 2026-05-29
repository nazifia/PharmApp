// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Opens [url] in a new browser tab.
void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}
