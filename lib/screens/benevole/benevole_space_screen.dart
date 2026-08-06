import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/benevole_document.dart';
import '../../models/benevole_space_config.dart';
import '../../services/benevole_space_service.dart';
import '../home/home_palette.dart';
import 'benevole_disponibilites_tab.dart';
import 'benevole_pdf_screen.dart';

/// Espace bénévoles — Team DVCR : dispo Make + PDF + Google Sheet.
class BenevoleSpaceScreen extends StatefulWidget {
  const BenevoleSpaceScreen({super.key});

  @override
  State<BenevoleSpaceScreen> createState() => _BenevoleSpaceScreenState();
}

class _BenevoleSpaceScreenState extends State<BenevoleSpaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // no-op
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openSheetExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSheetInApp(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: homeBg,
      appBar: AppBar(
        backgroundColor: homeBg,
        foregroundColor: homeText,
        elevation: 0,
        title: Text(
          'Espace bénévoles',
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: homeGold,
          labelColor: homeGold,
          unselectedLabelColor: homeMutedText,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          isScrollable: true,
          tabs: const [
            Tab(text: 'DISPONIBILITÉS'),
            Tab(text: 'DOCUMENTS'),
            Tab(text: 'PLANNING'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const BenevoleDisponibilitesTab(),
          _DocumentsTab(
            onOpenPdf: (title, url) {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BenevolePdfScreen(title: title, fileUrl: url),
                ),
              );
            },
          ),
          StreamBuilder<BenevoleSpaceConfig>(
            stream: BenevoleSpaceService.instance.watchConfig(),
            builder: (context, cfgSnap) {
              final cfg = cfgSnap.data ?? const BenevoleSpaceConfig();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: homeSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: homeBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          cfg.googleSheetTitle,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: homeText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Le planning s’ouvre directement dans Google Sheets pour naviguer / modifier plus facilement.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: homeMutedText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openSheetInApp(cfg.googleSheetUrl),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Ouvrir le planning'),
                          style: FilledButton.styleFrom(
                            backgroundColor: homeGreen,
                            foregroundColor: homeSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openSheetExternally(cfg.googleSheetUrl),
                          icon: const Icon(Icons.launch_rounded, size: 16),
                          label: const Text('Ouvrir dans Google Sheets'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Astuce : connecte-toi avec ton compte Google pour éditer.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: homeMutedText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final void Function(String title, String url) onOpenPdf;

  const _DocumentsTab({required this.onOpenPdf});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: BenevoleSpaceService.instance.watchPublishedDocuments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: homeGreen,
              strokeWidth: 2,
            ),
          );
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Aucun document pour le moment.\nL’équipe DVCR ajoutera les PDF ici.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: homeMutedText,
                  height: 1.45,
                ),
              ),
            ),
          );
        }

        final byCategory = <String, List<BenevoleDocument>>{};
        for (final d in docs) {
          byCategory.putIfAbsent(d.category, () => []).add(d);
        }
        final categories = byCategory.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final cat in categories) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  cat.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: homeGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (final doc in byCategory[cat]!)
                _DocTile(
                  title: doc.title,
                  subtitle: doc.fileName ?? 'PDF',
                  onTap: () => onOpenPdf(doc.title, doc.fileUrl),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: homeSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: homeBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: homeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: homeGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: homeText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: homeMutedText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: homeMutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
