import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _barController;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const HomeShell(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    final bg = context.appBg;
    final textPrimary = context.appTextPrimary;
    final textMuted = context.appTextMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Main centered content ──────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App icon — uses your custom image from assets
                    // Replace with Image.asset if you have a custom image:
                    //   Image.asset('assets/icon/app_icon.png', width: 90, height: 90)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        // Shows your custom icon if placed at assets/icon/app_icon.png
                        // Falls back to accent-colored wallet icon otherwise
                        color: accent.withValues(alpha: 0.10),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: _AppIconImage(accent: accent),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    // App name
                    Text(
                      'CholeBature',
                      style: GoogleFonts.dmSans(
                        color: textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 500.ms)
                        .slideY(
                            begin: 0.2,
                            end: 0,
                            delay: 300.ms,
                            duration: 500.ms),

                    const SizedBox(height: 6),

                    Text(
                      'Loading your kharche…',
                      style: GoogleFonts.dmSans(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate(
                                  onPlay: (c) => c.repeat(reverse: true))
                              .fadeIn(duration: 800.ms)
                              .then()
                              .fadeOut(duration: 800.ms),
                    

                    const SizedBox(height: 52),

                    // Loading bar
                    SizedBox(
                      width: 160,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedBuilder(
                              animation: _barController,
                              builder: (_, __) => LinearProgressIndicator(
                                value: _barController.value,
                                backgroundColor:
                                    accent.withValues(alpha: 0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                                minHeight: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'made by @siddiq0611',
                            style: GoogleFonts.dmSans(
                              color: textMuted,
                              fontSize: 11,
                            ),
                          ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                              
                        ],
                      ),
                    ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tries to load your custom asset image.
/// If the asset doesn't exist yet, falls back to the wallet icon.
class _AppIconImage extends StatelessWidget {
  final Color accent;
  const _AppIconImage({required this.accent});

  @override
  Widget build(BuildContext context) {
    // Once you add your icon at assets/icon/app_icon.png,
    // replace this entire widget body with just:
    //   return Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover);
    return Image.asset(
      'assets/icon/app_icon.jpeg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance_wallet_rounded,
        color: accent,
        size: 44,
      ),
    );
  }
}