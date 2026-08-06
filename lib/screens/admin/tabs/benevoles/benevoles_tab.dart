import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/benevole_space_config.dart';
import '../../../../models/user_role.dart';
import '../../admin_controller.dart';
import '../../admin_actions.dart';
import '../../../../services/benevole_space_service.dart';
import '../../../../services/user_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_dialogs.dart';
import 'benevole_notifs_section.dart';
import 'benevole_postes_section.dart';

/// Admin — espace bénévoles : PDF + URL Google Sheet.
class BenevolesTab extends StatefulWidget {
  const BenevolesTab({super.key});

  @override
  State<BenevolesTab> createState() => _BenevolesTabState();
}

class _BenevolesTabState extends State<BenevolesTab> {
  final _sheetUrlCtrl = TextEditingController();
  final _sheetTitleCtrl = TextEditingController();
  bool _enabled = true;
  bool _configLoading = true;
  bool _savingConfig = false;
  bool _uploading = false;
  bool _canManageBenevoleNotifs = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadNotifAccess();
  }

  Future<void> _loadNotifAccess() async {
    final ctrl = AdminController.maybeOf(context);
    if (ctrl != null) {
      if (!mounted) return;
      setState(() {
        _canManageBenevoleNotifs =
            ctrl.canAction(AdminAction.benevoleNotifs);
      });
      return;
    }
    final data = await UserService.getUserData();
    final roles = UserService.parseRolesFromData(data);
    if (!mounted) return;
    setState(() {
      _canManageBenevoleNotifs = roles.contains(UserRole.admin);
    });
  }

  @override
  void dispose() {
    _sheetUrlCtrl.dispose();
    _sheetTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await BenevoleSpaceService.instance.getConfig();
    if (!mounted) return;
    setState(() {
      _sheetUrlCtrl.text = cfg.googleSheetUrl;
      _sheetTitleCtrl.text = cfg.googleSheetTitle;
      _enabled = cfg.enabled;
      _configLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _savingConfig = true);
    try {
      await BenevoleSpaceService.instance.saveConfig(
        BenevoleSpaceConfig(
          enabled: _enabled,
          googleSheetUrl: _sheetUrlCtrl.text.trim(),
          googleSheetTitle: _sheetTitleCtrl.text.trim().isEmpty
              ? 'Planning bénévoles'
              : _sheetTitleCtrl.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configuration enregistrée',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: adminGold.withAlpha(230),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _addDrivePdfLink() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Général');
    final driveUrlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Ajouter un PDF',
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminField(ctrl: titleCtrl, label: 'Titre'),
            const SizedBox(height: 8),
            AdminField(ctrl: categoryCtrl, label: 'Catégorie'),
            const SizedBox(height: 8),
            AdminField(ctrl: driveUrlCtrl, label: 'Lien Google Drive du PDF'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'AJOUTER',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Titre requis', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    if (driveUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lien Google Drive requis', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await BenevoleSpaceService.instance.addDriveDocument(
        title: titleCtrl.text.trim(),
        category: categoryCtrl.text.trim(),
        driveUrl: driveUrlCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document Drive ajouté', style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(230),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ajout : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_configLoading) {
      return const Center(child: CircularProgressIndicator(color: adminGold));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: 'Espace bénévoles',
            subtitle:
                'PDF planning et lien Google Sheet — visible pour les Team DVCR dans l\'app.',
            icon: Icons.volunteer_activism_rounded,
            accent: AdminModuleColors.communaute,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: adminSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Visible dans l’app pour les Team DVCR (Profil → Raccourcis). '
                      'Ajoute ici un lien Google Drive (PDF en lecture).',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Espace actif',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                      value: _enabled,
                      activeThumbColor: AdminModuleColors.communaute,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    AdminField(ctrl: _sheetTitleCtrl, label: 'Titre planning'),
                    const SizedBox(height: 8),
                    AdminField(
                      ctrl: _sheetUrlCtrl,
                      label: 'URL Google Sheet (mode édition)',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _savingConfig ? null : _saveConfig,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminModuleColors.communaute,
                        foregroundColor: Colors.white,
                      ),
                      child: _savingConfig
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'ENREGISTRER LA CONFIG',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const BenevolePostesSection(),
              const SizedBox(height: 20),
              if (_canManageBenevoleNotifs) ...[
                const BenevoleNotifsSection(),
                const SizedBox(height: 20),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: adminGrey.withAlpha(200),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Les notifications bénévoles sont réservées au rôle '
                          'Admin (pas éditeur / CM). Tu peux gérer les PDF et le '
                          'planning ci-dessus.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'DOCUMENTS PDF',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AdminModuleColors.communaute,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _uploading ? null : _addDrivePdfLink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AdminModuleColors.communaute,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.upload_file_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'AJOUTER LIEN',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder(
                stream: BenevoleSpaceService.instance.watchAllDocuments(),
                builder: (context, snap) {
                  final docs = snap.data ?? [];
                  if (docs.isEmpty) {
                    return Text(
                      'Aucun PDF.',
                      style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                    );
                  }
                  return Column(
                    children: docs.map((doc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: adminBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: adminTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${doc.category} · ${doc.published ? "publié" : "masqué"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: adminGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                doc.published
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: adminGrey,
                                size: 20,
                              ),
                              onPressed: () => BenevoleSpaceService.instance
                                  .setDocumentPublished(
                                doc.id,
                                !doc.published,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: adminRed,
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await adminConfirm(
                                  context,
                                  'Supprimer « ${doc.title} » ?',
                                );
                                if (confirm == true) {
                                  await BenevoleSpaceService.instance
                                      .deleteDocument(doc);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
