import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/widgets/loading_overlay.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/pages/delete_account_page.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';

import '../../../../helpers/pump_app.dart';

class _LoadingAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<AppUser?> build() {
    return const AsyncLoading();
  }
}

void main() {
  group('DeleteAccountPage LoadingOverlay', () {
    testWidgets('exibe LoadingOverlay ativo quando estado for AsyncLoading', (
      tester,
    ) async {
      await pumpApp(
        tester,
        child: const DeleteAccountPage(),
        overrides: [
          currentUserProvider.overrideWithValue(
            const AppUser(
              id: 'u-1',
              email: 'test@olimpus.app',
              emailConfirmedAt: null,
            ),
          ),
          authNotifierProvider.overrideWith(_LoadingAuthNotifier.new),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingOverlay), findsOneWidget);
      expect(find.text('Excluindo conta...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
