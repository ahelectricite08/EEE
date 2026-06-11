# Workflow stats match (admin DVCR)

## Trois onglets (ne pas mélanger)

| Onglet | Rôle | Contenu |
|--------|------|---------|
| **Match** | Admin, CM | Calendrier, fiche (équipes, date, buteurs, cartons). Pas de pilotage live ni grille chiffrée. |
| **Direct** | Admin, CM | Score, buts, cartons, chrono, stream, salon, HDM. Bandeau stats ON/OFF uniquement. |
| **Statistiques match** | Statisticien (+ admin) | Sous-onglets En direct / Archive / Comparer. Workbench chiffré, publication, clôture. |

**Règles techniques :**
- Live impossible sans `matchId` calendrier (pas de `live_*` fantôme).
- Fin de live : faits → `matches` ; stats → `match_stats` (pas `showStats` forcé sur la fiche).
- Édition fiche match pendant le live : sync vers `live/current` si même `matchId`.

## Firestore

- `live/current` — état éphémère du direct.
- `matches/{id}` — fiche visible dans l’app.
- `match_stats/{id}` — brouillon statisticien + flags publication.

La saisie chiffrée passe par `MatchStatsSheetService.saveDraft`. Le Direct n’écrit plus de stats dans `live/current.stats` (panneau retiré).

## Jour de match

1. **Avant** — Match : créer / compléter la fiche. Stats : « Commencer la saisie » (`prepareSession`).
2. **Coup d’envoi** — Direct : démarrer le live avec un `matchId` calendrier. Stats : saisie + « Sync carte » si aperçu app.
3. **Mi-temps / fin** — Direct : pilotage score / faits. Stats : workbench (bouton « Saisir les statistiques » depuis Direct).
4. **Fin de direct** — Direct : terminer → archive auto vers `match_stats` (`archiveFromLiveEnd`). Snackbar → onglet Stats.
5. **Après** — Stats : « Terminer » → stats officielles (`finalize`).

## Raccourcis UI

Sur chaque fiche match : **Fiche · Stats · Direct · Rappel** (`AdminMatchQuickActions`).

Bandeau contexte : `MatchAdminContextBanner` (état live + publication + liens).

## Rôles

- **Admin** — tous les onglets, migration legacy, comparaison saison.
- **Community manager** — Match + Direct (selon permissions).
- **Statisticien** — atterrissage onglet Stats, workbench, publication.

## Tests manuels (checklist)

- [ ] Démarrer live avec `matchId` calendrier → accueil suit le bon match.
- [ ] Saisir stats dans workbench → aperçu carte après sync.
- [ ] Terminer live → données dans `match_stats`, snackbar Stats.
- [ ] Finaliser stats → fiche match officielle.
- [ ] Comparer deux matchs (onglet Stats).
