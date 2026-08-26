part of 'prono_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Pages sociales Pronos — « Journal du Sanglier ».
//
//  Langages utilisés ici :
//   · ENCRE     UNE dalle pleine largeur par écran, jamais deux :
//                 Ligues        → comptoir « Rejoindre un salon »
//                 Salon         → en-tête de ligue (talon d’invitation papier)
//                 Classement    → bandeau « ta place »
//                 Détail duel   → tableau d’affichage
//                 Score duel    → zone de saisie
//                 Amis · Duels · Top ligues → aucune (papier + réglure)
//   · RÉGLURE   annuaires (ligues, amis, duels, sélecteurs)
//   · TABLE     classements (ligue, global, top ligues) — entièrement papier
//   · VESTIAIRE panneaux à casquette rouge (créer une ligue, demandes reçues)
//
//  Accent de toutes ces pages : rouge club. L’or reste réservé à la
//  distinction (ta place, code de salon, podium, victoire).
// ═══════════════════════════════════════════════════════════════════════════

const _socialPageAccent = PronoPageAccent.social;

/// Gouttière éditoriale des pages sociales.
const double _clubGutter = 20;

// ── Chrome de page ─────────────────────────────────────────────────────────

class _SocialAppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SocialAppBarTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.title,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PronoType.meta,
            ),
          ],
        ],
      ),
    );
  }
}

/// Filet d’accent sous la barre — la signature rouge des pages sociales.
const _socialAppBarRuleHeight = 3.0;

double _socialAppBarHeight(BuildContext context) {
  final topPad = MediaQuery.paddingOf(context).top;
  return topPad + kToolbarHeight + _socialAppBarRuleHeight;
}

PreferredSizeWidget _buildSocialPageAppBar({
  required BuildContext context,
  required String title,
  required String subtitle,
}) {
  final accent = _socialPageAccent.color;
  final topPad = MediaQuery.paddingOf(context).top;

  return PreferredSize(
    preferredSize: Size.fromHeight(_socialAppBarHeight(context)),
    child: Material(
      color: PronoArenaTheme.scaffoldTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPad),
          SizedBox(
            height: kToolbarHeight,
            child: AppBar(
              // Safe-area already applied via SizedBox(topPad) above.
              // primary:true would nest another SafeArea and squash the
              // toolbar inside this fixed-height box (broken social headers).
              primary: false,
              backgroundColor: PronoArenaTheme.scaffoldTop,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: kToolbarHeight,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: PronoTokens.text,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              leadingWidth: 46,
              titleSpacing: 0,
              centerTitle: false,
              title: Align(
                alignment: Alignment.centerLeft,
                child: _SocialAppBarTitle(
                  title: title,
                  subtitle: subtitle,
                ),
              ),
            ),
          ),
          Container(height: _socialAppBarRuleHeight, color: accent),
        ],
      ),
    ),
  );
}

const _leaderboardFootnote =
    'Classement saison prono DVCR : points cumulés sur tous les matchs de '
    'championnat (les duels ne comptent pas). 3 pts pour un score exact, '
    '1 pt pour le bon résultat 1-X-2, 0 sinon. Top 20 + ta place et tes '
    'voisins, mis à jour après chaque match.';

class _LeaderboardEmptyCard extends StatelessWidget {
  const _LeaderboardEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const PronoEmptyState(
      icon: Icons.leaderboard_outlined,
      title: 'Pas encore de classement',
      body:
          'Dès qu’un match est joué, les points sont calculés et les pronostiqueurs apparaissent ici.',
      pageAccent: PronoPageAccent.social,
    );
  }
}

