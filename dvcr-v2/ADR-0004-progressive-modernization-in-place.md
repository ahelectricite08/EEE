# ADR-0004 — Modernisation progressive in-place (abandon rewrite V2 séparée)

**Statut :** Proposé — **attente validation utilisateur explicite** avant tout refactor code  
**Date :** 2026-07-26  
**Décideurs :** Lead Architect DVCR  
**Compléments :** `STRATEGY.md`, `MODERNIZATION_PLAN.md`, `ARCHITECTURE.md`, `SCOPE_V2.md`, `ARCHITECTURE_REVIEW.md`, `ADR-0001`, `ADR-0002`, `ADR-0003`

---

## Contexte

L’app DVCR en production (`dvcr_appli`, Flutter + Firebase) est **fonctionnelle** : écrans, parcours UX, identité graphique, Features métier, backend Firebase.

Une stratégie antérieure (ADR-0001, plan de migration) visait une **reconstruction from scratch** dans un second arbre (`dvcr-v2/app/` et/ou sibling `dvcr_appli_v2`) : Module 0 scaffold, puis portage feature par feature en reproduisant le comportement sans copier le code.

Problèmes de cette approche rewrite séparée ici :

| Facteur | Impact |
|---------|--------|
| App déjà riche et en prod | Double maintenance V1 + V2 jusqu’au cutover ; risque long de dérive |
| UX / identité à conserver | Rewrite = tentation de re-scaffolder UI « propre » et de casser la parité |
| Dette localisée (services statiques, Maps, hybridation Feature First) | Refactor ciblé plus rentable qu’un second monolithe à reconstruire |
| Partiel déjà engagé | `lib/features/prono/` (data/domain/presentation) prouve qu’une modernisation **dans** l’arbre actuel est viable |
| Repo sibling `dvcr_appli_v2` | Travail amont gelé ; continuer dessus dilue l’effort sans valeur prod immédiate |

---

## Décision

1. **Abandonner** le développement d’une application V2 **séparée** (nouveau projet Flutter sous `dvcr-v2/app/` ou sibling `dvcr_appli_v2`) comme voie principale.
2. **Moderniser in-place** l’application existante `dvcr_appli` : **refactoring d’architecture interne**, pas rewrite produit.
3. **« V2 »** désigne désormais l’**architecture cible** (Feature First, couches, Riverpod, Repository, Freezed, testabilité) **dans la même app** — pas un second repo.
4. **Conserver** : tous les écrans utiles, logique métier qui marche, identité graphique, parcours UX, features production. UX inchangée sauf demande explicite.
5. **Transformer module par module** : Presentation / Domain / Data ; Riverpod ; Repository Pattern ; Freezed / modèles typés ; suppression progressive des services statiques / duplication / dette.
6. **`dvcr_appli_v2`** (sibling hors ce monorepo) : projet **gelé / abandonné** — ne plus y développer. Suppression éventuelle = décision utilisateur ultérieure (**ne pas supprimer dans cette ADR**).
7. **Sources de vérité** : code de `dvcr_appli` (`lib/`, `functions/`) + docs mises à jour dans `dvcr-v2/` (`STRATEGY.md`, `MODERNIZATION_PLAN.md`, `ARCHITECTURE.md`, `SCOPE_V2.md`, ce ADR).
8. **Gate Architecture Review** (ADR-0003) **reste obligatoire**, avec chemins pointant vers le `lib/` de `dvcr_appli`.
9. **Aucun refactor code applicatif** sans validation utilisateur de cet ADR + du premier module du `MODERNIZATION_PLAN.md`.

### Ce que ADR-0001 conserve / ce qu’il cède

| Conservé (ADR-0001) | Superseedé par ADR-0004 |
|---------------------|-------------------------|
| Stack Flutter + Firebase | Rebuild from scratch dans un second arbre |
| Riverpod, GoRouter (cible), Dio HTTP, Freezed, Material 3, CI | « V1 intangible / V2 neuve » comme organisation repo |
| Feature First + couches | Interdiction de moderniser `lib/` in-place |
| Rejet Next.js / React | — |

