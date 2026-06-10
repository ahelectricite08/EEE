// Conditional import : dart:html n'est disponible que sur le web.
export 'home_banner_section_stub.dart'
    if (dart.library.html) 'home_banner_section_web.dart';
