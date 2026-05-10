import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import '../admin_panel.dart';
import '../../theme/app_colors.dart';

const _kRed = AppColors.red;
const _kBg = AppColorsLight.scaffold;
const _kCard = AppColorsLight.card;
const _kBorder = AppColorsLight.border;

class AdminWebScreen extends StatefulWidget {
  const AdminWebScreen({super.key});
  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _checking = false;
        _authorized = false;
      });
      return;
    }
    RolePermissionsService.ensureDefaults();
    final roles = await UserService.getCurrentRoles();
    final config = await RolePermissionsService.stream().first;
    final ok = RolePermissionsService.hasPermission(
      roles,
      RolePermissionsService.adminAccess,
      config,
    );
    if (ok) {
      try {
        await FirebaseFunctions.instance
            .httpsCallable('refreshDvcrAuthClaims')
            .call();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (_) {}
    }
    setState(() {
      _checking = false;
      _authorized = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking)
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kRed)),
      );

    if (!_authorized)
      return _LoginGate(
        onLogin: () {
          setState(() {
            _checking = true;
          });
          _check();
        },
      );

    return AdminPanel(
      toolbarMode: kIsWeb
          ? AdminToolbarMode.standaloneWeb
          : AdminToolbarMode.embeddedFromApp,
    );
  }
}

// ── Gate login ────────────────────────────────────────────────────────────────
class _LoginGate extends StatefulWidget {
  final VoidCallback onLogin;
  const _LoginGate({required this.onLogin});
  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      widget.onLogin();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DVCR',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _kRed,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Administration',
                style: GoogleFonts.inter(fontSize: 13, color: AppColorsLight.textMuted),
              ),
              const SizedBox(height: 32),
              _WebField(controller: _email, label: 'Email'),
              const SizedBox(height: 16),
              _WebField(
                controller: _pass,
                label: 'Mot de passe',
                obscure: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 12, color: _kRed),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _loading ? null : _login,
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
                          'CONNEXION',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  const _WebField({
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 13, color: AppColorsLight.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColorsLight.textMuted),
        filled: true,
        fillColor: AppColorsLight.cardMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kRed),
        ),
      ),
    );
  }
}
