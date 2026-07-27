# DVCR — Rationalisation (synthèse exécutive)

**Date :** 2026-07-26 · Docs only · **ADR-0005** : ❌ = proposals, pas d’exécution sans GO.

**Détail :** [`RATIONALIZATION_AUDIT.md`](./RATIONALIZATION_AUDIT.md) · [`RATIONALIZATION_BY_FEATURE.md`](./RATIONALIZATION_BY_FEATURE.md)

---

## Verdict

Le monolithe V1 est **déjà en modernisation in-place** (Foundation ✅, Auth ✅, Home T1 ✅ / **T2 en cours**). La rationalisation utile n’est **pas** un big-bang delete : c’est (1) fermer les dualités `screens/`↔`features/`, (2) retirer le code orphelin confirmé, (3) isoler Esti/WC (ADR-0002), (4) découper les monolithes >1000 L module par module.

---

## Chiffres clés (approx.)

| | |
|--|--|
| `lib/` | ~**404** Dart / ~**121k** lignes |
| `> 500 L` / `> 1000 L` | ~**64** / ~**28** |
| Services | **61** (presque tous static) |
| Features modernisées | Auth, Home (partiel), Prono (hybride), Admin (routing) |
| TODO/FIXME littéraux | **0** |
| Packages 0-import | `lottie`, `youtube_player_iframe`, `flutter_markdown` (+ `cupertino_icons` / `json_annotation` ⚠️) |
| Functions dep suspecte | `fast-xml-parser` (0 require source) |

---

## Top risques / opportunités

1. **Home T2** — UI déjà sous `features/home`, shims `screens/home` ; **syntaxe cassée** (`with` dupliqué) → bloquant compile ; `HomeSectionsService` orphelin côté app.
2. **Dualité Prono** — `PronoRootShell` + monolithe `prono_screen` (~3800 L combinés).
3. **Monolithes** — `match_detail` (~3.3k), Direct admin (~3.2k), `chat_ui_parts` (~2.7k), `match_card` / quick panel (~2.1k).
4. **Esti/WC** encore dans le graphe (Home, admin, Functions) — hors core, delete = **GO produit**.
5. **Code mort clair** — `OnboardingScreen`, `subscription_screen`, `utils/roles.dart`, 3 services prono sans call site, packages non importés.
6. **Architecture** — Riverpod rare ; `FirebaseAuth.instance` ~50 fichiers ; Home UI → data layer direct.

---

## Batches GO recommandés (ordre)

| # | Batch | Nature |
|---|--------|--------|
| R0 | Fix compile Home | bug (hors cleanup strict) |
| R1 | ❌ `HomeSectionsService` si confirmé | cleanup |
| R2 | Close Home T2 (placeholders/shims/`_t2_*`) | cleanup + docs |
| R3 | Auth shims login/register | `AUTH_CLEANUP` A1 |
| R4 | Services prono orphelins + onboarding/subscription/roles | cleanup |
| R5 | Packages / `fast-xml-parser` | deps |
| R6 | Isolation Esti/WC | **GO produit** |
| R7+ | Prono merge + splits >1000 L | modules |

---

## Confirmation

- Livrables : les 3 fichiers `dvcr-v2/RATIONALIZATION_*.md` uniquement.  
- **Zéro code applicatif modifié** par cet audit.
