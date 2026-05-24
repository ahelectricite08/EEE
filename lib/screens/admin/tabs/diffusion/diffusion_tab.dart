import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_controller.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import '../notifs/match_reminder_tab.dart';
import '../notifs/notifs_tab.dart';

/// Push manuelle + rappel match (un seul onglet sidebar).
class DiffusionTab extends StatefulWidget {
  const DiffusionTab({super.key});

  @override
  State<DiffusionTab> createState() => _DiffusionTabState();
}

class _DiffusionTabState extends State<DiffusionTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  AdminController? _controller;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AdminControllerProvider.of(context);
    if (_controller != ctrl) {
      _controller?.removeListener(_syncSubTab);
      _controller = ctrl;
      _controller!.addListener(_syncSubTab);
      _applySubTab(ctrl.diffusionSubTab);
    }
  }

  void _syncSubTab() {
    if (!mounted) return;
    _applySubTab(_controller?.diffusionSubTab ?? 0);
  }

  void _applySubTab(int index) {
    if (_tabs.index != index) {
      _tabs.animateTo(index.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncSubTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: AdminModuleHeader(
            title: 'Diffusion',
            subtitle:
                'Notifications push manuelles et rappels match Sedan avant coup d’envoi.',
            icon: Icons.send_rounded,
            accent: adminPurple,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            controller: _tabs,
            onTap: (i) => _controller?.setDiffusionSubTab(i),
            indicatorColor: adminGold,
            labelColor: adminTextPrimary,
            unselectedLabelColor: adminGrey,
            labelStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            tabs: const [
              Tab(text: 'PUSH MANUELLE'),
              Tab(text: 'RAPPEL MATCH'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              NotifsTab(embedded: true),
              MatchReminderTab(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
