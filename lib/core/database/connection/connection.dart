/// Conexão com o banco local, por plataforma.
///
/// Native (FFI): Android/iOS/desktop. Web: SQLite WASM + drift worker.
library;

export 'connection_stub.dart'
    if (dart.library.js_interop) 'web.dart'
    if (dart.library.ffi) 'native.dart';
