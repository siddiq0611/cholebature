import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Full-screen overlay shown while [isLoading] is true.
/// Adapts to light and dark themes automatically via [context.appAccent].
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: context.appBg.withValues(alpha: 0.65),
              child: Center(child: AppSpinner(message: message)),
            ).animate().fadeIn(duration: 200.ms),
          ),
      ],
    );
  }
}

/// Reusable themed spinner — use this anywhere in the app.
///
/// ```dart
/// // Full screen center
/// Center(child: AppSpinner())
///
/// // With message
/// AppSpinner(message: 'Saving…')
///
/// // Small inline size
/// AppSpinner(size: 24, strokeWidth: 2)
/// ```
class AppSpinner extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;

  const AppSpinner({
    super.key,
    this.message,
    this.size = 40,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            color: accent,
            strokeCap: StrokeCap.round,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(
            message!,
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact inline loader for lists/cards.
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AppSpinner(size: 28, strokeWidth: 2.5),
      ),
    );
  }
}