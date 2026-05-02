import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';
import 'article_editor.dart';

class ArticlesTab extends StatelessWidget {
  const ArticlesTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ARTICLES',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openEditor(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE1C15A), adminGold],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: adminGold.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.black,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'NOUVEL ARTICLE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('articles')
                .orderBy('created_at', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: adminGold),
                );
              }
              final docs = snap.data!.docs;
              final published = docs
                  .where((d) => (d.data() as Map)['status'] != 'draft')
                  .length;
              final drafts = docs.length - published;
              final featured = docs
                  .where((d) => (d.data() as Map)['featured'] == true)
                  .length;

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: adminBorder),
                        ),
                        child: const Icon(
                          Icons.article_rounded,
                          color: adminGrey,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun article',
                        style: GoogleFonts.inter(
                          color: adminGrey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _openEditor(context, null),
                        child: Text(
                          'Créer le premier article →',
                          style: GoogleFonts.inter(
                            color: adminGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // ── Stats mini bar ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        _StatPill(
                          label: 'PUBLIÉS',
                          value: '$published',
                          color: adminGreenAccent,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: 'BROUILLONS',
                          value: '$drafts',
                          color: adminGrey,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          label: 'À LA UNE',
                          value: '$featured',
                          color: adminGold,
                        ),
                        const Spacer(),
                        Text(
                          '${docs.length} total',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final isDraft = d['status'] == 'draft';
                        return _ArticleRow(
                          id: docs[i].id,
                          title: d['title'] ?? '',
                          category: d['category'] ?? '',
                          isDraft: isDraft,
                          featured: d['featured'] ?? false,
                          onEdit: () => _openEditor(context, docs[i]),
                          onDelete: () => _deleteArticle(
                            context,
                            docs[i].id,
                            d['title'] ?? '',
                          ),
                          onToggleFeatured: () => docs[i].reference.update({
                            'featured': !(d['featured'] ?? false),
                          }),
                          onToggleStatus: () => docs[i].reference.update({
                            'status': isDraft ? 'published' : 'draft',
                          }),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, DocumentSnapshot? doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminArticleEditorScreen(doc: doc)),
    );
  }

  Future<void> _deleteArticle(
    BuildContext context,
    String id,
    String title,
  ) async {
    final ok = await adminConfirm(context, 'Supprimer "$title" ?');
    if (!ok) return;
    await FirebaseFirestore.instance.collection('articles').doc(id).delete();
  }
}

// ── Ligne article ─────────────────────────────────────────────────────────────
class _ArticleRow extends StatelessWidget {
  final String id, title, category;
  final bool isDraft, featured;
  final VoidCallback onEdit, onDelete, onToggleFeatured, onToggleStatus;

  const _ArticleRow({
    required this.id,
    required this.title,
    required this.category,
    required this.isDraft,
    required this.featured,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFeatured,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isDraft
        ? adminGrey
        : (featured ? adminGold : adminGreenAccent);
    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left status accent bar
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        AdminStatusChip(
                          label: category.toUpperCase(),
                          color: adminBlue,
                        ),
                      if (category.isNotEmpty) const SizedBox(width: 5),
                      if (isDraft)
                        const AdminStatusChip(
                          label: 'BROUILLON',
                          color: adminGrey,
                        ),
                      if (featured) ...[
                        if (isDraft) const SizedBox(width: 5),
                        const AdminStatusChip(label: '★ UNE', color: adminGold),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: adminGrey,
              size: 18,
            ),
            color: const Color(0xFF1E1E1E),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (v == 'featured') onToggleFeatured();
              if (v == 'status') onToggleStatus();
            },
            itemBuilder: (_) => [
              _menuItem('edit', Icons.edit_rounded, 'Modifier'),
              _menuItem(
                'featured',
                Icons.star_rounded,
                featured ? 'Retirer une' : 'Mettre à la une',
                color: adminGold,
              ),
              _menuItem(
                'status',
                Icons.visibility_rounded,
                isDraft ? 'Publier' : 'Brouillon',
              ),
              _menuItem(
                'delete',
                Icons.delete_rounded,
                'Supprimer',
                color: adminRed,
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String v,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: v,
    child: Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.white70),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: color ?? Colors.white70,
          ),
        ),
      ],
    ),
  );
}

// ── Pilule stat ───────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withAlpha(180),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
