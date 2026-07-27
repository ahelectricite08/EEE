import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../admin_form_widgets.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import '../../../../services/app_version_policy_service.dart';

/// Admin : politique de version store (`app_config/app_version`).
class AppVersionAdminSection extends StatefulWidget {
  const AppVersionAdminSection({super.key});

  @override
  State<AppVersionAdminSection> createState() => _AppVersionAdminSectionState();
}

class _AppVersionAdminSectionState extends State<AppVersionAdminSection> {
  bool _enabled = false;
  final _minBuildAndroidCtrl = TextEditingController();
  final _minBuildIosCtrl = TextEditingController();
  final _latestBuildAndroidCtrl = TextEditingController();
  final _latestBuildIosCtrl = TextEditingController();
  final _storeAndroidCtrl = TextEditingController(
    text: AppVersionPolicyService.defaultStoreAndroid,
  );
  final _storeIosCtrl = TextEditingController(
    text: AppVersionPolicyService.defaultStoreIos,
  );

  // Champs conservés en Firestore (textes / secours / visuel) — non exposés dans l’UI.
  String _titleRequired = '';
  String _messageRequired = '';
  String _titleOptional = '';
  String _messageOptional = '';
  String _minVersionAndroid = '';
  String _minVersionIos = '';
  String _updateImageUrl = '';

  String _installedVersionLabel = '—';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minBuildAndroidCtrl.dispose();
    _minBuildIosCtrl.dispose();
    _latestBuildAndroidCtrl.dispose();
    _latestBuildIosCtrl.dispose();
    _storeAndroidCtrl.dispose();
    _storeIosCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AppVersionPolicyService.ref.get(),
        PackageInfo.fromPlatform(),
      ]);
      final snap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final info = results[1] as PackageInfo;
      final d = snap.data() ?? {};

      _enabled = d['enabled'] == true;
      _titleRequired =
          (d['titleRequired'] as String?) ?? (d['title'] as String?) ?? '';
      _messageRequired =
          (d['messageRequired'] as String?) ?? (d['message'] as String?) ?? '';
      _titleOptional = (d['titleOptional'] as String?) ?? '';
      _messageOptional = (d['messageOptional'] as String?) ?? '';
      _minVersionAndroid = (d['minVersionAndroid'] as String?) ?? '';
      _minVersionIos = (d['minVersionIos'] as String?) ?? '';
      _updateImageUrl = (d['updateImageUrl'] as String?) ?? '';
      _minBuildAndroidCtrl.text = '${d['minBuildAndroid'] ?? ''}';
      _minBuildIosCtrl.text = '${d['minBuildIos'] ?? ''}';
      _latestBuildAndroidCtrl.text = '${d['latestBuildAndroid'] ?? ''}';
      _latestBuildIosCtrl.text = '${d['latestBuildIos'] ?? ''}';
      _storeAndroidCtrl.text =
          (d['storeUrlAndroid'] as String?) ??
          AppVersionPolicyService.defaultStoreAndroid;
      _storeIosCtrl.text =
          (d['storeUrlIos'] as String?) ??
          AppVersionPolicyService.defaultStoreIos;
      _installedVersionLabel = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final latestA = int.tryParse(_latestBuildAndroidCtrl.text.trim());
    final latestI = int.tryParse(_latestBuildIosCtrl.text.trim());
    if (_enabled && latestA == null && latestI == null) {
      final minA = int.tryParse(_minBuildAndroidCtrl.text.trim());
      if (minA != null) {
        _latestBuildAndroidCtrl.text = '${minA + 1}';
      }
    }

    setState(() => _saving = true);
    try {
      await AppVersionPolicyService.savePolicy({
        'enabled': _enabled,
        'titleRequired': _titleRequired.trim(),
        'messageRequired': _messageRequired.trim(),
        'titleOptional': _titleOptional.trim(),
        'messageOptional': _messageOptional.trim(),
        'minBuildAndroid': int.tryParse(_minBuildAndroidCtrl.text.trim()),
        'minBuildIos': int.tryParse(_minBuildIosCtrl.text.trim()),
        'latestBuildAndroid': int.tryParse(_latestBuildAndroidCtrl.text.trim()),
        'latestBuildIos': int.tryParse(_latestBuildIosCtrl.text.trim()),
        'minVersionAndroid': _minVersionAndroid.trim(),
        'minVersionIos': _minVersionIos.trim(),
        'storeUrlAndroid': _storeAndroidCtrl.text.trim(),
        'storeUrlIos': _storeIosCtrl.text.trim(),
        'updateImageUrl': _updateImageUrl.trim(),
        'maintenanceMode': false,
        'forceUpdate': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Politique de mise à jour enregistrée',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: adminGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: adminOrange, strokeWidth: 2),
        ),
      );
    }

    return AdminModuleSection(
      eyebrow: 'Application',
      title: 'Mises à jour store',
      subtitle:
          'Incrémente le +N dans pubspec.yaml à chaque publication, puis mets à jour les builds ci-dessous.',
      accent: adminOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            'Version installée (admin)',
            _installedVersionLabel,
            'Référence pubspec — le +N est le numéro de build.',
          ),
          const SizedBox(height: 12),
          _switchRow('Contrôle de version actif', _enabled, (v) {
            setState(() => _enabled = v);
          }),
          const SizedBox(height: 14),
          _blockLabel('Mise à jour obligatoire'),
          const SizedBox(height: 4),
          Text(
            'Build minimum : bloque l’app et ouvre le store.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AdminField(
                  ctrl: _minBuildAndroidCtrl,
                  label: 'Build min. Android',
                  keyboardType: TextInputType.number,
                  hint: 'ex. 50',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminField(
                  ctrl: _minBuildIosCtrl,
                  label: 'Build min. iOS',
                  keyboardType: TextInputType.number,
                  hint: 'ex. 50',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _blockLabel('Dernière version store'),
          const SizedBox(height: 4),
          Text(
            'Build publié : affiche la bannière « Mettre à jour » (non bloquante).',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AdminField(
                  ctrl: _latestBuildAndroidCtrl,
                  label: 'Dernier build Android',
                  keyboardType: TextInputType.number,
                  hint: 'ex. 56',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminField(
                  ctrl: _latestBuildIosCtrl,
                  label: 'Dernier build iOS',
                  keyboardType: TextInputType.number,
                  hint: 'ex. 56',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _blockLabel('Liens store'),
          const SizedBox(height: 8),
          AdminField(ctrl: _storeAndroidCtrl, label: 'Play Store'),
          const SizedBox(height: 8),
          AdminField(ctrl: _storeIosCtrl, label: 'App Store'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                'Enregistrer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: adminOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: adminTextPrimary,
      ),
    );
  }

  Widget _infoRow(String label, String value, String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminGrey,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: adminOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
