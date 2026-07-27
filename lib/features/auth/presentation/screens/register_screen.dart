import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../screens/tutorial/tutorial_screen.dart';
import '../../../../services/referral_service.dart';
import '../auth_providers.dart';
import '../widgets/auth_hero_banner.dart';
import '../widgets/auth_palette.dart';
import '../widgets/auth_register_form_body.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  /// Called after successful register when embedded under AppEntry.
  final VoidCallback? onRegistered;
  final VoidCallback? onBrowseArticlesAsGuest;

  /// Back to guest actus (App Store guest flow).
  final VoidCallback? onBackToGuest;

  const RegisterScreen({
    super.key,
    this.onRegistered,
    this.onBrowseArticlesAsGuest,
    this.onBackToGuest,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _referral = TextEditingController();

  bool _loading = false;
  bool _showPwd = false;
  bool _showConf = false;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(registerUserProvider)(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    await result.when(
      success: (_) async {
        final code = _referral.text.trim();
        if (code.isNotEmpty) {
          try {
            await ReferralService.useCode(code);
          } catch (_) {
            // Silent — do not block registration
          }
        }
        await markTutorialDone();
        if (!mounted) return;
        widget.onRegistered?.call();
        if (widget.onRegistered == null) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      failure: (e) async {
        setState(() => _error = e.messageFr);
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final canBack =
        widget.onBackToGuest != null || Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AuthPalette.bg,
      body: Column(
        children: [
          AuthHeroBanner(
            title: 'CRÉER UN COMPTE',
            height: 200,
            showImageLoadingPlaceholder: true,
            onBack: canBack
                ? () {
                    if (widget.onBackToGuest != null) {
                      widget.onBackToGuest!();
                    } else {
                      Navigator.pop(context);
                    }
                  }
                : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: AuthRegisterFormBody(
                formKey: _form,
                firstName: _firstName,
                lastName: _lastName,
                email: _email,
                password: _password,
                confirm: _confirm,
                referral: _referral,
                showPassword: _showPwd,
                showConfirm: _showConf,
                loading: _loading,
                error: _error,
                onTogglePassword: () => setState(() => _showPwd = !_showPwd),
                onToggleConfirm: () => setState(() => _showConf = !_showConf),
                onSubmit: _submit,
                onGoLogin: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                onBrowseAsGuest: widget.onBrowseArticlesAsGuest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
