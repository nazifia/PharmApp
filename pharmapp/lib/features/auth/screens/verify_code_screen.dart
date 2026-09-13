import 'package:flutter/material.dart';
import 'package:pharmapp/shared/widgets/in_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// OTP flow has been removed. This screen now simply redirects to login
/// so that any existing deep-links or bookmarks don't produce an error page.
class VerifyCodeScreen extends StatelessWidget {
  const VerifyCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(child: const CircularProgressIndicator().animateInView((a) => a.fadeIn(duration: 600.ms).scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 600.ms, curve: Curves.easeOutCubic))),
    );
  }
}
