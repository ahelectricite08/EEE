import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

const _kBg      = Color(0xFFF5F2E9);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFDDD8CC);
const _kText    = Color(0xFF173C31);
const _kMuted   = Color(0xFF6E776F);
const _kRed     = Color(0xFFBA203C);
const _kGold    = Color(0xFFC8A436);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form     = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();

  bool    _loading = false;
  bool    _showPwd = false;
  String? _error;
  bool    _resetSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      setState(() => _error = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Hero ────────────────────────────────────────────────────────────
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(60),
                        Colors.black.withAlpha(190),
                        _kBg.withAlpha(255),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
                if (Navigator.canPop(context))
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'ESPACE MEMBRES',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: _kGold, width: 1.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DVCR',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _kGold, letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Formulaire ──────────────────────────────────────────────────────
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
                      style: GoogleFonts.barlow(fontSize: 13, color: _kMuted),
                    ),
                    const SizedBox(height: 20),

                    _Field(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Requis';
                        if (!v!.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _Field(
                      controller: _password,
                      label: 'Mot de passe',
                      obscure: !_showPwd,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPwd ? Icons.visibility_off : Icons.visibility,
                          color: _kMuted, size: 20,
                        ),
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                      ),
                      validator: (v) => (v?.length ?? 0) < 6
                          ? '6 caractères minimum'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          _error!,
                          style: GoogleFonts.barlow(fontSize: 13, color: _kRed),
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                'SE CONNECTER',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 18, fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2, color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final email = _email.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setState(() => _error = 'Saisis ton email d\'abord.');
                            return;
                          }
                          try {
                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: email);
                            setState(() { _resetSent = true; _error = null; });
                          } catch (e) {
                            setState(() => _error = 'Impossible d\'envoyer l\'email.');
                          }
                        },
                        child: Text(
                          _resetSent
                              ? 'Email envoyé !'
                              : 'Mot de passe oublié ?',
                          style: GoogleFonts.barlow(
                            fontSize: 13,
                            color: _resetSent ? _kGold : _kMuted,
                            decoration: TextDecoration.underline,
                            decorationColor: _kMuted,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/register'),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.barlow(fontSize: 13, color: _kMuted),
                            children: [
                              const TextSpan(text: 'Pas encore inscrit ? '),
                              TextSpan(
                                text: 'Créer un compte',
                                style: const TextStyle(
                                  color: _kGold,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _kGold,
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.barlow(color: _kText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.barlow(color: _kMuted, fontSize: 13),
        filled: true,
        fillColor: _kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
        errorStyle: GoogleFonts.barlow(color: _kRed, fontSize: 11),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
