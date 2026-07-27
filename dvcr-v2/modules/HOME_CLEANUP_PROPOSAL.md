# Home — Cleanup Proposal (post tranche 2)

**Date :** 2026-07-26  
**Statut :** proposition uniquement — **AUCUNE suppression / fusion destructive sans GO user explicite**  
**Contexte :** Home T2 a migré l’UI vers `lib/features/home/presentation/` et laissé des façades / placeholders pour ne pas casser les imports.

**Objectif documenté :** une seule implémentation par fonctionnalité. Les deletes attendent un GO séparé.

---

## 1. Peut être supprimé (après GO)

| Élément | Risque | Recommandation |
|---------|--------|----------------|
| Placeholders `lib/screens/home/home_feed_sections.dart`, `home_feed_results.dart`, `home_feed_articles.dart`, `home_live_widgets.dart`, `home_media_sections.dart`, `home_secondary_sections.dart` | **Faible** — fichiers commentaires 3 L, plus référencés (anciens `part of`) | Supprimer après grep « zero imports » |
| Scripts temporaires `_t2_*.py`, `_t2_*.txt`, dossier `_t2_src_backup/` | **Nul** (outils agent) | Supprimer dès validation T2 |
| `lib/features/home/presentation/legacy/` (si dossier vide) | Nul | Supprimer s’il existe vide |

## 2. Peut être fusionné / simplifié (après GO)

| Élément | Risque | Recommandation |
|---------|--------|----------------|
| Re-exports `lib/screens/home/home_screen.dart`, `home_palette.dart`, `home_motion.dart`, `home_shell_widgets.dart` | **Moyen** — encore importés par Profile, Matches, Benevole, widgets live, `main` via `screens/home_screen.dart` | **Garder** jusqu’à migration des call sites vers `package:dvcr/features/home/home.dart` ; puis supprimer façades |
| `lib/screens/home_screen.dart` → `export 'home/home_screen.dart'` | Faible | Optionnel : pointer directement le package feature |
| Façades `HomeSectionsService` / `HomeBannerService` | **Moyen** — admin / legacy call sites | Migrer call sites vers providers ; puis déprécier / supprimer |
| Instantiations `const HomeMatchCatalogAdapter()` / `HomeLiveHubAdapter()` / datasources inline dans les parts | Faible | Brancher uniquement via `ref.watch(*Provider)` (Consumer) pour tests |

## 3. Code mort / doublons potentiels (à confirmer avant delete)

| Élément | Note |
|---------|------|
| `_HeroMetaChip`, `_DefaultNavPill` | WARN analyzer « unused » — legacy non branché ; vérifier historique avant delete |
| `_publicPronoFeaturesEnabled = false` + bloc classement flouté | Mort fonctionnel volontaire (feature flag compile-time) — ne pas supprimer sans produit |
| Double chemin palette/motion/shell (`screens/home` re-export vs `features/home/presentation/widgets`) | Pas un doublon d’implémentation : **une** impl + façades |

## 4. Hors Home — ne pas toucher dans ce cleanup

- Modules Matchs / Articles / Live / Prono complets
- `LiveStateService`, `MatchController`, `ArticleService` (wrappers Home seulement)
- ~~World Cup / Esti (ADR-0002)~~ → **GO 2026-07-26 exécuté** (`ESTI_WC_REMOVAL_DONE.md`) : mini-carte CdM Home retirée
- `features/prono/*` hybride (FAILs script préexistants)

## 5. Checklist GO cleanup (séparé)

1. [ ] User valide Accueil (checklist `HOME.md`)
2. [ ] Grep : plus aucun import des placeholders `screens/home/home_feed_*` etc.
3. [ ] Migrer imports externes palette/motion/shell → barrel `features/home`
4. [ ] GO explicite « cleanup Home » → delete placeholders + scripts temp
5. [ ] (Optionnel) GO façades services → supprimer `HomeSectionsService` / `HomeBannerService`

---

**Interdit aujourd’hui :** toute suppression ou fusion destructive sans GO ci-dessus.
