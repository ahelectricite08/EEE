import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/club_branding.dart';
import 'auth_palette.dart';
import 'auth_text_field.dart';

/// Register form fields + submit (visual parity with legacy register screen).
class AuthRegisterFormBody extends StatelessWidget {
  const AuthRegisterFormBody({
    super.key,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.confirm,
    required this.referral,
    required this.showPassword,
    required this.showConfirm,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onGoLogin,
    this.onBrowseAsGuest,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final TextEditingController referral;
  final bool showPassword;
  final bool showConfirm;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onGoLogin;
  final VoidCallback? onBrowseAsGuest;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rejoins la communauté ${ClubBranding.shortName} / DVCR gratuitement.',
            style: GoogleFonts.barlow(fontSize: 13, color: AuthPalette.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AuthTextField(
                  controller: firstName,
                  label: 'Prénom',
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuthTextField(
                  controller: lastName,
                  label: 'Nom',
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: email,
            label: 'Adresse e-mail',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Requis';
              if (!v!.contains('@')) return 'Adresse e-mail invalide';
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: password,
            label: 'Mot de passe',
            obscure: !showPassword,
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: AuthPalette.muted,
                size: 20,
              ),
              onPressed: onTogglePassword,
            ),
            validator: (v) =>
                (v?.length ?? 0) < 6 ? '6 caractères minimum' : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: confirm,
            label: 'Confirmer le mot de passe',
            obscure: !showConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                showConfirm ? Icons.visibility_off : Icons.visibility,
                color: AuthPalette.muted,
                size: 20,
              ),
              onPressed: onToggleConfirm,
            ),
            validator: (v) => v != password.text
                ? 'Les mots de passe ne correspondent pas'
                : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 1,
                height: 16,
                color: AuthPalette.border,
                margin: const EdgeInsets.only(right: 10),
              ),
              Text(
                'CODE DE PARRAINAGE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AuthPalette.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(optionnel)',
                style: GoogleFonts.inter(fontSize: 10, color: AuthPalette.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AuthTextField(
            controller: referral,
            label: 'Ex: DVCRXYZ123',
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 24),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                error!,
                style: GoogleFonts.barlow(fontSize: 13, color: AuthPalette.red),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthPalette.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'CRÉER MON COMPTE',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: onGoLogin,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.barlow(
                    fontSize: 13,
                    color: AuthPalette.muted,
                  ),
                  children: [
                    const TextSpan(text: 'Déjà un compte ? '),
                    TextSpan(
                      text: 'Se connecter',
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
          if (onBrowseAsGuest != null) ...[
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: loading ? null : onBrowseAsGuest,
                style: TextButton.styleFrom(
                  foregroundColor: AuthPalette.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Continuer sans compte — lire les actus',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlow(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AuthPalette.muted.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
