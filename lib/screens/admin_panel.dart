// Re-export shim — AdminPanel is now AdminShell.
export 'admin/admin_shell.dart' show AdminShell, AdminToolbarMode;
import 'package:flutter/material.dart';
import 'admin/admin_shell.dart';

/// Point d’entrée admin : [toolbarMode] pilote retour profil (app) vs web.
class AdminPanel extends StatelessWidget {
  final AdminToolbarMode toolbarMode;
  const AdminPanel({super.key, this.toolbarMode = AdminToolbarMode.embeddedFromApp});

  @override
  Widget build(BuildContext context) => AdminShell(toolbarMode: toolbarMode);
}
