import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/global_search_service.dart';
import '../../widgets/dvcr_reveal.dart';
import '../../widgets/dvcr_share_favorite_controls.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../articles_screen.dart';
import '../match_detail_screen.dart';
import '../video_web_screen.dart';

const _kBg = Color(0xFFF5F2E9);
const _kCard = Color(0xFFFFFCF8);
const _kCardSoft = Color(0xFFEAF5F0);
const _kBorder = Color(0xFFD8D2C4);
const _kGreen = Color(0xFF0A4438);
const _kGreenDeep = Color(0xFF062921);
const _kGold = Color(0xFFC8A436);
const _kGrey = Color(0xFF5C6560);
const _kText = Color(0xFF1A2522);
const _kRed = Color(0xFFBA203C);

class GlobalSearchScreen extends StatefulWidget {
  /// Si fourni (overlay depuis [MainNavigation]), ferme sans route plein écran.
  final VoidCallback? onDismiss;

  const GlobalSearchScreen({super.key, this.onDismiss});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  GlobalSearchPayload? _payload;
  List<SearchResultItem> _results = const [];
  bool _loading = true;
  Timer? _debounce;
  SearchResultType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final payload = await GlobalSearchService.load();
    if (!mounted) return;
    setState(() {
      _payload = payload;
      _loading = false;
    });
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      final payload = _payload;
      if (payload == null) return;
      setState(() {
        _results = GlobalSearchService.search(payload, _controller.text);
        if (_typeFilter != null &&
            !_results.any((e) => e.type == _typeFilter)) {
          _typeFilter = null;
        }
      });
    });
  }

  List<SearchResultItem> get _visible {
    if (_typeFilter == null) return _results;
    return _results.where((e) => e.type == _typeFilter).toList();
  }

  void _openResult(SearchResultItem item) {
    HapticFeedback.lightImpact();
    switch (item.type) {
      case SearchResultType.article:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(article: item.article!),
          ),
        );
        break;
      case SearchResultType.match:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(match: item.match!),
          ),
        );
        break;
      case SearchResultType.video:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoWebScreen(video: item.video!),
          ),
        );
        break;
    }
  }

  void _close() {
    final d = widget.onDismiss;
    if (d != null) {
      d();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Color _typeAccent(SearchResultType t) {
    switch (t) {
      case SearchResultType.article:
        return _kGold;
      case SearchResultType.match:
        return _kGreen;
      case SearchResultType.video:
        return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.onDismiss != null;
    final insetBottom = MediaQuery.of(context).viewInsets.bottom;
    final q = _controller.text.trim();
    final visible = _visible;

    return PopScope(
      canPop: !embedded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && embedded) _close();
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !embedded,
          leading: embedded
              ? IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close_rounded),
                  color: _kGreen,
                  onPressed: _close,
                )
              : null,
          iconTheme: const IconThemeData(color: _kGreen),
          title: Text(
            'RECHERCHE',
            style: GoogleFonts.barlowCondensed(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _kGreen,
              letterSpacing: 1.6,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 10 + insetBottom * 0.25),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _kGold.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kGreenDeep.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _kText,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: _kGreen),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: Icon(
                              Icons.close_rounded,
                              color: _kGrey.withValues(alpha: 0.75),
                            ),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = const [];
                                _typeFilter = null;
                              });
                            },
                          ),
                    hintText: 'Actu, match, vidéo…',
                    hintStyle: GoogleFonts.inter(
                      color: _kGrey,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 4,
                    ),
                  ),
                ),
              ),
            ),
            if (!_loading && q.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tout',
                        selected: _typeFilter == null,
                        onTap: () => setState(() => _typeFilter = null),
                      ),
                      _FilterChip(
                        label: 'Articles',
                        selected: _typeFilter == SearchResultType.article,
                        onTap: () => setState(
                          () => _typeFilter = SearchResultType.article,
                        ),
                      ),
                      _FilterChip(
                        label: 'Matchs',
                        selected: _typeFilter == SearchResultType.match,
                        onTap: () =>
                            setState(() => _typeFilter = SearchResultType.match),
                      ),
                      _FilterChip(
                        label: 'Vidéos',
                        selected: _typeFilter == SearchResultType.video,
                        onTap: () =>
                            setState(() => _typeFilter = SearchResultType.video),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Expanded(
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: 5,
                      itemBuilder: (context, index) =>
                          const DVCRSearchSkeleton(),
                    )
                  : q.isEmpty
                  ? const _SearchWelcome()
                  : visible.isEmpty
                  ? _SearchEmptyState(
                      hadFilter: _typeFilter != null && _results.isNotEmpty,
                      onClearFilter: _typeFilter != null
                          ? () => setState(() => _typeFilter = null)
                          : null,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + insetBottom),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return DVCRReveal(
                          delay: Duration(milliseconds: 28 * index),
                          child: _SearchResultTile(
                            item: item,
                            accent: _typeAccent(item.type),
                            onTap: () => _openResult(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kGreen : _kCard,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? _kGreen
                    : _kBorder.withValues(alpha: 0.9),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _kText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchWelcome extends StatelessWidget {
  const _SearchWelcome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kCard,
                _kCardSoft,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kGreenDeep.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: _kGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Explore tout DVCR',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _kText,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Tape un mot-clé : titre d’article, équipe, compétition, ou titre de vidéo. Les résultats se mettent à jour tout seuls.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kGrey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _HintRow(
                icon: Icons.article_outlined,
                color: _kGold,
                text: 'Articles & catégories',
              ),
              const SizedBox(height: 10),
              _HintRow(
                icon: Icons.sports_soccer_rounded,
                color: _kGreen,
                text: 'Matchs & clubs',
              ),
              const SizedBox(height: 10),
              _HintRow(
                icon: Icons.play_circle_outline_rounded,
                color: _kRed,
                text: 'Replay & DVCR TV',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _HintRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final bool hadFilter;
  final VoidCallback? onClearFilter;

  const _SearchEmptyState({
    required this.hadFilter,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kGreenDeep.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hadFilter ? Icons.filter_alt_off_rounded : Icons.search_off_rounded,
                size: 40,
                color: _kGold.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 12),
              Text(
                hadFilter ? 'Rien dans ce filtre' : 'Aucun résultat',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hadFilter
                    ? 'Essaie un autre onglet ou élargis ta recherche.'
                    : 'Essaie un autre mot-clé ou le nom d’une équipe.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _kGrey,
                  height: 1.4,
                ),
              ),
              if (hadFilter && onClearFilter != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.layers_clear_rounded, size: 18),
                  label: Text(
                    'Voir tous les types',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultShareFavorite extends StatelessWidget {
  final SearchResultItem item;

  const _SearchResultShareFavorite({required this.item});

  @override
  Widget build(BuildContext context) {
    final muted = _kGrey.withValues(alpha: 0.92);
    switch (item.type) {
      case SearchResultType.article:
        final a = item.article;
        if (a == null) return const SizedBox.shrink();
        return DvcrArticleShareFavoriteRow(
          article: a,
          mutedIconColor: muted,
          activeFavoriteColor: _kGold,
        );
      case SearchResultType.match:
        final m = item.match;
        if (m == null) return const SizedBox.shrink();
        return DvcrMatchShareFavoriteRow(
          match: m,
          mutedIconColor: _kGreen.withValues(alpha: 0.55),
          activeFavoriteColor: _kGold,
        );
      case SearchResultType.video:
        final v = item.video;
        if (v == null) return const SizedBox.shrink();
        return DvcrVideoShareFavoriteRow(
          video: v,
          mutedIconColor: _kRed.withValues(alpha: 0.72),
          activeFavoriteColor: _kGold,
        );
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResultItem item;
  final Color accent;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: _kGreenDeep.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(17),
                    ),
                    color: accent,
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        child: Row(
                          children: [
                            _SearchThumb(item: item, accent: accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _typeLabel(item.type),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _kText,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.subtitle} · ${item.meta}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _kGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _kGreen.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
                    child: _SearchResultShareFavorite(item: item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _typeLabel(SearchResultType type) {
    switch (type) {
      case SearchResultType.article:
        return 'ARTICLE';
      case SearchResultType.match:
        return 'MATCH';
      case SearchResultType.video:
        return 'VIDÉO';
    }
  }
}

class _SearchThumb extends StatelessWidget {
  final SearchResultItem item;
  final Color accent;

  const _SearchThumb({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      SearchResultType.article => Icons.article_outlined,
      SearchResultType.match => Icons.sports_soccer_rounded,
      SearchResultType.video => Icons.play_circle_outline_rounded,
    };

    final imageUrl = item.imageUrl;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: _kCardSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(child: Icon(icon, color: accent, size: 26));
              },
            )
          : Center(child: Icon(icon, color: accent, size: 26)),
    );
  }
}
