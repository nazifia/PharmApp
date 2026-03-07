import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// OTP flow has been removed. This screen now simply redirects to login
/// so that any existing deep-links or bookmarks don't produce an error page.
class VerifyCodeScreen extends StatelessWidget {
  const VerifyCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
