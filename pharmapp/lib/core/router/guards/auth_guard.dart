import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/services/auth_service.dart';

class AuthGuard extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) {
    final authService = context.read(authServiceProvider);

    return FutureBuilder<bool>(
      future: authService.checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!) {
          // Authenticated - proceed to the requested route
          return state.builder(
            context,
            child: state.route.subloc.isEmpty
               ? const HomeRoute().build(context, state)
                : state.subloc,
          );
        } else {
          // Not authenticated - redirect to login
          return const LoginRoute().build(context, state);
        }
      },
    );
  }
}

class RoleGuard extends GoRouteData {
  final String requiredRole;

  const RoleGuard(this.requiredRole);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final authService = context.read(authServiceProvider);

    return FutureBuilder<bool>(
      future: authService.checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!) {
          final currentUser = authService.currentUser;
          if (currentUser != null && currentUser.role == requiredRole) {
            // Has required role - proceed to the requested route
            return state.builder(
              context,
              child: state.route.subloc.isEmpty
                 ? const HomeRoute().build(context, state)
                  : state.subloc,
            );
          } else {
            // Doesn't have required role - redirect to appropriate dashboard
            String redirectRoute = '/dashboard';
            if (currentUser?.role == 'Wholesaler') {
              redirectRoute = '/wholesale-dashboard';
            } else if (currentUser?.role == 'Admin') {
              redirectRoute = '/admin-dashboard';
            }
            return redirect(redirectRoute);
          }
        } else {
          // Not authenticated - redirect to login
          return const LoginRoute().build(context, state);
        }
      },
    );
  }
}

class PermissionGuard extends GoRouteData {
  final List<String> requiredPermissions;

  const PermissionGuard(this.requiredPermissions);

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final authService = context.read(authServiceProvider);

    return FutureBuilder<bool>(
      future: authService.checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!) {
          final authService = context.read(authServiceProvider);
          final hasPermission = authService.hasPermission(requiredPermissions[0]);

          if (hasPermission) {
            // Has required permission - proceed to the requested route
            return state.builder(
              context,
              child: state.route.subloc.isEmpty
                 ? const HomeRoute().build(context, state)
                  : state.subloc,
            );
          } else {
            // Doesn't have required permission - show access denied
            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0x66FFFFFF),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Access Denied',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You don\'t have permission to access this page.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                          fontSize: 14,
                          textAlign: TextAlign.center,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        onPressed: () {
                          // Navigate back to dashboard
                          ref.read(enhancedThemeProvider.notifier).navigateTo('/dashboard');
                        },
                        text: 'Go to Dashboard',
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        } else {
          // Not authenticated - redirect to login
          return const LoginRoute().build(context, state);
        }
      },
    );
  }
}