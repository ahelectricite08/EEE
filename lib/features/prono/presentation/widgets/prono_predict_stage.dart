import 'package:flutter/material.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';
import 'prono_ui.dart';

/// La scène — tableau d’affichage plein cadre du moment « je pose mon score ».
///
/// C’est **la dalle d’encre unique** de la feuille de prono : l’écran n’a pas
/// de photo hero, il dépense donc sa seule pièce sombre ici, sur le geste qui
/// compte. Chiffres géants, or pour la distinction — le seul endroit du module
/// où la typo passe en 88 pt.
///
/// Le fond est pilotable depuis l’admin (Pronos → Bannières Pronos → « Feuille
/// de prono »). Sans photo, la matière d’encre reste le fond par défaut.
class PronoPredictStage extends StatelessWidget {
  final String kicker;
  final String? stamp;
  final String team1;
  final String team2;
  final String? logo1;
  final String? logo2;
  final int score1;
  final int score2;
  final ValueChanged<int> onScore1Changed;
  final ValueChanged<int> onScore2Changed;

  const PronoPredictStage({
    super.key,
    required this.kicker,
    this.stamp,
    required this.team1,
    required this.team2,
    this.logo1,
    this.logo2,
    required this.score1,
    required this.score2,
    required this.onScore1Changed,
    required this.onScore2Changed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        // Pas de filigrane ici : les deux écussons des équipes sont déjà les
        // ancres visuelles de la scène, un troisième blason ferait du bruit.
        crest: false,
        goldEdge: true,
        photoSlot: PronoBannerSlot.predictSlab,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      kicker.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.kickerOnInk,
                    ),
                  ),
                  if (stamp != null && stamp!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _StageStamp(label: stamp!),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StageSide(
                        name: team1,
                        logoUrl: logo1,
                        score: score1,
                        onChanged: onScore1Changed,
                      ),
                    ),
                    const _StageSpine(),
                    Expanded(
                      child: _StageSide(
                        name: team2,
                        logoUrl: logo2,
                        score: score2,
                        onChanged: onScore2Changed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampon or — « prono posé », lisible sans être un badge de gamification.
class _StageStamp extends StatelessWidget {
  final String label;

  const _StageStamp({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: PronoArenaTheme.gold.withValues(alpha: 0.8),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: PronoType.kickerGold.copyWith(letterSpacing: 1.4),
      ),
    );
  }
}

/// L’axe central — filet vertical + point or à hauteur des chiffres.
class _StageSpine extends StatelessWidget {
  const _StageSpine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          // Aligné sur l’axe optique des deux chiffres (écusson + nom au-dessus).
          const SizedBox(height: 142),
          Container(
            width: 12,
            height: 3,
            color: PronoArenaTheme.gold,
          ),
        ],
      ),
    );
  }
}

class _StageSide extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final int score;
  final ValueChanged<int> onChanged;

  const _StageSide({
    required this.name,
    required this.logoUrl,
    required this.score,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PronoStageCrest(url: logoUrl, name: name),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PronoType.fixture.copyWith(
              color: Colors.white,
              fontSize: 15,
              height: 1.12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          textAlign: TextAlign.center,
          style: PronoType.numeralStage,
        ),
        const SizedBox(height: 14),
        _StageStepper(value: score, onChanged: onChanged),
      ],
    );
  }
}

/// Segment − / + — cible tactile large, filet blanc, pas de bouton Material.
class _StageStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StageStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StageStepBtn(
              icon: Icons.remove_rounded,
              enabled: value > 0,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
            ),
            Container(width: 1, height: 42, color: Colors.white24),
            _StageStepBtn(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageStepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _StageStepBtn({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.14),
        child: SizedBox(
          width: 54,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }
}

/// Écusson sur encre — disque blanc, le logo respire.
class PronoStageCrest extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const PronoStageCrest({
    super.key,
    required this.url,
    required this.name,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: u != null && u.isNotEmpty
          ? Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: DvcrNetworkImage(
                u,
                fit: BoxFit.contain,
                cacheWidth: dvcrCrestCacheWidth(context, size),
                placeholder: const SizedBox.shrink(),
                errorBuilder: (_, __, ___) => _fallback(),
              ),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final t = name.trim();
    final letter =
        t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: PronoType.title.copyWith(
          color: PronoArenaTheme.ink,
          fontSize: size * 0.44,
        ),
      ),
    );
  }
}
