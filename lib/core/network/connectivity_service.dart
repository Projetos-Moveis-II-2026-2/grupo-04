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

  /// Estado atual de conexão.
  bool get isOnline => _current;

  /// Emite `true`/`false` a cada mudança de conectividade, com o estado
  /// inicial vindo de `checkConnectivity()`.
  Stream<bool> get isOnlineStream {
    return _stream ??= () {
      unawaited(
        _connectivity.checkConnectivity().then(
          (results) => _onResults(results),
          onError: (Object _) => _onResults(const []),
        ),
      );
      _connectivity.onConnectivityChanged.listen(
        _onResults,
        onError: (Object _) => _onResults(const []),
      );
      return _controller.stream;
    }();
  }

  void _onResults(List<ConnectivityResult> results) {
    final online = results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
    if (online == _current) return;
    _current = online;
    _controller.add(online);
  }

  Future<void> dispose() => _controller.close();
}
