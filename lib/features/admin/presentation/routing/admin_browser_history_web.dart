import 'dart:html' as html;

void adminBrowserReplacePath(String path) {
  if (path.isEmpty) return;
  html.window.history.replaceState(null, '', path);
}
