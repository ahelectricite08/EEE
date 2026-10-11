import 'package:flutter/material.dart';

import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import 'prono_ui.dart';

/// Lettres du disque d’en-tête : un mot → 2 lettres, sinon initiales prénom+nom.
String pronoPageMarkLetters(String title) {
  final letters = pronoRankInitials(title);
  if (letters.length >= 2) return letters;
  final t = title.trim();
  if (t.length >= 2) return t.substring(0, 2).toUpperCase();
  return letters;
}

/// En-tête compact des sous-pages Pronos — ligues, duels, amis, classement, salon.
///
/// Pas un clone d’AppBar Material : casquette papier, kicker, titre condensé,
/// barre d’accent et disque d’initiales. Le masthead photo des onglets reste
/// [PronoTabHeroSliver].
///
/// Revert : dans `_buildSocialPageAppBar` (`prono_social_pages.dart`),
/// renvoyer `_buildSocialPageAppBarLegacy` à la place de [PronoPageHeader.asAppBar].
class PronoPageHeader extends StatelessWidget {
  static const double capHeight = 4;
  static const double hairlineHeight = 1;
  static const double contentHeight = 72;

  final String title;
  final String subtitle;
  final String? kicker;
  final PronoPageAccent pageAccent;
  final bool showBack;
  final String? markLabel;
  final bool highlightMark;
  final String? markAvatarUrl;
  final VoidCallback? onBack;

  const PronoPageHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.kicker,
    this.pageAccent = PronoPageAccent.social,
    this.showBack = true,
    this.markLabel,
    this.highlightMark = false,
    this.markAvatarUrl,
    this.onBack,
  });

  /// Chrome vestiaire — rouge club. [PronoSocialHeroBar] est un alias de cette forme.
  factory PronoPageHeader.social({
    Key? key,
    required String title,
    String subtitle = '',
    String? kicker,
    String? markLabel,
    bool highlightMark = false,
    String? markAvatarUrl,
    bool showBack = true,
    VoidCallback? onBack,
  }) {
    return PronoPageHeader(
      key: key,
      title: title,
      subtitle: subtitle,
      kicker: kicker,
      pageAccent: PronoPageAccent.social,
      markLabel: markLabel,
      highlightMark: highlightMark,
      markAvatarUrl: markAvatarUrl,
      showBack: showBack,
      onBack: onBack,
    );
  }

  String get resolvedKicker {
    final raw = kicker?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return PronoArenaTheme.heroKicker(pageAccent);
  }

  static double heightFor(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        capHeight +
        contentHeight +
        hairlineHeight;
  }

  /// [PreferredSize] prêt pour `Scaffold.appBar` — hauteur = safe area + chrome.
  static PreferredSizeWidget asAppBar({
    required BuildContext context,
    required String title,
    String subtitle = '',
    String? kicker,
    PronoPageAccent pageAccent = PronoPageAccent.social,
    String? markLabel,
    bool highlightMark = false,
    String? markAvatarUrl,
    bool showBack = true,
    VoidCallback? onBack,
  }) {
    return PreferredSize(
      preferredSize: Size.fromHeight(heightFor(context)),
      child: PronoPageHeader(
        title: title,
        subtitle: subtitle,
        kicker: kicker,
        pageAccent: pageAccent,
        markLabel: markLabel,
        highlightMark: highlightMark,
        markAvatarUrl: markAvatarUrl,
        showBack: showBack,
        onBack: onBack,
      ),
    );
  }

  Color get _kickerColor {
    if (pageAccent == PronoPageAccent.progression) {
      return PronoArenaTheme.goldDeep;
    }
    return pageAccent.color;
  }

  @override
  Widget build(BuildContext context) {
    final accent = pageAccent.color;
    final topPad = MediaQuery.paddingOf(context).top;
    final markName =
        (markLabel != null && markLabel!.trim().isNotEmpty) ? markLabel! : title;
    final markSrc = (markAvatarUrl ?? '').trim();
    final markLetters = pronoPageMarkLetters(markName);

    return Material(
      color: PronoArenaTheme.scaffoldTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPad),
          SizedBox(height: capHeight, child: ColoredBox(color: accent)),
          SizedBox(
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showBack) _BackMark(onPressed: onBack),
                  if (showBack) const SizedBox(width: 4) else const SizedBox(width: 12),
                  Container(width: 3, height: 28, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.15,
                      child: _Lockup(
                        kicker: resolvedKicker,
                        kickerColor: _kickerColor,
                        title: title,
                        subtitle: subtitle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (markSrc.isNotEmpty)
                    PronoIdentityMark(
                      name: markName,
                      size: 40,
                      highlighted: highlightMark,
                      accent: pageAccent.color,
                      avatarUrl: markSrc,
                    )
                  else
                    _HeaderMark(
                      letters: markLetters,
                      accent: pageAccent,
                      highlighted: highlightMark,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: hairlineHeight,
            child: ColoredBox(color: PronoArenaTheme.hairline),
          ),
        ],
      ),
    );
  }
}

/// Alias vestiaire — même chrome que [PronoPageHeader], accent social.
typedef PronoSocialHeroBar = PronoPageHeader;

class _Lockup extends StatelessWidget {
  final String kicker;
  final Color kickerColor;
  final String title;
  final String subtitle;

  const _Lockup({
    required this.kicker,
    required this.kickerColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kicker.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.kicker.copyWith(color: kickerColor),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.headline.copyWith(fontSize: 28),
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
    );
  }
}

class _BackMark extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BackMark({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Retour',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Material(
            color: PronoArenaTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
              side: const BorderSide(color: PronoArenaTheme.hairline),
            ),
            child: InkWell(
              onTap: onPressed ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: PronoArenaTheme.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMark extends StatelessWidget {
  final String letters;
  final PronoPageAccent accent;
  final bool highlighted;

  const _HeaderMark({
    required this.letters,
    required this.accent,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final ring = highlighted ? PronoArenaTheme.gold : accent.color;
    final fg = highlighted ? PronoArenaTheme.goldDeep : accent.color;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PronoArenaTheme.surface,
        border: Border.all(color: ring, width: highlighted ? 2.5 : 1.5),
      ),
      child: Text(
        letters,
        style: PronoType.rank.copyWith(
          fontSize: letters.length > 1 ? size * 0.32 : size * 0.42,
          color: fg,
        ),
      ),
    );
  }
}
