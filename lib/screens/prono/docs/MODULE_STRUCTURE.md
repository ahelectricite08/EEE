# Découpage module Prono (cible)

Le fichier monolithique [`prono_screen.dart`](../prono_screen.dart) reste la **library** principale (`part` files). Migration progressive recommandée :

| Dossier cible | Contenu à y déplacer |
|---------------|----------------------|
| `prono_hub/` | Onglet matchs : lentilles, vues feed/cal/grille, filtres (`prono_matches_tab.dart`). |
| `prono_predict/` | Cartes match, bottom sheet prono, duel sheet (`prono_match_cards.dart`, `_PronoSheet`). |
| `prono_reveal/` | Animations post-match, révélations (futur). |
| `prono_social/` | Pages ligues/duels/amis (`prono_social_pages.dart`, `prono_community_tab.dart`). |
| `prono_profile/` | XP, badges, onboarding, saison (`prono_progress_tab.dart`). |

**Contrainte** : conserver `export '../../screens/prono_screen.dart'` ou équivalent pour les routes existantes ; extraire d’abord des **fichiers non-`part`** (services, widgets autonomes) pour limiter les risques.

Fichiers déjà extraits côté services : [`match_prono_stats_service.dart`](../../../services/match_prono_stats_service.dart), [`prono_season_service.dart`](../../../services/prono_season_service.dart), [`prono_onboarding_service.dart`](../../../services/prono_onboarding_service.dart), widgets [`prono_predict_extras.dart`](../prono_predict_extras.dart).