/// Coquille commune. [child] = contenu dans la gouttière (comportement
/// historique). [slivers] = échappatoire pleine largeur pour les blocs d’encre.
class _PronoSocialPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;
  final List<Widget>? slivers;

  const _PronoSocialPageScaffold({
    required this.title,
    required this.subtitle,
    this.child,
    this.slivers,
  }) : assert(
          child != null || slivers != null,
          'Fournir soit child (gouttière) soit slivers (pleine largeur).',
        );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PronoThemeScope(
      pageAccent: _socialPageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildSocialPageAppBar(
            context: context,
            title: title,
            subtitle: subtitle,
          ),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              clipBehavior: Clip.hardEdge,
              physics: const BouncingScrollPhysics(),
              slivers: slivers != null
                  ? [
                      ...slivers!,
                      SliverToBoxAdapter(
                        child: SizedBox(height: 28 + bottom),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          _clubGutter,
                          14,
                          _clubGutter,
                          24 + bottom,
                        ),
                        sliver: SliverToBoxAdapter(child: child!),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Kit local « _Club » — pièces propres aux pages sociales.
// ═══════════════════════════════════════════════════════════════════════════

/// Champ papier à filet bas — kicker au-dessus, jamais de boîte Material.
class _ClubRuleField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  const _ClubRuleField({
    required this.controller,
    required this.label,
    this.hint = '',
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _socialPageAccent.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: PronoType.kicker),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: PronoType.body,
          cursorColor: accent,
          cursorWidth: 2,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: PronoType.body.copyWith(
              color: PronoArenaTheme.textSoft,
            ),
            contentPadding: const EdgeInsets.only(top: 6, bottom: 9),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PronoArenaTheme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Comptoir d’accueil — la dalle d’encre unique de la page Ligues. Rejoindre
/// un salon est l’acte premier de l’écran : c’est lui qui mérite la matière.
class _ClubReceptionDesk extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onJoin;

  const _ClubReceptionDesk({
    required this.controller,
    required this.busy,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        tint: _socialPageAccent.deep,
        goldEdge: true,
        photoSlot: PronoBannerSlot.leaguesSlab,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(_clubGutter, 24, _clubGutter, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VESTIAIRE', style: PronoType.kickerGold),
              const SizedBox(height: 12),
              Text(
                'Rejoindre un salon',
                style: PronoType.headline.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Un pote t’a donné un code ? Tape-le ici, tu entres dans sa '
                'ligue tout de suite.',
                style: PronoType.caption.copyWith(
                  color: PronoArenaTheme.onInkMuted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CODE DU SALON', style: PronoType.kickerOnInk),
                        const SizedBox(height: 2),
                        TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onJoin(),
                          cursorColor: PronoArenaTheme.gold,
                          cursorWidth: 2,
                          style: PronoType.codeStamp.copyWith(
                            fontSize: 30,
                            letterSpacing: 5,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'ABC123',
                            hintStyle: PronoType.codeStamp.copyWith(
                              fontSize: 30,
                              letterSpacing: 5,
                              color: PronoArenaTheme.onInkSoft,
                            ),
                            contentPadding: const EdgeInsets.only(
                              top: 8,
                              bottom: 8,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: PronoArenaTheme.onInkSoft,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: PronoArenaTheme.gold,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: busy ? null : onJoin,
                      child: Ink(
                        color: busy
                            ? PronoArenaTheme.onInkSoft
                            : PronoArenaTheme.gold,
                        child: SizedBox(
                          width: 66,
                          height: 52,
                          child: Center(
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: PronoArenaTheme.ink,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'OK',
                                    style: PronoType.cta.copyWith(
                                      color: PronoArenaTheme.ink,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête d’encre pleine largeur — titre de salon / de moment. C’est la dalle
/// unique de sa page : le talon d’invitation qu’on y pose reste du papier.
class _ClubInkPageHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String? meta;
  final Widget? child;
  final Color? tint;

  const _ClubInkPageHeader({
    required this.kicker,
    required this.title,
    this.meta,
    this.child,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        tint: tint,
        photoSlot: PronoBannerSlot.leaguesSlab,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(_clubGutter, 22, _clubGutter, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kicker.toUpperCase(), style: PronoType.kickerGold),
              const SizedBox(height: 12),
              Text(
                title,
                style: PronoType.headline.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                ),
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta!,
                  style: PronoType.caption.copyWith(
                    color: PronoArenaTheme.onInkMuted,
                  ),
                ),
              ],
              if (child != null) ...[
                const SizedBox(height: 20),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chiffre de gouttière + légende — l’ancre visuelle des annuaires.
class _ClubGutterNumeral extends StatelessWidget {
  final String value;
  final String caption;

  const _ClubGutterNumeral({required this.value, this.caption = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: PronoType.numeralGutter.copyWith(fontSize: 30),
        ),
        if (caption.isNotEmpty)
          Text(
            caption.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.kicker.copyWith(
              fontSize: 8,
              letterSpacing: 1.2,
              color: PronoArenaTheme.textSoft,
            ),
          ),
      ],
    );
  }
}

/// Initiale de gouttière — un carré d’encre légère, pas un avatar Material.
class _ClubInitialMark extends StatelessWidget {
  final String name;

  const _ClubInitialMark({required this.name});

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final initial = clean.isEmpty ? '?' : clean[0].toUpperCase();
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _socialPageAccent.wash,
        border: Border.all(color: PronoArenaTheme.hairline),
      ),
      child: Text(
        initial,
        style: PronoType.title.copyWith(
          fontSize: 19,
          color: _socialPageAccent.color,
        ),
      ),
    );
  }
}

/// Tampon de code — petites capitales suivies, comme un cachet de club.
class _ClubCodeStamp extends StatelessWidget {
  final String code;

  const _ClubCodeStamp({required this.code});

  @override
  Widget build(BuildContext context) {
    final clean = code.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: PronoArenaTheme.edgeHighlight),
      ),
      child: Text(
        clean.toUpperCase(),
        style: PronoType.kicker.copyWith(
          fontSize: 11,
          letterSpacing: 2.2,
          color: PronoArenaTheme.text,
        ),
      ),
    );
  }
}

/// Ligne d’annuaire — filet bas, gouttière, pas de carte.
///
/// Sélection : barre d’encre à gauche + papier teinté tant que le doigt est
/// posé, pour que « je choisis cette ligne » soit lisible sur les sélecteurs.
class _ClubDirectoryRow extends StatefulWidget {
  final Widget gutter;
  final String title;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ClubDirectoryRow({
    required this.gutter,
    required this.title,
    this.meta,
    this.trailing,
    this.onTap,
  });

  @override
  State<_ClubDirectoryRow> createState() => _ClubDirectoryRowState();
}

class _ClubDirectoryRowState extends State<_ClubDirectoryRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final gutter = widget.gutter;
    final title = widget.title;
    final meta = widget.meta;
    final trailing = widget.trailing;
    final onTap = widget.onTap;
    final selected = _pressed && onTap != null;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(_clubGutter, 15, _clubGutter, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 42, child: gutter),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.title.copyWith(fontSize: 21),
                ),
                if (meta != null && meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.meta,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ] else if (onTap != null) ...[
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: PronoArenaTheme.textSoft,
            ),
          ],
        ],
      ),
    );

    final decorated = AnimatedContainer(
      duration: PronoArenaTheme.animFast,
      curve: PronoArenaTheme.animCurve,
      decoration: BoxDecoration(
        color: selected ? _socialPageAccent.wash : Colors.transparent,
        border: Border(
          bottom: const BorderSide(color: PronoArenaTheme.hairline),
          left: BorderSide(
            color: selected ? PronoArenaTheme.ink : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: content,
    );

    if (onTap == null) return decorated;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: decorated,
    );
  }
}

/// Puce d’action compacte en encre — « Défier », « Voir ».
class _ClubActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ClubActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: PronoArenaTheme.inkSlab(radius: 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Text(
              label.toUpperCase(),
              style: PronoType.kicker.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action texte compacte — accepter / refuser / ajouter.
class _ClubTextAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ClubTextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: PronoType.kicker.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Container(width: 22, height: 2, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action texte posée sur l’encre — filet blanc, pas un bouton Material.
class _ClubInkTextAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ClubInkTextAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: PronoArenaTheme.onInkSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 9),
                  Text(
                    label.toUpperCase(),
                    style: PronoType.kicker.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Note discrète de section — remplace les « labels vides » gris.
class _ClubQuietNote extends StatelessWidget {
  final String text;

  const _ClubQuietNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.fromLTRB(_clubGutter, 14, _clubGutter, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 16,
            margin: const EdgeInsets.only(top: 1, right: 12),
            color: PronoArenaTheme.edgeHighlight,
          ),
          Expanded(child: Text(text, style: PronoType.caption)),
        ],
      ),
    );
  }
}

/// Ligne de registre — libellé à gauche, valeur alignée à droite.
class _ClubLedgerRow extends StatelessWidget {
  final String label;
  final String meta;
  final String value;

  const _ClubLedgerRow({
    required this.label,
    required this.meta,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.fromLTRB(_clubGutter, 14, _clubGutter, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(meta, style: PronoType.meta),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: PronoType.scoreCompact.copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

/// Repère de statut — un mot en kicker, un filet de 3px, jamais une pilule.
class _ClubStatusMark extends StatelessWidget {
  final String label;
  final Color color;

  const _ClubStatusMark({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 22, height: 3, color: color),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.kicker.copyWith(fontSize: 9, color: color),
        ),
      ],
    );
  }
}

Color _clubDuelStatusColor(String label) {
  switch (label) {
    case 'GAGNÉ':
      return PronoArenaTheme.gold;
    case 'EN COURS':
      return _socialPageAccent.color;
    case 'PERDU':
    case 'ANNULÉ':
    case 'REFUSÉ':
      return PronoArenaTheme.textSoft;
    default:
      return PronoArenaTheme.edgeHighlight;
  }
}

String _clubDuelStatusLabel(Map<String, dynamic> duel, String uid) {
  final status = (duel['status'] ?? 'pending').toString();
  return status == 'won'
      ? ((duel['winnerUid'] == uid) ? 'GAGNÉ' : 'PERDU')
      : status == 'draw'
          ? 'NUL'
          : status == 'cancelled'
              ? 'ANNULÉ'
              : status == 'declined'
                  ? 'REFUSÉ'
                  : status == 'in_progress'
                      ? 'EN COURS'
                      : 'EN ATTENTE';
}

/// Ligne de duel — réglure, adversaire, face-à-face en chiffres condensés.
class _ClubDuelRow extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> duel;
  final VoidCallback onTap;

  const _ClubDuelRow({
    required this.uid,
    required this.duel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (duel['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final isOpponent = (duel['opponentUid'] ?? '') == uid;
    final label = _clubDuelStatusLabel(duel, uid);
    final matchLabel = (duel['matchLabel'] ?? 'Duel').toString();

    // Duel reçu non traité : la ligne porte elle-même accepter / refuser.
    if (isPending && isOpponent) {
      return Container(
        decoration: PronoArenaTheme.fixtureTape(),
        padding: const EdgeInsets.fromLTRB(_clubGutter, 15, _clubGutter, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClubStatusMark(
              label: 'ON TE DÉFIE',
              color: _socialPageAccent.color,
            ),
            const SizedBox(height: 10),
            Text(
              (duel['ownerName'] ?? 'Un membre').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PronoType.title,
            ),
            const SizedBox(height: 3),
            Text(matchLabel, style: PronoType.meta),
            const SizedBox(height: 6),
            Row(
              children: [
                _ClubTextAction(
                  label: 'Accepter',
                  color: PronoArenaTheme.greenBright,
                  onTap: () async {
                    final duelId = duel['id']?.toString() ?? '';
                    await PronoSocialService.acceptDuel(duelId: duelId);
                    if (!context.mounted) return;
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => PronoDuelPickPage(
                          duelId: duelId,
                          currentUid: uid,
                          matchLabel: matchLabel,
                        ),
                      ),
                    );
                    if (saved == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Score duel enregistré',
                            style: PronoType.label.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 14),
                _ClubTextAction(
                  label: 'Refuser',
                  color: PronoArenaTheme.textSoft,
                  onTap: () => PronoSocialService.declineDuel(
                    duelId: duel['id']?.toString() ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final opponentName = isOpponent
        ? (duel['ownerName'] ?? 'Membre').toString()
        : (duel['opponentName'] ?? 'Membre').toString();
    final minePoints = isOpponent ? duel['opponentPoints'] : duel['ownerPoints'];
    final theirPoints =
        isOpponent ? duel['ownerPoints'] : duel['opponentPoints'];
    final statusColor = _clubDuelStatusColor(label);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _socialPageAccent.color.withValues(alpha: 0.06),
        highlightColor: _socialPageAccent.color.withValues(alpha: 0.04),
        child: Ink(
          decoration: PronoArenaTheme.fixtureTape(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _clubGutter,
              15,
              _clubGutter,
              15,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 74,
                  child: _ClubStatusMark(label: label, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.title.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        matchLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  minePoints?.toString() ?? '—',
                  style: PronoType.scoreCompact.copyWith(fontSize: 26),
                ),
                Container(
                  width: 2,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  color: PronoArenaTheme.gold,
                ),
                Text(
                  theirPoints?.toString() ?? '—',
                  style: PronoType.scoreCompact.copyWith(
                    fontSize: 26,
                    color: PronoArenaTheme.textMuted,
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

/// Tableau d’affichage du duel — deux noms, deux chiffres, une arête d’or.
/// Dalle d’encre unique de la page de détail : tout le reste y est en réglure.
class _ClubDuelScoreboard extends StatelessWidget {
  final String kicker;
  final String matchLabel;
  final String leftName;
  final String leftValue;
  final String rightName;
  final String rightValue;

  const _ClubDuelScoreboard({
    required this.kicker,
    required this.matchLabel,
    required this.leftName,
    required this.leftValue,
    required this.rightName,
    required this.rightValue,
  });

  Widget _side(String name, String value, {required bool alignRight}) {
    final align = alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: PronoType.label.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment:
                alignRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              value,
              style: PronoType.numeralStage.copyWith(fontSize: 64),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(_clubGutter, 22, _clubGutter, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kicker.toUpperCase(), style: PronoType.kickerGold),
              const SizedBox(height: 10),
              Text(
                matchLabel,
                style: PronoType.headline.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _side(leftName, leftValue, alignRight: false),
                  Container(
                    width: 2,
                    height: 62,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: PronoArenaTheme.gold,
                  ),
                  _side(rightName, rightValue, alignRight: true),
                ],
              ),
              const SizedBox(height: 14),
              Text('POINTS DU DUEL', style: PronoType.kickerOnInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saisie d’un chiffre de score posée sur l’encre.
class _ClubScoreField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _ClubScoreField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.kickerOnInk,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          cursorColor: PronoArenaTheme.gold,
          style: PronoType.numeralStage.copyWith(fontSize: 62),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            hintStyle: PronoType.numeralStage.copyWith(
              fontSize: 62,
              color: PronoArenaTheme.onInkSoft,
            ),
            contentPadding: const EdgeInsets.only(bottom: 6),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PronoArenaTheme.onInkSoft),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PronoArenaTheme.gold, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Demande d’ami en attente — ligne filetée dans le panneau vestiaire.
class _ClubPendingRequestRow extends StatelessWidget {
  final String requestId;
  final String currentUid;
  final String currentName;
  final String otherUid;
  final String otherName;
  final bool last;

  const _ClubPendingRequestRow({
    required this.requestId,
    required this.currentUid,
    required this.currentName,
    required this.otherUid,
    required this.otherName,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: last
          ? const BoxDecoration()
          : PronoArenaTheme.fixtureTape(),
      padding: EdgeInsets.only(bottom: last ? 0 : 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ClubInitialMark(name: otherName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text('veut devenir ton ami', style: PronoType.meta),
              ],
            ),
          ),
          _ClubTextAction(
            label: 'Accepter',
            color: PronoArenaTheme.greenBright,
            onTap: () async {
              await PronoSocialService.acceptFriendRequest(
                requestId: requestId,
                currentUid: currentUid,
                currentName: currentName,
                otherUid: otherUid,
                otherName: otherName,
              );
            },
          ),
          _ClubTextAction(
            label: 'Refuser',
            color: PronoArenaTheme.textSoft,
            onTap: () async {
              await PronoSocialService.declineFriendRequest(
                requestId: requestId,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AMIS
// ═══════════════════════════════════════════════════════════════════════════

class PronoFriendsPage extends StatefulWidget {
  final String currentUid;
  final String displayName;

  const PronoFriendsPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  State<PronoFriendsPage> createState() => _PronoFriendsPageState();
}

class _PronoFriendsPageState extends State<PronoFriendsPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _didSearch = false;
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _didSearch = true;
        _searchError = 'Saisis au moins 2 caractères.';
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _didSearch = true;
    });
    try {
      final found = await PronoSocialService.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = found
            .where((user) => (user['uid'] ?? '') != widget.currentUid)
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
        _searchError = 'Recherche impossible. Réessaie.';
      });
    }
  }

  Future<void> _invite(String otherUid, String otherName) async {
    await PronoSocialService.sendFriendRequest(
      fromUid: widget.currentUid,
      fromName: widget.displayName,
      toUid: otherUid,
      toName: otherName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation envoyée à $otherName'),
        backgroundColor: _kGreen,
      ),
    );
  }

  Widget _sectionHeader(String title, {String? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_clubGutter, 24, _clubGutter, 6),
      child: PronoSectionHeader(
        title: title,
        countLabel: count,
        pageAccent: _socialPageAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Amis',
      subtitle: 'Invitations, amis confirmés et recherche.',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(widget.currentUid),
            builder: (context, userSnap) {
              final loadingFriends =
                  userSnap.connectionState == ConnectionState.waiting &&
                      !userSnap.hasData;
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friendNames =
                  (social['friendNames'] as Map<String, dynamic>?) ?? const {};
              final friendIds =
                  (social['friends'] as List?)?.whereType<String>().toList() ??
                  const <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.friendRequestsForUser(
                  widget.currentUid,
                ),
                builder: (context, receivedSnap) {
                  final received = receivedSnap.data?.docs ?? const [];
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: PronoSocialService.sentFriendRequestsForUser(
                      widget.currentUid,
                    ),
                    builder: (context, sentSnap) {
                      final sent = sentSnap.data?.docs ?? const [];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (received.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                _clubGutter,
                                18,
                                _clubGutter,
                                0,
                              ),
                              child: PronoRoomPanel(
                                eyebrow: 'Demandes reçues',
                                accent: _socialPageAccent,
                                trailing: Text(
                                  '${received.length}',
                                  style: PronoType.meta,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < received.length; i++)
                                      Builder(
                                        builder: (context) {
                                          final data = received[i].data();
                                          return _ClubPendingRequestRow(
                                            requestId: received[i].id,
                                            currentUid: widget.currentUid,
                                            currentName: widget.displayName,
                                            otherUid:
                                                (data['fromUid'] ?? '')
                                                    .toString(),
                                            otherName:
                                                (data['fromName'] ??
                                                        'Utilisateur')
                                                    .toString(),
                                            last: i == received.length - 1,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (sent.isNotEmpty) ...[
                            _sectionHeader(
                              'Invitations envoyées',
                              count: '${sent.length}',
                            ),
                            ...sent.map((request) {
                              final data = request.data();
                              final name =
                                  (data['toName'] ?? 'Utilisateur').toString();
                              return _ClubDirectoryRow(
                                gutter: _ClubInitialMark(name: name),
                                title: name,
                                meta: 'En attente de réponse',
                                trailing: Text(
                                  'EN ATTENTE',
                                  style: PronoType.kicker.copyWith(
                                    fontSize: 9,
                                    color: PronoArenaTheme.textSoft,
                                  ),
                                ),
                              );
                            }),
                          ],
                          _sectionHeader(
                            'Amis confirmés',
                            count: loadingFriends ? null : '${friendIds.length}',
                          ),
                          if (loadingFriends)
                            const PronoLoadingTape(rows: 3)
                          else if (friendIds.isEmpty)
                            PronoEmptyState(
                              icon: Icons.person_add_alt_1_outlined,
                              title: 'Personne dans ton vestiaire',
                              body: received.isEmpty
                                  ? 'Cherche un supporter par pseudo ou email juste en dessous, envoie-lui une invitation et vous pourrez vous défier.'
                                  : 'Accepte une demande ci-dessus, ou cherche un supporter par pseudo ou email juste en dessous.',
                              pageAccent: _socialPageAccent,
                            )
                          else
                            ...friendIds.map((friendUid) {
                              final friendName =
                                  (friendNames[friendUid] ?? 'Ami DVCR')
                                      .toString();
                              void openDuel() => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PronoDuelMatchPickerPage(
                                        currentUid: widget.currentUid,
                                        currentName: widget.displayName,
                                        opponentUid: friendUid,
                                        opponentName: friendName,
                                      ),
                                    ),
                                  );
                              return _ClubDirectoryRow(
                                gutter: _ClubInitialMark(name: friendName),
                                title: friendName,
                                meta: 'Ami confirmé · prêt pour un duel',
                                trailing: _ClubActionChip(
                                  label: 'Défier',
                                  onTap: openDuel,
                                ),
                                onTap: openDuel,
                              );
                            }),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _clubGutter,
              28,
              _clubGutter,
              0,
            ),
            child: PronoRoomPanel(
              eyebrow: 'Ajouter un ami',
              accent: _socialPageAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClubRuleField(
                    controller: _searchCtrl,
                    label: 'Pseudo, prénom ou email',
                    hint: 'ex. sanglier08',
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 18),
                  PronoInkCta(
                    label: 'Rechercher',
                    icon: Icons.search_rounded,
                    busy: _searching,
                    onTap: _searching ? null : _search,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              if (_searchError != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _ClubQuietNote(text: _searchError!),
                );
              }
              if (_didSearch && !_searching && _results.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PronoEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun inscrit trouvé',
                    body:
                        'Essaie le prénom / pseudo (début du nom) ou l’email exact du compte.',
                    pageAccent: _socialPageAccent,
                  ),
                );
              }
              if (_results.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader(
                    'Résultats de recherche',
                    count: '${_results.length}',
                  ),
                  ..._results.map((user) {
                    final otherUid = (user['uid'] ?? '').toString();
                    final otherName = PronoSocialService.resolveDisplayName(
                      data: user,
                      fallback: UserRole.teamDvcr.displayName,
                    );
                    return _ClubDirectoryRow(
                      gutter: _ClubInitialMark(name: otherName),
                      title: otherName,
                      meta: 'Envoyer une invitation',
                      trailing: _ClubTextAction(
                        label: 'Ajouter',
                        color: _socialPageAccent.color,
                        onTap: () => _invite(otherUid, otherName),
                      ),
                      onTap: () => _invite(otherUid, otherName),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DUELS
// ═══════════════════════════════════════════════════════════════════════════

class PronoDuelsPage extends StatelessWidget {
  final String currentUid;
  final String displayName;

  const PronoDuelsPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  static Widget _sectionHeader(String title, {String? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_clubGutter, 26, _clubGutter, 6),
      child: PronoSectionHeader(
        title: title,
        countLabel: count,
        pageAccent: _socialPageAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Duels',
      subtitle: 'Scores fun réservés au duel — pas le prono championnat.',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _clubGutter,
              18,
              _clubGutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PronoInkCta(
                  label: 'Lancer un duel',
                  icon: Icons.sports_martial_arts_rounded,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PronoDuelFriendPickerPage(
                        currentUid: currentUid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PronoPaperCta(
                  label: 'Ouvrir la liste d’amis',
                  icon: Icons.group_outlined,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PronoFriendsPage(
                        currentUid: currentUid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelsForUser(currentUid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: PronoLoadingTape(rows: 4),
                );
              }

              final docs = snap.data?.docs ?? const [];
              final pending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final finished = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final doc in docs) {
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                if (status == 'cancelled' || status == 'declined') {
                  doc.reference.delete();
                  continue;
                }
                if (status == 'pending') {
                  pending.add(doc);
                } else if (status == 'in_progress') {
                  active.add(doc);
                } else {
                  finished.add(doc);
                }
              }

              if (pending.isEmpty && active.isEmpty && finished.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: PronoEmptyState(
                    icon: Icons.sports_martial_arts_outlined,
                    title: 'Aucun duel au tableau',
                    body:
                        'Choisis un pote, choisis un match, annonce ton score : le premier duel du vestiaire, c’est toi.',
                    pageAccent: _socialPageAccent,
                  ),
                );
              }

              Widget duelRow(
                QueryDocumentSnapshot<Map<String, dynamic>> doc,
              ) {
                return _ClubDuelRow(
                  uid: currentUid,
                  duel: {'id': doc.id, ...doc.data()},
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PronoDuelDetailPage(
                        duelId: doc.id,
                        currentUid: currentUid,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader('En attente', count: '${pending.length}'),
                  if (pending.isEmpty)
                    const _ClubQuietNote(
                      text: 'Aucun défi en attente de réponse.',
                    )
                  else
                    ...pending.map(duelRow),
                  _sectionHeader('En cours', count: '${active.length}'),
                  if (active.isEmpty)
                    const _ClubQuietNote(text: 'Aucun duel en cours.')
                  else
                    ...active.map(duelRow),
                  _sectionHeader('Terminés', count: '${finished.length}'),
                  if (finished.isEmpty)
                    const _ClubQuietNote(text: 'Aucun duel terminé.')
                  else
                    ...finished.map(duelRow),
                ],
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: FutureBuilder<List<DuelRivalStat>>(
            future: PronoSocialService.duelRivalStatsAmongFriends(currentUid),
            builder: (context, rivalSnap) {
              if (rivalSnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: PronoLoadingTape(rows: 2),
                );
              }
              final rivals = rivalSnap.data ?? const <DuelRivalStat>[];
              if (rivals.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader(
                    'Classement potes',
                    count: '${rivals.length}',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: PronoLbTableShell(
                      children: [
                        const PronoLbColumnHeader(
                          nameLabel: 'Adversaire',
                          showExactColumn: false,
                        ),
                        ...rivals.take(20).toList().asMap().entries.map((e) {
                          final rank = e.key + 1;
                          final r = e.value;
                          return PronoLbDataRow(
                            displayRank: rank,
                            title: r.opponentName,
                            subtitle: '${r.wins}V · ${r.draws}N · ${r.losses}D',
                            points: r.duelPoints,
                            exactScores: null,
                            showExactColumn: false,
                            podiumHighlight: rank <= 3,
                            isMe: false,
                          );
                        }),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(_clubGutter, 4, _clubGutter, 0),
                    child: PronoLbFootnote(
                      text:
                          'Bilan face-à-face entre amis, duels terminés uniquement : '
                          '3 points par victoire, 1 par match nul.',
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
}

// ═══════════════════════════════════════════════════════════════════════════
//  LIGUES
// ═══════════════════════════════════════════════════════════════════════════

class PronoLeaguesPage extends StatefulWidget {
  final String currentUid;
  final String displayName;

  const PronoLeaguesPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  State<PronoLeaguesPage> createState() => _PronoLeaguesPageState();
}

class _PronoLeaguesPageState extends State<PronoLeaguesPage> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final code = await PronoSocialService.createLeague(
      ownerUid: widget.currentUid,
      ownerName: widget.displayName,
      name: name,
    );
    if (!mounted) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce nom de ligue est déjà utilisé (même nom, espaces ignorés, insensible à la casse).',
          ),
          backgroundColor: _kRed,
        ),
      );
      return;
    }
    _nameCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ligue créée. Code invitation : $code'),
        backgroundColor: _kGreen,
      ),
    );
  }

  Future<void> _joinLeague() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _joining) return;
    setState(() => _joining = true);
    try {
      final ok = await PronoSocialService.joinLeague(
        uid: widget.currentUid,
        displayName: widget.displayName,
        code: code,
      );
      if (ok) _codeCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ligue rejointe avec succès.'
                : 'Code de ligue introuvable.',
          ),
          backgroundColor: ok ? _kGreen : _kRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Ligues',
      subtitle: 'Mini-championnat entre amis — mêmes règles de points.',
      slivers: [
        SliverToBoxAdapter(
          child: _ClubReceptionDesk(
            controller: _codeCtrl,
            busy: _joining,
            onJoin: _joinLeague,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _clubGutter,
              22,
              _clubGutter,
              0,
            ),
            child: PronoRoomPanel(
              eyebrow: 'Créer ma ligue',
              accent: _socialPageAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClubRuleField(
                    controller: _nameCtrl,
                    label: 'Nom de la ligue',
                    hint: 'ex. Les Sangliers du bureau',
                    onSubmitted: (_) => _createLeague(),
                  ),
                  const SizedBox(height: 18),
                  PronoInkCta(
                    label: 'Créer ma ligue',
                    icon: Icons.add_rounded,
                    onTap: _createLeague,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.leaguesForUser(widget.currentUid),
            builder: (context, snap) {
              final waiting =
                  snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData;
              final leagues = snap.data?.docs ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _clubGutter,
                      28,
                      _clubGutter,
                      6,
                    ),
                    child: PronoSectionHeader(
                      title: 'Mes ligues',
                      countLabel: waiting ? null : '${leagues.length}',
                      pageAccent: _socialPageAccent,
                    ),
                  ),
                  if (waiting)
                    const PronoLoadingTape(rows: 3)
                  else if (leagues.isEmpty)
                    PronoEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Aucun salon pour l’instant',
                      body:
                          'Entre le code d’un pote en haut de page, ou crée ta ligue : elle s’affichera ici avec son code d’invitation.',
                      pageAccent: _socialPageAccent,
                    )
                  else
                    ...leagues.map((league) {
                      final data = league.data();
                      final code = (data['code'] ?? '-').toString();
                      final members =
                          (data['memberCount'] as num?)?.toInt() ?? 0;
                      final name =
                          (data['name'] ?? 'Ligue privée').toString();
                      return _ClubDirectoryRow(
                        gutter: _ClubGutterNumeral(
                          value: '$members',
                          caption: members > 1 ? 'membres' : 'membre',
                        ),
                        title: name,
                        meta: 'Salon privé · mêmes règles de points',
                        trailing: _ClubCodeStamp(code: code),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PronoLeagueDetailPage(
                              leagueId: league.id,
                              league: data,
                              currentUid: widget.currentUid,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLASSEMENT GLOBAL
// ═══════════════════════════════════════════════════════════════════════════

class PronoLeaderboardPage extends StatelessWidget {
  final String currentUid;

  const PronoLeaderboardPage({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Classement',
      subtitle: 'Top 20 · ta place toujours visible',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<GlobalLeaderboardView>(
            stream: PronoSocialService.watchGlobalLeaderboardWindow(currentUid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(
                    _clubGutter,
                    18,
                    _clubGutter,
                    0,
                  ),
                  child: PronoLoadingBlock(),
                );
              }

              final view = snap.data;
              if (view == null || view.top.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: _LeaderboardEmptyCard(),
                );
              }

              Widget rowFor(GlobalLeaderboardRow r) {
                return PronoLbDataRow(
                  displayRank: r.rank,
                  title: r.displayName,
                  points: r.points,
                  exactScores: r.exactScores,
                  xiCount: r.perfectXiCount,
                  podiumHighlight: r.rank <= 3,
                  isMe: r.uid == currentUid,
                );
              }

              final tableChildren = <Widget>[
                const PronoLbColumnHeader(
                  nameLabel: 'Pronostiqueur',
                  showExactColumn: true,
                ),
                for (final r in view.top) rowFor(r),
                if (view.neighbors.isNotEmpty) ...[
                  const PronoLbZoneDivider(label: 'ta zone'),
                  for (final r in view.neighbors) rowFor(r),
                ],
              ];

              final me = view.me;
              final myRank = view.myRank;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      _clubGutter,
                      16,
                      _clubGutter,
                      0,
                    ),
                    child: PronoLbTitleBlock(
                      title: 'Classement saison',
                      subtitle:
                          'Points cumulés sur les matchs de championnat, hors duels.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: PronoLbPodium(
                      top: view.top
                          .take(3)
                          .map(
                            (r) => (
                              rank: r.rank,
                              name: r.displayName,
                              score: '${r.points}',
                              isMe: r.uid == currentUid,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (myRank != null && me != null)
                    // Dalle d’encre unique de l’écran : le podium et la table
                    // restent en papier pour lui laisser toute la matière.
                    PronoStandingBand(
                      kicker: 'TA PLACE',
                      rankLabel: '${myRank}e',
                      detail: view.totalCount > 0
                          ? 'sur ${view.totalCount} pronostiqueurs · ${me.points} pts'
                          : '${me.points} pts',
                      action: _ClubInkTextAction(
                        label: 'Partager ma place',
                        icon: Icons.ios_share_rounded,
                        onTap: () {
                          DvcrShare.share(
                            ShareHelper.tournamentRankingShareText(
                              tournamentLabel: 'Classement global DVCR',
                              rank: myRank,
                              points: me.points,
                              exactScores: me.exactScores,
                              displayName: me.displayName,
                            ),
                            context: context,
                          );
                        },
                      ),
                    )
                  else
                    const _ClubQuietNote(
                      text:
                          'Pose ton premier prono pour apparaître au classement.',
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: PronoLbTableShell(children: tableChildren),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      _clubGutter,
                      2,
                      _clubGutter,
                      0,
                    ),
                    child: PronoLbFootnote(text: _leaderboardFootnote),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Classement global des ligues (puissance = moyenne de points par membre).
///
/// Règle produit : toute ligue privée compte dès 1 membre (pas de seuil min).
/// Les points viennent de `prono_leaderboard` (agrégés dans `rankingStats`).
class PronoTopLeaguesPage extends StatelessWidget {
  final String currentUid;

  const PronoTopLeaguesPage({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Top ligues',
      subtitle: 'Classement à la moyenne de points par membre.',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<List<TopLeagueRow>>(
            stream: PronoSocialService.topLeaguesByMemberPointsStream(
              limit: 30,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: PronoLoadingTape(rows: 5),
                );
              }
              if (snap.hasError) {
                return PronoErrorState(
                  title: 'Classement indisponible',
                  body:
                      'Impossible de charger le classement des ligues. Réessaie plus tard.',
                  pageAccent: _socialPageAccent,
                );
              }
              final rows = snap.data ?? const <TopLeagueRow>[];
              if (rows.isEmpty) {
                return PronoEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Aucune ligue pour l’instant',
                  body:
                      'Crée une ligue privée ou rejoins-en une avec un code — elle apparaîtra ici dès qu’elle existe (même avec 1 membre).',
                  pageAccent: _socialPageAccent,
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      _clubGutter,
                      16,
                      _clubGutter,
                      0,
                    ),
                    child: PronoLbTitleBlock(
                      title: 'Top ligues',
                      subtitle:
                          'La ligue la plus forte du vestiaire DVCR, à la moyenne par membre.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: PronoLbPodium(
                      top: rows
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (e) => (
                              rank: e.key + 1,
                              name: e.value.name,
                              score: e.value.memberPointsAvgLabel,
                              isMe: e.value.memberIds.contains(currentUid),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: PronoLbTableShell(
                      children: [
                        const PronoLbColumnHeader(
                          nameLabel: 'Ligue privée',
                          showExactColumn: false,
                        ),
                        ...rows.asMap().entries.map((e) {
                          final i = e.key;
                          final row = e.value;
                          final mine = row.memberIds.contains(currentUid);
                          return PronoLbDataRow(
                            displayRank: i + 1,
                            title: row.name,
                            subtitle:
                                '${row.memberCount} membre${row.memberCount > 1 ? 's' : ''}'
                                '${mine ? ' · ta ligue' : ''}',
                            points: row.memberPointsAvg.round(),
                            pointsLabel: row.memberPointsAvgLabel,
                            exactScores: null,
                            showExactColumn: false,
                            podiumHighlight: i < 3,
                            isMe: mine,
                          );
                        }),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      _clubGutter,
                      2,
                      _clubGutter,
                      0,
                    ),
                    child: PronoLbFootnote(
                      text:
                          'On classe les ligues à la moyenne des points prono '
                          'par membre — pas à la somme. Une ligue de 2 a les '
                          'mêmes chances qu’une ligue de 20.',
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
}

// ═══════════════════════════════════════════════════════════════════════════
//  SALON DE LIGUE
// ═══════════════════════════════════════════════════════════════════════════

class PronoLeagueDetailPage extends StatefulWidget {
  final String leagueId;
  final Map<String, dynamic> league;
  final String currentUid;

  const PronoLeagueDetailPage({
    super.key,
    required this.leagueId,
    required this.league,
    required this.currentUid,
  });

  @override
  State<PronoLeagueDetailPage> createState() => _PronoLeagueDetailPageState();
}

class _PronoLeagueDetailPageState extends State<PronoLeagueDetailPage> {
  bool _sedanOnly = false;

  @override
  Widget build(BuildContext context) {
    final memberIds = (widget.league['memberIds'] as List?) ?? const [];
    final ownerUid = (widget.league['ownerUid'] ?? '').toString();
    final memberCount =
        (widget.league['memberCount'] as num?)?.toInt() ?? memberIds.length;
    final isMember = memberIds.contains(widget.currentUid) ||
        ownerUid == widget.currentUid;
    final code = (widget.league['code'] ?? '').toString().trim();
    final leagueName = (widget.league['name'] ?? 'Ligue privée').toString();
    final memberLabel = '$memberCount membre${memberCount > 1 ? 's' : ''}';
    // Code visible uniquement pour membres / owner (pas pour une ligue adverse).
    final subtitle = isMember && code.isNotEmpty
        ? 'Code $code · $memberLabel'
        : memberLabel;

    return _PronoSocialPageScaffold(
      title: leagueName,
      subtitle: subtitle,
      slivers: [
        SliverToBoxAdapter(
          child: _ClubInkPageHeader(
            kicker: 'Salon privé',
            title: leagueName,
            meta: '$memberLabel · mêmes règles de points que le championnat.',
            tint: _socialPageAccent.deep,
            child: isMember
                ? PronoInviteStub(code: code, memberLabel: memberLabel)
                : null,
          ),
        ),
        SliverToBoxAdapter(
          child: FutureBuilder<List<LeagueStandingEntry>>(
            future: PronoSocialService.leagueLeaderboardFiltered(
              memberIds,
              sedanOnly: _sedanOnly,
            ),
            builder: (context, snap) {
              final rows = snap.data ?? const <LeagueStandingEntry>[];
              final waiting =
                  snap.connectionState == ConnectionState.waiting;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _clubGutter,
                      24,
                      _clubGutter,
                      8,
                    ),
                    child: PronoSectionHeader(
                      title: 'Classement de la ligue',
                      pageAccent: _socialPageAccent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: PronoFilterChip(
                            label: 'Tous',
                            selected: !_sedanOnly,
                            onTap: () => setState(() => _sedanOnly = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PronoFilterChip(
                            label: 'Sedan',
                            selected: _sedanOnly,
                            onTap: () => setState(() => _sedanOnly = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (waiting)
                    const PronoLoadingTape(rows: 4)
                  else if (rows.isEmpty)
                    PronoEmptyState(
                      icon: Icons.leaderboard_outlined,
                      title: 'Classement encore vide',
                      body:
                          'Dès qu’un membre de la ligue marque des points sur un match de championnat, il apparaît ici.',
                      pageAccent: _socialPageAccent,
                    )
                  else
                    Builder(
                      builder: (context) {
                        final sliced =
                            sliceLeaderboardWindow<LeagueStandingEntry>(
                          sortedEntries: rows,
                          uidOf: (e) => e.uid,
                          currentUid: widget.currentUid,
                        );
                        final plan = sliced.plan;
                        final children = <Widget>[
                          const PronoLbColumnHeader(
                            nameLabel: 'Membre',
                            showExactColumn: true,
                          ),
                          ...sliced.top.map((e) {
                            final row = e.data;
                            final isMe = row.uid == widget.currentUid;
                            return PronoLbDataRow(
                              displayRank: e.rank,
                              title: row.displayName,
                              subtitle:
                                  '${row.totalPredictions} pronos · ${row.goodResults} bons résultats',
                              points: row.points,
                              exactScores: row.exactScores,
                              xiCount: row.perfectXiCount,
                              podiumHighlight: e.rank <= 3,
                              isMe: isMe,
                            );
                          }),
                          if (sliced.neighbors.isNotEmpty) ...[
                            const PronoLbZoneDivider(label: 'ta zone'),
                            ...sliced.neighbors.map((e) {
                              final row = e.data;
                              final isMe = row.uid == widget.currentUid;
                              return PronoLbDataRow(
                                displayRank: e.rank,
                                title: row.displayName,
                                subtitle:
                                    '${row.totalPredictions} pronos · ${row.goodResults} bons résultats',
                                points: row.points,
                                exactScores: row.exactScores,
                                xiCount: row.perfectXiCount,
                                podiumHighlight: false,
                                isMe: isMe,
                              );
                            }),
                          ],
                        ];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (plan.myRank != null) ...[
                              // Papier : l’encre du salon est déjà posée par
                              // l’en-tête de page, en haut de cet écran.
                              PronoStandingBand(
                                kicker: 'TA PLACE DANS LE SALON',
                                rankLabel: '${plan.myRank}e',
                                detail: 'sur ${rows.length} membres classés',
                                paper: true,
                              ),
                              const SizedBox(height: 18),
                            ],
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _clubGutter,
                              ),
                              child: PronoLbTableShell(children: children),
                            ),
                          ],
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _clubGutter,
                      28,
                      _clubGutter,
                      8,
                    ),
                    child: PronoSectionHeader(
                      title: 'Pronos des membres',
                      pageAccent: _socialPageAccent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _clubGutter,
                    ),
                    child: _LeagueHistorySection(
                      memberIds: memberIds,
                      currentUid: widget.currentUid,
                    ),
                  ),
                  if (ownerUid == widget.currentUid)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _clubGutter,
                        24,
                        _clubGutter,
                        0,
                      ),
                      child: PronoPaperCta(
                        label: 'Supprimer la ligue',
                        icon: Icons.delete_outline_rounded,
                        accent: _socialPageAccent.color,
                        onTap: () async {
                          await PronoSocialService.deleteLeague(
                            leagueId: widget.leagueId,
                            ownerUid: widget.currentUid,
                          );
                          if (context.mounted) {
                            Navigator.of(context).maybePop();
                          }
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
}

// ═══════════════════════════════════════════════════════════════════════════
//  DÉTAIL DUEL
// ═══════════════════════════════════════════════════════════════════════════

class PronoDuelDetailPage extends StatelessWidget {
  final String duelId;
  final String currentUid;

  const PronoDuelDetailPage({
    super.key,
    required this.duelId,
    required this.currentUid,
  });

  static String _pickPreview(Map<String, dynamic>? p) {
    if (p == null) return '—';
    final a = p['score1'];
    final b = p['score2'];
    if (a == null || b == null) return '—';
    return '$a-$b';
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Détail duel',
      subtitle: 'Scores duel fun — pas le prono championnat.',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelStream(duelId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(
                    _clubGutter,
                    18,
                    _clubGutter,
                    0,
                  ),
                  child: PronoLoadingBlock(),
                );
              }
              final duel = snap.data?.data();
              if (duel == null) {
                return PronoErrorState(
                  title: 'Duel introuvable',
                  body:
                      'Ce duel n’existe plus. Reviens aux duels pour en lancer un nouveau.',
                  pageAccent: _socialPageAccent,
                );
              }
              final status = (duel['status'] ?? 'pending').toString();
              final label = status == 'won'
                  ? ((duel['winnerUid'] == currentUid) ? 'GAGNÉ' : 'PERDU')
                  : status == 'draw'
                      ? 'NUL'
                      : status == 'cancelled'
                          ? 'ANNULÉ'
                          : status == 'in_progress'
                              ? 'EN COURS'
                              : 'EN ATTENTE';
              final canEditPick =
                  status == 'pending' || status == 'in_progress';

              return StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: PronoSocialService.duelPicksStream(duelId),
                builder: (context, pickSnap) {
                  final picks =
                      pickSnap.data ?? const <String, Map<String, dynamic>>{};
                  final ownerUid = (duel['ownerUid'] ?? '').toString();
                  final oppUid = (duel['opponentUid'] ?? '').toString();
                  final ownerPick = picks[ownerUid];
                  final oppPick = picks[oppUid];

                  final ownerScoreStr = duel['ownerScore'] != null
                      ? duel['ownerScore'].toString()
                      : _pickPreview(ownerPick);
                  final oppScoreStr = duel['opponentScore'] != null
                      ? duel['opponentScore'].toString()
                      : _pickPreview(oppPick);

                  final ownerName =
                      (duel['ownerName'] ?? 'Joueur 1').toString();
                  final oppName =
                      (duel['opponentName'] ?? 'Joueur 2').toString();
                  final ownerPoints = duel['ownerPoints']?.toString() ?? '—';
                  final oppPoints = duel['opponentPoints']?.toString() ?? '—';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ClubDuelScoreboard(
                        kicker: label,
                        matchLabel:
                            (duel['matchLabel'] ?? 'Duel privé').toString(),
                        leftName: ownerName,
                        leftValue: ownerPoints,
                        rightName: oppName,
                        rightValue: oppPoints,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _clubGutter,
                          24,
                          _clubGutter,
                          8,
                        ),
                        child: PronoSectionHeader(
                          title: 'Scores annoncés',
                          pageAccent: _socialPageAccent,
                        ),
                      ),
                      _ClubLedgerRow(
                        label: ownerName,
                        meta: 'Score annoncé pour ce duel',
                        value: ownerScoreStr,
                      ),
                      _ClubLedgerRow(
                        label: oppName,
                        meta: 'Score annoncé pour ce duel',
                        value: oppScoreStr,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _clubGutter,
                          16,
                          _clubGutter,
                          0,
                        ),
                        child: PronoFootnote(
                          text:
                              '+${duel['duelXpReward'] ?? 3} XP si tu gagnes ce duel. '
                              'Ces scores restent entre vous : ils ne touchent pas au prono championnat.',
                        ),
                      ),
                      if (canEditPick)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _clubGutter,
                            22,
                            _clubGutter,
                            0,
                          ),
                          child: PronoInkCta(
                            label: 'Mon score duel',
                            icon: Icons.edit_outlined,
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PronoDuelPickPage(
                                    duelId: duelId,
                                    currentUid: currentUid,
                                    matchLabel: (duel['matchLabel'] ?? 'Duel')
                                        .toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Saisie du score « fun » pour un duel (sous-collection `duel_picks`), hors prono championnat.
class PronoDuelPickPage extends StatefulWidget {
  final String duelId;
  final String currentUid;
  final String matchLabel;

  const PronoDuelPickPage({
    super.key,
    required this.duelId,
    required this.currentUid,
    required this.matchLabel,
  });

  @override
  State<PronoDuelPickPage> createState() => _PronoDuelPickPageState();
}

class _PronoDuelPickPageState extends State<PronoDuelPickPage> {
  final _home = TextEditingController();
  final _away = TextEditingController();
  bool _loading = true;

  @override
  void dispose() {
    _home.dispose();
    _away.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final doc = await FirebaseFirestore.instance
        .collection('prono_duels')
        .doc(widget.duelId)
        .collection('duel_picks')
        .doc(widget.currentUid)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      final d = doc.data() ?? {};
      _home.text = '${d['score1'] ?? ''}';
      _away.text = '${d['score2'] ?? ''}';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final n1 = int.tryParse(_home.text.trim());
    final n2 = int.tryParse(_away.text.trim());
    if (n1 == null || n2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kRed,
          content: Text(
            'Entre deux nombres entiers (0-99).',
            style: PronoType.label.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }
    await PronoSocialService.saveDuelPick(
      duelId: widget.duelId,
      uid: widget.currentUid,
      score1: n1,
      score2: n2,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _PronoSocialPageScaffold(
        title: 'Score duel',
        subtitle: widget.matchLabel,
        slivers: const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(_clubGutter, 18, _clubGutter, 0),
              child: PronoLoadingBlock(),
            ),
          ),
        ],
      );
    }
    return _PronoSocialPageScaffold(
      title: 'Score duel',
      subtitle: widget.matchLabel,
      slivers: [
        // Dalle d’encre unique de la page : la zone de saisie. La barre de
        // titre reste du papier, il n’y a pas de second bloc sombre.
        SliverToBoxAdapter(
          child: SizedBox(
            width: double.infinity,
            child: PronoInkSurface(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _clubGutter,
                  24,
                  _clubGutter,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TON SCORE DUEL', style: PronoType.kickerGold),
                    const SizedBox(height: 12),
                    Text(
                      widget.matchLabel,
                      style: PronoType.headline.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _ClubScoreField(
                            controller: _home,
                            label: 'Domicile',
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 64,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          color: PronoArenaTheme.gold,
                        ),
                        Expanded(
                          child: _ClubScoreField(
                            controller: _away,
                            label: 'Extérieur',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _clubGutter,
              24,
              _clubGutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PronoInkCta(
                  label: 'Enregistrer',
                  icon: Icons.check_rounded,
                  onTap: _save,
                ),
                const SizedBox(height: 6),
                const PronoFootnote(
                  text:
                      'Ce score ne compte que pour le duel : ton prono championnat reste inchangé.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SÉLECTEURS DE DUEL
// ═══════════════════════════════════════════════════════════════════════════

class PronoDuelFriendPickerPage extends StatelessWidget {
  final String currentUid;
  final String displayName;

  const PronoDuelFriendPickerPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Choisir un ami',
      subtitle: 'Amis confirmés uniquement.',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(currentUid),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting &&
                  !userSnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: PronoLoadingTape(rows: 4),
                );
              }
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friendNames =
                  (social['friendNames'] as Map<String, dynamic>?) ?? const {};
              final friendIds =
                  (social['friends'] as List?)?.whereType<String>().toList() ??
                  const <String>[];

              if (friendIds.isEmpty) {
                return PronoEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Pas encore d’adversaire',
                  body:
                      'Ajoute un ami dans le vestiaire, puis reviens ici pour le défier sur un match.',
                  pageAccent: _socialPageAccent,
                  action: SizedBox(
                    width: 240,
                    child: PronoInkCta(
                      label: 'Aller aux amis',
                      icon: Icons.group_outlined,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PronoFriendsPage(
                            currentUid: currentUid,
                            displayName: displayName,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _clubGutter,
                      20,
                      _clubGutter,
                      6,
                    ),
                    child: PronoSectionHeader(
                      title: 'Tes amis',
                      countLabel: '${friendIds.length}',
                      pageAccent: _socialPageAccent,
                    ),
                  ),
                  ...friendIds.map((friendUid) {
                    final friendName =
                        (friendNames[friendUid] ?? 'Ami DVCR').toString();
                    return _ClubDirectoryRow(
                      gutter: _ClubInitialMark(name: friendName),
                      title: friendName,
                      meta: 'Choisir le match ensuite',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PronoDuelMatchPickerPage(
                            currentUid: currentUid,
                            currentName: displayName,
                            opponentUid: friendUid,
                            opponentName: friendName,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class PronoDuelMatchPickerPage extends StatelessWidget {
  final String currentUid;
  final String currentName;
  final String opponentUid;
  final String opponentName;

  const PronoDuelMatchPickerPage({
    super.key,
    required this.currentUid,
    required this.currentName,
    required this.opponentUid,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'Lancer un duel',
      subtitle: 'Match pour défier $opponentName',
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<List<MatchModel>>(
            stream: MatchService.allUpcoming(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: PronoLoadingTape(rows: 4),
                );
              }

              final now = DateTime.now();
              final matches = (snap.data ?? const <MatchModel>[]).where((m) {
                final daysLeft = m.date.difference(now).inDays;
                return now.isBefore(m.date) && daysLeft <= 7;
              }).toList();

              if (matches.isEmpty) {
                return PronoEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Aucun match à défier',
                  body:
                      'Les duels s’ouvrent dans les 7 jours qui précèdent un match. Reviens quand le prochain rendez-vous approche.',
                  pageAccent: _socialPageAccent,
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _clubGutter,
                      20,
                      _clubGutter,
                      6,
                    ),
                    child: PronoSectionHeader(
                      title: 'Matchs ouverts',
                      countLabel: '${matches.length}',
                      pageAccent: _socialPageAccent,
                    ),
                  ),
                  ...matches.map((match) {
                    final label = '${match.team1} vs ${match.team2}';
                    final dateStr = DateFormat(
                      "EEEE d MMMM · HH'h'mm",
                      'fr_FR',
                    ).format(match.date);
                    final monthStr =
                        DateFormat('MMM', 'fr_FR').format(match.date);
                    return _ClubDirectoryRow(
                      gutter: _ClubGutterNumeral(
                        value: '${match.date.day}',
                        caption: monthStr,
                      ),
                      title: label,
                      meta: dateStr,
                      onTap: () async {
                        final duelId = await PronoSocialService.createDuel(
                          ownerUid: currentUid,
                          ownerName: currentName,
                          opponentUid: opponentUid,
                          opponentName: opponentName,
                          matchId: match.id,
                          matchLabel: label,
                        );
                        if (!context.mounted) return;
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) => PronoDuelPickPage(
                              duelId: duelId,
                              currentUid: currentUid,
                              matchLabel: label,
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        if (saved == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Défi envoyé à $opponentName — score duel enregistré',
                              ),
                              backgroundColor: _kGreen,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Duel créé : complète ton score depuis Duels > détail.',
                              ),
                              backgroundColor: _socialPageAccent.color,
                            ),
                          );
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
