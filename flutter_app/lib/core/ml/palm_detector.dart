export 'palm_detector_stub.dart'
    if (dart.library.io) 'palm_detector_native.dart'
    if (dart.library.js_interop) 'palm_detector_web.dart';
