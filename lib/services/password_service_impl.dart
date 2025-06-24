// This file conditionally imports the correct implementation

// For web
// ignore: uri_does_not_exist

// Re-export the implementation
export 'password_service_impl_web.dart'
    if (dart.library.io) 'password_service_impl_mobile.dart';