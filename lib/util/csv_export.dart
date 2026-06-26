// Saves/shares a CSV across platforms. The right implementation is chosen at
// compile time: native share sheet on mobile/desktop (dart:io), a browser
// download on web (dart:html), and an explicit error elsewhere (stub).
export 'csv_export_stub.dart'
    if (dart.library.io) 'csv_export_io.dart'
    if (dart.library.html) 'csv_export_web.dart';
