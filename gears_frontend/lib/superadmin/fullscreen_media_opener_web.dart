import 'dart:js' as js;

void openPdfUrl(String url) {
  js.context.callMethod('open', [url]);
}
