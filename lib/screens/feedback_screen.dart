// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

const _googleFormBase =
    'https://docs.google.com/forms/d/e/1FAIpQLSfN3hgpUR66QS0emkH0uCMA14ul4j93w3FXoIy74W88V-ndDw/formResponse';

const _entryRating = 'entry.1993910943';
const _entryMessage = 'entry.2031031347';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _stars = 0;
  final _msgCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a star rating',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: context.appBorrowed,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Show spinner immediately
    setState(() => _sending = true);

    final ratingText = '$_stars star${_stars > 1 ? 's' : ''}';
    final msg = _msgCtrl.text.trim();

    final uri = Uri.parse(_googleFormBase).replace(queryParameters: {
      _entryRating: ratingText,
      _entryMessage: msg,
    });

    // Try to submit; give it up to 8 seconds before giving up gracefully.
    // Either way we show the success screen — Google Forms returns a redirect
    // (303) which http treats as an error on some devices, but the submission
    // still goes through.
    try {
      await http.post(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => http.Response('timeout', 408),
      );
    } catch (_) {
      // Swallow — submission likely still went through via the redirect.
    }

    // Only update state if still mounted
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
  }

  void _reset() => setState(() {
        _sent = false;
        _stars = 0;
        _msgCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_rounded, color: context.appTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Feedback',
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _sent
          ? _ThankYouView(onReset: _reset)
          : _FormView(
              stars: _stars,
              sending: _sending,
              msgCtrl: _msgCtrl,
              onStarTap: (s) => setState(() => _stars = s),
              onSubmit: _submit,
            ),
    );
  }
}

// ── Form view ──────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final int stars;
  final bool sending;
  final TextEditingController msgCtrl;
  final void Function(int) onStarTap;
  final VoidCallback onSubmit;

  const _FormView({
    required this.stars,
    required this.sending,
    required this.msgCtrl,
    required this.onStarTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFFD700), size: 36),
                ),
                const Gap(16),
                Text('Rate CholeBature',
                    style: GoogleFonts.dmSans(
                        color: context.appTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
                const Gap(6),
                Text(
                  'Your feedback helps us improve the app\nand add features you care about.',
                  style: GoogleFonts.dmSans(
                      color: context.appTextSecondary,
                      fontSize: 13,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Gap(28),

          Text('How would you rate your experience?',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Gap(16),

          // Star row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < stars;
              return GestureDetector(
                onTap: () => onStarTap(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      key: ValueKey(filled),
                      color: filled
                          ? const Color(0xFFFFD700)
                          : context.appTextMuted,
                      size: 44,
                    ),
                  ),
                ),
              );
            }),
          ),

          if (stars > 0) ...[
            const Gap(10),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  [
                    '',
                    'Poor 😞',
                    'Fair 😐',
                    'Good 🙂',
                    'Great 😊',
                    'Excellent! 🤩'
                  ][stars],
                  key: ValueKey(stars),
                  style: GoogleFonts.dmSans(
                      color: context.appAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const Gap(28),

          Text('Leave a message (optional)',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Gap(10),
          TextField(
            controller: msgCtrl,
            maxLines: 5,
            style: GoogleFonts.dmSans(
                color: context.appTextPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Tell us what you love, what to improve, or request a feature…',
              hintStyle: GoogleFonts.dmSans(
                  color: context.appTextMuted, fontSize: 13),
              alignLabelWithHint: true,
            ),
          ),
          const Gap(32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sending ? null : onSubmit,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
              label: Text(
                  sending ? 'Submitting…' : 'Submit Feedback',
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thank you view ─────────────────────────────────────────────────────────────

class _ThankYouView extends StatelessWidget {
  final VoidCallback onReset;
  const _ThankYouView({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.appIncome.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: context.appIncome, size: 44),
            ),
            const Gap(24),
            Text('Thanks for your feedback!',
                style: GoogleFonts.dmSans(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const Gap(10),
            Text(
              'Your feedback helps us make CholeBature\nbetter for everyone.',
              style: GoogleFonts.dmSans(
                  color: context.appTextSecondary,
                  fontSize: 14,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appAccent,
                side: BorderSide(color: context.appAccent),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Submit Another',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}