// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// ── Replace with your actual Google Form values ────────────────────────────────
// The formResponse endpoint for background submission
const _googleFormBase =
    'https://docs.google.com/forms/d/e/1FAIpQLSfN3hgpUR66QS0emkH0uCMA14ul4j93w3FXoIy74W88V-ndDw/formResponse';

const _googleFormFallbackUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSchCr-GVCrI_d7ytec6OmniwvHWyXuj8chfM97Chem4EOgjrQ/viewform?usp=dialog';

const _entryRating  = 'entry.1993910943';
const _entryMessage = 'entry.2031031347';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _stars = 0;
  final _msgCtrl = TextEditingController();

  _SubmitState _submitState = _SubmitState.idle;
  _ErrorType? _errorType;
  String? _errorDetail;

  bool _sent = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() {
        _errorType   = _ErrorType.validation;
        _errorDetail = 'Please select a star rating before submitting.';
      });
      return;
    }

    setState(() {
      _submitState = _SubmitState.sending;
      _errorType   = null;
      _errorDetail = null;
    });

    final ratingText = '$_stars star${_stars > 1 ? 's' : ''}';
    final msg        = _msgCtrl.text.trim();

    final uri = Uri.parse(_googleFormBase).replace(queryParameters: {
      _entryRating:  ratingText,
      _entryMessage: msg,
    });

    try {
      final response = await http
          .post(uri)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 400) {
        if (mounted) setState(() { _submitState = _SubmitState.idle; _sent = true; });
      } else {
        if (mounted) {
          setState(() {
            _submitState = _SubmitState.idle;
            _errorType   = _ErrorType.server;
            _errorDetail = 'HTTP ${response.statusCode}';
          });
        }
      }
    } on Exception catch (e) {
      if (!mounted) return;

      final msg2 = e.toString().toLowerCase();
      final isNetworkBlock =
          msg2.contains('socketexception') ||
          msg2.contains('clientexception') ||
          msg2.contains('handshake') ||
          msg2.contains('connection refused') ||
          msg2.contains('network is unreachable') ||
          msg2.contains('failed host lookup');

      setState(() {
        _submitState = _SubmitState.idle;
        _errorType   = isNetworkBlock
            ? _ErrorType.networkBlock
            : _ErrorType.unknown;
        _errorDetail = e.toString().split(':').first.trim();
      });
    }
  }

  Future<void> _openFormInBrowser() async {
    final uri = Uri.parse(_googleFormFallbackUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _reset() => setState(() {
        _sent        = false;
        _stars       = 0;
        _submitState = _SubmitState.idle;
        _errorType   = null;
        _errorDetail = null;
        _msgCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.appTextPrimary),
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
              stars:       _stars,
              submitState: _submitState,
              msgCtrl:     _msgCtrl,
              errorType:   _errorType,
              errorDetail: _errorDetail,
              onStarTap:   (s) => setState(() {
                _stars     = s;
                _errorType = null;
                _errorDetail = null;
              }),
              onSubmit:           _submit,
              onOpenFormInBrowser: _openFormInBrowser,
            ),
    );
  }
}

enum _SubmitState { idle, sending }

enum _ErrorType {
  validation,   // user forgot to pick stars
  networkBlock, // SocketException / device blocking HTTP
  server,       // 4xx / 5xx
  unknown,      // anything else
}

// ── Form view ──────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final int stars;
  final _SubmitState submitState;
  final TextEditingController msgCtrl;
  final _ErrorType? errorType;
  final String? errorDetail;
  final void Function(int) onStarTap;
  final VoidCallback onSubmit;
  final VoidCallback onOpenFormInBrowser;

  const _FormView({
    required this.stars,
    required this.submitState,
    required this.msgCtrl,
    required this.errorType,
    required this.errorDetail,
    required this.onStarTap,
    required this.onSubmit,
    required this.onOpenFormInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    final isSending = submitState == _SubmitState.sending;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
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
                    fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const Gap(28),

          // ── Star rating ─────────────────────────────────────────────────
          Text('How would you rate your experience?',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const Gap(16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < stars;
              return GestureDetector(
                onTap: isSending ? null : () => onStarTap(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
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
                  ['', 'Poor 😞', 'Fair 😐', 'Good 🙂',
                   'Great 😊', 'Excellent! 🤩'][stars],
                  key: ValueKey(stars),
                  style: GoogleFonts.dmSans(
                      color: context.appAccent,
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const Gap(28),

          // ── Message ─────────────────────────────────────────────────────
          Text('Leave a message (optional)',
              style: GoogleFonts.dmSans(
                  color: context.appTextPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const Gap(10),
          TextField(
            controller: msgCtrl,
            maxLines: 5,
            enabled: !isSending,
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
          const Gap(20),

          // ── Error box ────────────────────────────────────────────────────
          if (errorType != null)
            _ErrorBox(
              errorType:          errorType!,
              errorDetail:        errorDetail,
              onOpenFormInBrowser: onOpenFormInBrowser,
            ),

          // ── Submit button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSending ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appAccent,
                disabledBackgroundColor:
                    context.appAccent.withValues(alpha: 0.6),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSending
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const Gap(10),
                        Text('Submitting…',
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded,
                            size: 18, color: Colors.white),
                        const Gap(8),
                        Text('Submit Feedback',
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ],
                    ),
            ),
          ),

          const Gap(12),
          Center(
            child: Text(
              'Feedback is submitted directly in the background.',
              style: GoogleFonts.dmSans(
                  color: context.appTextMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error box ──────────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final _ErrorType errorType;
  final String? errorDetail;
  final VoidCallback onOpenFormInBrowser;

  const _ErrorBox({
    required this.errorType,
    required this.errorDetail,
    required this.onOpenFormInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    // Decide message + whether to show the "Open Form" button
    String title;
    String body;
    bool showOpenButton;

    switch (errorType) {
      case _ErrorType.validation:
        title          = 'Missing rating';
        body           = 'Please select a star rating before submitting.';
        showOpenButton = false;
        break;

      case _ErrorType.networkBlock:
        title          = 'Connection blocked';
        body           =
            'Your device or network is preventing the app from reaching ';
            'Googles servers. This is common on some Android/iOS setups.\n'
            'You can open the form directly in your browser instead — '
            'your stars and message will not be pre-filled there.';
        showOpenButton = true;
        break;

      case _ErrorType.server:
        title          = 'Submission failed';
        body           =
            'Google returned an error (${errorDetail ?? 'unknown'}). '
            'Please try again or open the form in your browser.';
        showOpenButton = true;
        break;

      case _ErrorType.unknown:
        title          = 'Something went wrong';
        body           =
            'An unexpected error occurred. Please check your internet '
            'connection and try again, or open the form in your browser.';
        showOpenButton = true;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appExpense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: context.appExpense.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: context.appExpense, size: 18),
              const Gap(8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: context.appExpense,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),

          // Body text
          Text(
            body,
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          // "Open Form in Browser" button
          if (showOpenButton) ...[
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenFormInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: Text('Open Form in Browser',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appAccent,
                  side: BorderSide(
                      color: context.appAccent.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
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
              width: 80, height: 80,
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
              'Your feedback helps us make CholeBature\nbetter for everyone. 🙏',
              style: GoogleFonts.dmSans(
                  color: context.appTextSecondary,
                  fontSize: 14, height: 1.6),
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