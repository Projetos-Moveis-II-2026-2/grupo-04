import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Expõe o estado de conectividade do dispositivo como bool.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();
  Stream<bool>? _stream;
  bool _current = false;
  bool _published = false;

  /// Estado atual de conexão.
  bool get isOnline => _current;

  /// Emite `true`/`false` a cada mudança de conectividade, incluindo o
  /// estado inicial vindo de `checkConnectivity()` (sempre publicado,
  /// mesmo que o dispositivo inicie offline).
  Stream<bool> get isOnlineStream {
    return _stream ??= () {
      unawaited(
        _connectivity.checkConnectivity().then(
          (results) => _publish(_isOnline(results)),
          onError: (Object _) => _publish(false),
        ),
      );
      _connectivity.onConnectivityChanged.listen(
        (results) => _publish(_isOnline(results)),
        onError: (Object _) => _publish(false),
      );
      return _controller.stream;
    }();
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }

  void _publish(bool online) {
    final changed = !_published || online != _current;
    if (!changed) return;
    _published = true;
    _current = online;
    if (!_controller.isClosed) _controller.add(online);
  }

  Future<void> dispose() => _controller.close();
}
