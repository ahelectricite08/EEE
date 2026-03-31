import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

const _kBg     = Color(0xFF0D0D0D);
const _kRed    = Color(0xFFBA203C);
const _kCard   = Color(0xFF141414);
const _kBorder = Color(0xFF2A2A2A);
const _kGold   = Color(0xFFC8A436);

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
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
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
          // ── Hero ──────────────────────────────────────────────────────────
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                  fit: BoxFit.cover,
                ),
                // Gradient bas→haut pour fondre avec le body
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(80),
                        Colors.black.withAlpha(200),
                        _kBg,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Titre
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
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
                      const SizedBox(height: 4),
                      Text(
                        'Connecte-toi pour rejoindre la communauté.',
                        style: GoogleFonts.barlow(
                            fontSize: 13, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Formulaire ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          color: Colors.white38, size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showPwd = !_showPwd),
                      ),
                      validator: (v) => (v?.length ?? 0) < 6
                          ? '6 caractères minimum'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!,
                            style: GoogleFonts.barlow(
                                fontSize: 13, color: _kRed)),
                      ),

                    // Bouton connexion
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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

                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                            context, '/register'),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.barlow(
                                fontSize: 13, color: Colors.white54),
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
      style: GoogleFonts.barlow(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.barlow(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: _kCard,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
