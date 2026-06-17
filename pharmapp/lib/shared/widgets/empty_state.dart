import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

/// Reusable empty / no-data placeholder.
///
/// Replaces the ~40 hand-rolled `_emptyState` variants. Renders a
/// tinted circular icon, a title and an optional message. Set [boxed]
/// to true for the bordered glass-panel style used inside report cards;
/// leave false for the centered full-screen style used in list bodies.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = EnhancedTheme.primaryTeal,
    this.boxed = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final bool boxed;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(boxed ? 18 : 28),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.03),
            ]),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: boxed ? 32 : 56),
        ),
        SizedBox(height: boxed ? 12 : 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: context.labelColor,
            fontSize: boxed ? 15 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subLabelColor, fontSize: 13),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ],
    );

    final animated = column
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));

    if (!boxed) return Center(child: animated);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: animated,
    );
  }
}
