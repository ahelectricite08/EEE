import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/referral_service.dart';
import '../tutorial/tutorial_screen.dart';

const _kBg     = Color(0xFFF5F2E9);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFDDD8CC);
const _kText   = Color(0xFF173C31);
const _kMuted  = Color(0xFF6E776F);
const _kRed    = Color(0xFFBA203C);
const _kGold   = Color(0xFFC8A436);

class RegisterScreen extends StatefulWidget {
  /// Quand l’écran est affiché **sous** [_AppEntry] : appelé après inscription réussie
  /// pour basculer tout de suite vers tutoriel / app (le [Navigator.popUntil] ne suffit pas).
  final VoidCallback? onRegistered;

  const RegisterScreen({super.key, this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form      = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _password  = TextEditingController();
  final _confirm   = TextEditingController();
  final _referral  = TextEditingController();

  bool    _loading  = false;
  bool    _showPwd  = false;
  bool    _showConf = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.register(
        firstName: _firstName.text,
        lastName:  _lastName.text,
        email:     _email.text,
        password:  _password.text,
      );
      // Appliquer le code parrainage si renseigné
      final code = _referral.text.trim();
      if (code.isNotEmpty) {
        try {
          await ReferralService.useCode(code);
        } catch (_) {
          // Echec silencieux — ne bloque pas l'inscription
        }
      }
      await markTutorialDone();
      if (!mounted) return;
      // Encarté dans _AppEntry : le parent recalcule la phase (tutoriel ou app).
      widget.onRegistered?.call();
      // Route `/register` sans parent (ex. après login) : repartir sur la racine comme la connexion.
      if (widget.onRegistered == null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
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
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: _kBg),
                Image.asset(
                  'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, wasSync) {
                    if (wasSync || frame != null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kGold.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: _kBg,
                    child: Icon(Icons.stadium_rounded,
                        size: 56, color: _kMuted.withValues(alpha: 0.35)),
                  ),
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
                      Flexible(
                        child: Text(
                        'CRÉER UN COMPTE',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 1.5,
                        ),
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
                      'Rejoins la communauté CSSA / DVCR gratuitement.',
                      style: GoogleFonts.barlow(fontSize: 13, color: _kMuted),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _firstName,
                            label: 'Prénom',
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _lastName,
                            label: 'Nom',
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

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
                    const SizedBox(height: 14),

                    _Field(
                      controller: _confirm,
                      label: 'Confirmer le mot de passe',
                      obscure: !_showConf,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConf ? Icons.visibility_off : Icons.visibility,
                          color: _kMuted, size: 20,
                        ),
                        onPressed: () => setState(() => _showConf = !_showConf),
                      ),
                      validator: (v) => v != _password.text
                          ? 'Les mots de passe ne correspondent pas'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Code de parrainage (optionnel) ───────────────────────
                    Row(
                      children: [
                        Container(
                          width: 1,
                          height: 16,
                          color: _kBorder,
                          margin: const EdgeInsets.only(right: 10),
                        ),
                        Text(
                          'CODE DE PARRAINAGE',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _kMuted, letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(optionnel)',
                          style: GoogleFonts.inter(fontSize: 10, color: _kMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _referral,
                      label: 'Ex: DVCRXYZ123',
                      textCapitalization: TextCapitalization.characters,
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
                                'CRÉER MON COMPTE',
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
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.barlow(fontSize: 13, color: _kMuted),
                            children: [
                              const TextSpan(text: 'Déjà un compte ? '),
                              TextSpan(
                                text: 'Se connecter',
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
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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