---

## Pourquoi progressive modernization > rewrite (ici)

| Critère | Rewrite séparée | Modernisation in-place |
|---------|-----------------|------------------------|
| Continuité prod | Cutover tardif, double coût | Amélioration continue sur la base live |
| Risque UX | Élevé (recréation écrans) | Faible (comportement figé, archi interne) |
| ROI court terme | Faible (long avant valeur) | Fort (module livré = dette réduite) |
| Apprentissage codebase | Re-découverte | Capitalise sur ce qui marche |
| Déjà engagé | Scaffold V2 orphelin | `lib/features/prono/` amorcé |
| Alignement brief produit | « Nouvelle app » | « Évolution fidèle, intérieur solide » |

**Verdict architecte :** pour DVCR aujourd’hui, la modernisation progressive in-place est la **bonne** décision. Un rewrite ne se justifierait que si le produit ou la plateforme changeaient radicalement (stack non Flutter, modèle data incompatible, UX totale à refondre) — ce n’est pas le cas.

---

## Conséquences

### Positives

- Une seule codebase de vérité ; pas de double app à maintenir.
- Refactors incrémentaux validables (tests + Architecture Review + GO user).
- Réutilisation immédiate de l’identité et des parcours existants.
- `dvcr-v2/` reste le **dossier docs** (ADR, plans, review) — plus le futur root Flutter.

### Négatives / coûts

- Discipline stricte requise pour ne pas « nettoyer » en cassant les voisins.
- Coexistence temporaire `lib/screens/` + `lib/features/` + `lib/services/` pendant la migration.
- Introduction Riverpod / Freezed = changement de stack dans une app sans Riverpod aujourd’hui → Module Foundation d’abord.
- Dette historique (Maps UI, God services) traitée progressivement, pas effacée overnight.

### Suivi

- Plan d’exécution : `MODERNIZATION_PLAN.md` (remplace `MIGRATION_PLAN.md`).
- Résumé équipe/IA : `STRATEGY.md`.
- Checklist fin de module : `ARCHITECTURE_REVIEW.md` (AppRoot = racine `dvcr_appli`).
- Avant tout code : **GO utilisateur** sur ADR-0004 + Module 0 Foundation, puis Auth.

---

## Amendement (2026-07-26) — ordre Foundation → Auth

**Contexte :** une proposition antérieure du plan plaçait **Sponsors** en premier module fonctionnel (faible risque pédagogique). Analyse ciblée de l’auth actuelle (`AuthService` static, écrans qui appellent `FirebaseAuth` directement, absence de `features/auth` / Riverpod, session dans `_AppEntry`) : **Auth = dette élevée**, pas « déjà propre ».

**Révision :**

| Avant (proposition) | Après (retenu tant qu’Auth n’est pas Feature First) |
|---------------------|-----------------------------------------------------|
| Foundation → **Sponsors** → … | **Foundation → Auth → Home** → Sponsors → … |

- Premier chantier **technique** : Foundation ([`modules/FOUNDATION.md`](./modules/FOUNDATION.md)).
- Premier chantier **fonctionnel** : Auth, refactor archi **sans** changer l’UX ([`modules/AUTH.md`](./modules/AUTH.md)).
- Sponsors redevient candidat « petit pattern » **après** Auth (+ Home), ou plus tôt **uniquement** si Auth était déjà propre (exception non applicable aujourd’hui).

Détail et justification : `MODERNIZATION_PLAN.md` §3–4.

---

## Note — `dvcr_appli_v2`

Chemin sibling typique : `C:\Users\axeld\Music\dvcr_appli_v2`.

| Règle | |
|-------|--|
| Statut | **Gelé / abandonné** |
| Développement | **Interdit** (ne plus y committer de features) |
| Suppression | Uniquement sur décision explicite utilisateur, plus tard |
| Référence | Éventuellement historique ; **pas** source de vérité |

---

*Décision stratégique — aucun code applicatif Flutter dans ce document.*
