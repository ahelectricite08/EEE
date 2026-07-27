# Admin UX — résumé (1 page)

**2026-07-26** · IA flux : [`ADMIN_WORKFLOWS.md`](./ADMIN_WORKFLOWS.md) · Détail : [`ADMIN_UX_ROADMAP.md`](./ADMIN_UX_ROADMAP.md) · Onglets-outils : [`ADMIN_UX_MODULE_VISIONS.md`](./ADMIN_UX_MODULE_VISIONS.md) · État : [`ADMIN_STATUS.md`](./ADMIN_STATUS.md)

## Intent

Concevoir l’Admin autour de **4 flux de travail** (pas 17 onglets plats) : 🟢 Prépa · 🔴 Direct (single-view) · 🔵 Après · 🟣 Admin. Les onglets registry restent des **outils** (RBAC / deep-links). Même Admin vivant — pas d’Admin V2. Design system = outil, pas étape 1.

## Manifeste (extrait)

- Nav primaire = **phases match + Admin** ; tabs = couche secondaire.
- **5 actions / 95 %**, match-day, zéro navigation inutile — surtout en 🔴.
- Toute livraison = **changement d’organisation** (flux / hub / layout), sinon hors scope.
- Rien perdu : mapping feature → flux dans `ADMIN_WORKFLOWS`.

## Les 4 flux

| Flux | Jobs clés |
|------|-----------|
| 🟢 Prépa | Équipes/compos, programmer live, notifs, graphismes/TV |
| 🔴 Direct | Score, chrono, buts, cartons, stats, push, modération — **une vue** |
| 🔵 Après | Finaliser stats, MOTM, replay, résumé, classements, publication |
| 🟣 Admin | Membres, staff, réglages, TV, journaux |

## Ordre (organisation)

| # | Livraison | Flux |
|---|-----------|------|
| **#1 reco** | **Direct single-view** — sticky + Pilotage/Studio + latéral | 🔴 |
| alt. | Pilotage cockpit 30 s (pont vers les 4 flux) | pont |
| puis | Hub Prépa · Hub Après · catalogue Admin | 🟢 → 🔵 → 🟣 |
| outils | Matchs 3 pièces, Diffusion intents, Modération queue-first… | au service des hubs |
| — | Tokens / composants | **pas** étape 1 |

Transition : rail flux + mode classique + deep-links tabs (voir `ADMIN_WORKFLOWS` §7).

## Décision attendue

1. **Valides-tu l’IA par flux ?**
2. **Prototype #1 ?** Reco : **🔴 Direct single-view** (alt. : Pilotage pont).

---

*Docs only — zéro code `lib/` / `functions/` / pubspec.*
