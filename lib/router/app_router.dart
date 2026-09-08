import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/confirmation_pending_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_placeholder_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';

/// Configuração temporária de rotas para validar o fluxo de Auth.
/// A infraestrutura global de redirecionamento (guardas avançadas)
/// pertence à Issue #33.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.value;
      final isLoggedIn = user != null && user.isEmailConfirmed;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/confirmation') ||
          state.matchedLocation.startsWith('/callback') ||
          state.matchedLocation.startsWith('/auth/callback') ||
          state.matchedLocation.startsWith('/reset-password');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(
        path: '/confirmation',
        builder: (context, state) => ConfirmationPendingPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/callback',
        redirect: (context, state) => '/',
      ),
      GoRoute(
        path: '/auth/callback',
        redirect: (context, state) => '/',
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPlaceholderPage(),
      ),
    ],
  );
});
