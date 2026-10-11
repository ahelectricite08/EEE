import 'package:flutter/material.dart';

import '../../../../services/league_avatars_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import 'prono_ui.dart';

const kLeagueEmblemLockedMessage = 'Seul le créateur peut changer l’emblème';

const kLeagueEmblemCatalogEmptyMessage =
    'Importe des emblèmes dans l’admin (Photos & réseaux → AVATARS LIGUES)';

/// Rangée d’emblèmes de ligue uniquement (`app_config/league_avatars` +
/// Storage `league_avatars/`). Jamais le pack mascottes ni le catalogue profil.
class LeagueEmblemPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String>? onSelected;
  final bool enabled;

  /// Création : or sur le 1er choix si l’id n’est pas dans la liste.
  /// Réglages créateur : laisser `false` pour ne pas feindre une sélection.
  final bool selectFirstIfUnknown;

  /// `false` sous le code salon : le titre « CHANGER L’EMBLÈME » est déjà là.
  final bool showChrome;

  /// Si non null, pas de stream Firestore (tests / preview).
  final LeagueAvatarCatalog? catalog;

  const LeagueEmblemPicker({
    super.key,
    required this.selectedId,
    this.onSelected,
    this.enabled = true,
    this.selectFirstIfUnknown = false,
    this.showChrome = true,
    this.catalog,
  });

  @override
  Widget build(BuildContext context) {
    if (catalog != null) {
      return _body(catalog);
    }
    return StreamBuilder<LeagueAvatarCatalog>(
      stream: LeagueAvatarsService.instance.watchCatalog(),
      builder: (context, snap) {
        if (!snap.hasData &&
            !snap.hasError &&
            snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _body(snap.data, streamFailed: snap.hasError);
      },
    );
  }

  Widget _body(LeagueAvatarCatalog? catalog, {bool streamFailed = false}) {
    final options = resolveLeagueEmblemPickerOptions(
      catalog: catalog,
      streamFailed: streamFailed,
    ).where(isLeagueEmblemPickerOption).toList();
    return _LeagueEmblemPickerBody(
      options: options,
      selectedId: selectedId,
      onSelected: onSelected,
      enabled: enabled,
      selectFirstIfUnknown: selectFirstIfUnknown,
      showChrome: showChrome,
    );
  }
}

class _LeagueEmblemPickerBody extends StatelessWidget {
  final List<LeagueEmblemOption> options;
  final String selectedId;
  final ValueChanged<String>? onSelected;
  final bool enabled;
  final bool selectFirstIfUnknown;
  final bool showChrome;

  const _LeagueEmblemPickerBody({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.enabled,
    required this.selectFirstIfUnknown,
    required this.showChrome,
  });

  @override
  Widget build(BuildContext context) {
    final current = selectedId.trim();
    final ids = [for (final o in options) o.id];
    final highlightId = ids.contains(current)
        ? current
        : (selectFirstIfUnknown && ids.isNotEmpty ? ids.first : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showChrome) ...[
          Text('EMBLÈME', style: PronoType.kicker),
          const SizedBox(height: 6),
          Text(
            enabled
                ? 'Choisis un emblème de ligue. Pas les avatars membres — ceux-là se choisissent dans le profil. Toi seul, en tant que créateur, pourras le changer ensuite.'
                : 'Seul le créateur de la ligue peut changer l’emblème.',
            style: PronoType.caption,
          ),
          const SizedBox(height: 14),
        ],
        if (options.isEmpty)
          Text(
            kLeagueEmblemCatalogEmptyMessage,
            style: PronoType.caption,
          )
        else if (options.length <= 5)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _EmblemChoice(
                    option: options[i],
                    selected: options[i].id == highlightId,
                    enabled: enabled,
                    onTap: enabled && onSelected != null
                        ? () => onSelected!(options[i].id)
                        : null,
                  ),
                ),
              ],
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final o in options)
                SizedBox(
                  width: 64,
                  child: _EmblemChoice(
                    option: o,
                    selected: o.id == highlightId,
                    enabled: enabled,
                    onTap: enabled && onSelected != null
                        ? () => onSelected!(o.id)
                        : null,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmblemChoice extends StatelessWidget {
  final LeagueEmblemOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _EmblemChoice({
    required this.option,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = option.label.trim();
    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final size = c.maxWidth.clamp(40.0, 72.0);
                return PronoIdentityMark(
                  name: label.isEmpty ? 'Ligue' : label,
                  size: size,
                  highlighted: selected,
                  accent: PronoArenaTheme.hairline,
                  avatarUrl: option.src,
                );
              },
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PronoType.kicker.copyWith(
                  fontSize: 8,
                  letterSpacing: 0.8,
                  color: selected
                      ? PronoArenaTheme.goldDeep
                      : PronoArenaTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloc salon : emblème courant + CTA, **jamais** masqué par `if (owner)`.
class LeagueSalonEmblemBlock extends StatelessWidget {
  final String leagueName;
  final String? emblemSrc;
  final bool saving;
  final VoidCallback onChangeTap;

  const LeagueSalonEmblemBlock({
    super.key,
    required this.leagueName,
    required this.emblemSrc,
    required this.onChangeTap,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('league-salon-emblem-block'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: PronoArenaTheme.surface,
        borderRadius: BorderRadius.circular(PronoArenaTheme.ticketRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PronoIdentityMark(
              name: leagueName,
              size: 88,
              highlighted: true,
              avatarUrl: emblemSrc,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'EMBLÈME DE LA LIGUE',
            textAlign: TextAlign.center,
            style: PronoType.kicker,
          ),
          const SizedBox(height: 12),
          PronoPaperCta(
            key: const ValueKey('league-salon-emblem-change'),
            label: 'Changer l’emblème',
            icon: Icons.edit_outlined,
            onTap: saving ? null : onChangeTap,
          ),
        ],
      ),
    );
  }
}

/// Affordance compacte « Ta ligue » (hub) — icône ou CTA papier.
class LeagueHubEmblemEditAffordance extends StatelessWidget {
  final VoidCallback onTap;
  final bool iconOnly;

  const LeagueHubEmblemEditAffordance({
    super.key,
    required this.onTap,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        key: const ValueKey('league-hub-emblem-edit'),
        tooltip: 'Changer l’emblème',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: const Icon(
          Icons.edit_outlined,
          size: 18,
          color: PronoArenaTheme.textMuted,
        ),
        onPressed: onTap,
      );
    }
    return PronoPaperCta(
      key: const ValueKey('league-hub-emblem-edit'),
      label: 'Changer l’emblème',
      icon: Icons.edit_outlined,
      onTap: onTap,
    );
  }
}

/// Snackbar si lecture seule, sinon feuille avec la grille d’emblèmes.
Future<void> requestLeagueEmblemChange({
  required BuildContext context,
  required bool canEdit,
  required String selectedId,
  required ValueChanged<String> onSelected,
}) async {
  if (!canEdit) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(kLeagueEmblemLockedMessage)),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PronoArenaTheme.surface,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EMBLÈME DE LA LIGUE', style: PronoType.kicker),
              const SizedBox(height: 14),
              LeagueEmblemPicker(
                selectedId: selectedId,
                showChrome: false,
                onSelected: (id) {
                  Navigator.of(ctx).pop();
                  onSelected(id);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
