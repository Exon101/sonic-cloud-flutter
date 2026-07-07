import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_auth_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';

/// Sign-in screen shown when the user is not authenticated.
///
/// Two paths:
///   1. **Anonymous** — instant guest account, no email required.
///   2. **Email** — idempotent sign-in (same email → same userId across
///      devices and sessions). No password; the server treats email as a
///      stable user-key for cross-device sync.
///
/// Also exposes a "Server URL" field so users can point at a self-hosted
/// Firebase Cloud Functions deployment instead of the default Vercel dev.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.auth,
    required this.client,
  });

  final ApiAuthService auth;
  final ApiClient client;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isBusy = false;
  String? _error;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.client.baseUrl;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInAnon() => _doSignIn(() => widget.auth.signInAnonymously());

  Future<void> _signInEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    await _doSignIn(() => widget.auth.signInWithEmail(email));
  }

  Future<void> _doSignIn(Future<UserAccount> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      // ApiAuthService is a ChangeNotifier — main.dart listens and will
      // swap the home shell in automatically. No explicit navigation needed.
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isBusy = false;
      });
    }
  }

  Future<void> _applyUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await widget.auth.setBaseUrl(url);
    setState(() => _error = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server set to $url'),
          backgroundColor: AppColors.secondaryContainer,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryContainer, AppColors.surfaceLowest],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo / title ─────────────────────────────────────────
                    Container(
                      width: 88,
                      height: 88,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [AppColors.secondaryContainer, AppColors.primaryContainer],
                          radius: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryContainer.withOpacity(0.35),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 44,
                        color: AppColors.surface,
                      ),
                    ),
                    Text(
                      'Sonic Cloud',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to sync your library, playlists, and\nplayback state across devices.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // ── Email field ──────────────────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      borderRadius: 16,
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                          border: InputBorder.none,
                          icon: Icon(Icons.email_outlined, color: AppColors.secondary),
                        ),
                        style: const TextStyle(color: AppColors.onSurface),
                        onSubmitted: (_) => _signInEmail(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Primary CTA: email sign-in ───────────────────────────
                    _SonicButton(
                      label: 'Continue with Email',
                      icon: Icons.mail_outline_rounded,
                      isLoading: _isBusy,
                      isPrimary: true,
                      onPressed: _signInEmail,
                    ),
                    const SizedBox(height: 12),

                    // ── Secondary CTA: anonymous ─────────────────────────────
                    _SonicButton(
                      label: 'Continue as Guest',
                      icon: Icons.person_outline_rounded,
                      isLoading: false,
                      isPrimary: false,
                      onPressed: _isBusy ? null : _signInAnon,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // ── Advanced: server URL ─────────────────────────────────
                    TextButton.icon(
                      onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                      icon: Icon(
                        _showAdvanced ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.onSurfaceVariant,
                      ),
                      label: Text(
                        'Advanced',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (_showAdvanced) ...[
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        borderRadius: 12,
                        child: TextField(
                          controller: _urlCtrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                            border: InputBorder.none,
                            icon: Icon(Icons.dns_outlined, color: AppColors.secondary),
                          ),
                          style: const TextStyle(color: AppColors.onSurface),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _applyUrl,
                          child: const Text('Apply & test'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand-styled button used on the sign-in screen.
class _SonicButton extends StatelessWidget {
  const _SonicButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isPrimary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh;
    final fg = isPrimary ? AppColors.onSecondary : AppColors.onSurface;
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
