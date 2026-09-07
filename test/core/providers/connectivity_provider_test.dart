import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:olimpus/core/network/connectivity_service.dart';
import 'package:olimpus/core/providers/connectivity_providers.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  test(
    'connectivityProvider emits values from ConnectivityService stream',
    () async {
      final controller = StreamController<bool>.broadcast();
      final mock = MockConnectivityService();
      when(() => mock.isOnlineStream).thenAnswer((_) => controller.stream);

      final container = ProviderContainer(
        overrides: [connectivityServiceProvider.overrideWithValue(mock)],
      );
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      // Listen to trigger the stream subscription
      container.listen(connectivityProvider, (_, next) {});

      controller.add(true);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(connectivityProvider);
      expect(state.value, isTrue);
    },
  );
}
