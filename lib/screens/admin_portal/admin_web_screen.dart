import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import '../admin_panel.dart';
import '../../theme/app_colors.dart';
import '../admin/admin_palette.dart';

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
  String? _gateError;
  /// Auth OK mais sans rôle staff — affiche un message + bouton déconnexion.
  bool _deniedWhileSignedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _authorized = false;
        _deniedWhileSignedIn = false;
      });
      return;
    }
    try {
      unawaited(RolePermissionsService.ensureDefaults());

      Set<UserRole> roles;
      try {
        roles = await UserService.getCurrentRoles()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('AdminWebScreen roles: $e');
        // Dernier recours : isAdmin() seul (même timeout).
        try {
          final isAdmin = await UserService.isAdmin()
              .timeout(const Duration(seconds: 5));
          roles = isAdmin ? {UserRole.admin} : const <UserRole>{};
        } catch (_) {
          roles = const <UserRole>{};
        }
      }

      Map<String, List<String>> config;
      try {
        config = await RolePermissionsService.stream()
            .first
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        config = RolePermissionsService.defaultPermissions;
      }

      final ok = RolePermissionsService.hasPermission(
            roles,
            RolePermissionsService.adminAccess,
            config,
          ) ||
          UserService.canAccessAdminPanel(roles) ||
          roles.contains(UserRole.admin);

      if (ok) {
        unawaited(AppSettingsService.migrateLegacyTeamDvcrBadgeLabel());
        // Ne jamais bloquer l’entrée panel sur le refresh des claims (web).
        unawaited(_refreshClaimsBestEffort());
        if (!mounted) return;
        setState(() {
          _checking = false;
          _authorized = true;
          _gateError = null;
          _deniedWhileSignedIn = false;
        });
        return;
      }

      final roleLabels = roles.isEmpty
          ? 'aucun / doc users manquant'
          : roles.map((r) => r.firestoreRole).join(', ');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _authorized = false;
        _deniedWhileSignedIn = true;
        _gateError =
            'Compte connecté mais sans droit admin '
            '(rôles : $roleLabels). '
            'Dans Firebase Console → Firestore → users/${user.uid}, '
            'ajoute "admin" dans roles (et role: "admin"), puis reconnecte-toi.';
      });
    } catch (e) {
      debugPrint('AdminWebScreen._check: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _authorized = false;
        _deniedWhileSignedIn = FirebaseAuth.instance.currentUser != null;
        _gateError =
            'Impossible de vérifier les droits admin. Réessaie, ou vérifie '
            'le document Firestore users/{uid}.';
      });
    }
  }

  Future<void> _refreshClaimsBestEffort() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('refreshDvcrAuthClaims')
          .call()
          .timeout(const Duration(seconds: 8));
      await FirebaseAuth.instance.currentUser
          ?.getIdToken(true)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('AdminWebScreen claims refresh: $e');
    }
  }

  Future<void> _signOutFromGate() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _authorized = false;
      _deniedWhileSignedIn = false;
      _gateError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: adminGoldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chargement…',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColorsLight.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_authorized) {
      return _LoginGate(
        initialError: _gateError,
        showSignOut: _deniedWhileSignedIn,
        onSignOut: _signOutFromGate,
        onLogin: () {
          setState(() {
            _checking = true;
            _gateError = null;
            _deniedWhileSignedIn = false;
          });
          _check();
        },
      );
    }

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
  final Future<void> Function()? onSignOut;
  final String? initialError;
  final bool showSignOut;
  const _LoginGate({
    required this.onLogin,
    this.initialError,
    this.showSignOut = false,
    this.onSignOut,
  });
  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void didUpdateWidget(covariant _LoginGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialError != oldWidget.initialError) {
      _error = widget.initialError;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

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
      if (!mounted) return;
      widget.onLogin();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.errorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.errorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: adminGoldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: adminGlowShadow(adminGold),
                  ),
                  child: Center(
                    child: Text(
                      'D',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'DVCR Administration',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _kRed,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connectez-vous pour accéder au panel',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColorsLight.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                    boxShadow: adminCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.showSignOut) ...[
                        _WebField(controller: _email, label: 'Email'),
                        const SizedBox(height: 16),
                        _WebField(
                          controller: _pass,
                          label: 'Mot de passe',
                          obscure: true,
                        ),
                      ],
                      if (_error != null) ...[
                        if (!widget.showSignOut) const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _kRed.withAlpha(12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kRed.withAlpha(50)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: _kRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _kRed,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (widget.showSignOut)
                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRed,
                              side: const BorderSide(color: _kRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: widget.onSignOut == null
                                ? null
                                : () async {
                                    await widget.onSignOut!();
                                  },
                            child: Text(
                              'Se déconnecter',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                    'Se connecter',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppColorsLight.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColorsLight.textMuted,
        ),
        filled: true,
        fillColor: AppColorsLight.cardMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
