import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_providers.dart';
import '../widgets/auth_hero_banner.dart';
import '../widgets/auth_palette.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _showPwd = false;
  String? _error;
  bool _resetSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(signInProvider)(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    result.when(
      success: (_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      failure: (e) {
        setState(() => _error = e.messageFr);
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Indique ton adresse email pour recevoir le lien.',
      );
      return;
    }
    final result = await ref.read(resetPasswordProvider)(email: email);
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() {
          _resetSent = true;
          _error = null;
        });
      },
      failure: (e) {
        setState(() => _error = e.messageFr);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.bg,
      body: Column(
        children: [
          AuthHeroBanner(
            title: 'ESPACE MEMBRES',
            height: 240,
            onBack: Navigator.canPop(context)
                ? () => Navigator.pop(context)
                : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connecte-toi pour rejoindre la communauté.',
                      style: GoogleFonts.barlow(
                        fontSize: 13,
                        color: AuthPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      controller: _email,
                      label: 'Adresse e-mail',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Requis';
                        if (!v!.contains('@')) {
                          return 'Adresse e-mail invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _password,
                      label: 'Mot de passe',
                      obscure: !_showPwd,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPwd ? Icons.visibility_off : Icons.visibility,
                          color: AuthPalette.muted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) < 6 ? '6 caractères minimum' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          _error!,
                          style: GoogleFonts.barlow(
                            fontSize: 13,
                            color: AuthPalette.red,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuthPalette.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'SE CONNECTER',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          _resetSent
                              ? 'Lien envoyé — consulte ta boîte mail'
                              : 'Mot de passe oublié ?',
                          style: GoogleFonts.barlow(
                            fontSize: 13,
                            color: _resetSent
                                ? AuthPalette.gold
                                : AuthPalette.muted,
                            decoration: TextDecoration.underline,
                            decorationColor: AuthPalette.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (route) => false),
                        child: Text(
                          'Continuer sans compte — lire les actus',
                          style: GoogleFonts.barlow(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AuthPalette.text,
                            decoration: TextDecoration.underline,
                            decorationColor: AuthPalette.text.withAlpha(180),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/register',
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.barlow(
                              fontSize: 13,
                              color: AuthPalette.muted,
                            ),
                            children: [
                              const TextSpan(text: 'Pas encore inscrit ? '),
                              TextSpan(
                                text: 'Créer un compte',
                                style: const TextStyle(
                                  color: AuthPalette.gold,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AuthPalette.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
