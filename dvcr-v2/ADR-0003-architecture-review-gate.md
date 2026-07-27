# ADR-0003 — Gate Architecture Review en fin de chaque module

**Statut :** Accepté (chemins mis à jour avec ADR-0004)  
**Date :** 2026-07-26  
**Décideurs :** Lead Architect DVCR  
**Compléments :** `ARCHITECTURE_REVIEW.md`, `ARCHITECTURE.md`, `MODERNIZATION_PLAN.md`, `ADR-0001`, `ADR-0002`, `ADR-0004`, `ADR-0005`, `PACKAGE_POLICY.md`, `SCOPE_V2.md`, `STRATEGY.md`

---

## Contexte

La modernisation in-place se fait **module par module** (ADR-0004). Sans contrôle explicite en fin de module, les dérives (imports croisés, Maps Firestore dans l’UI, God services, packages opportunistes, modules événementiels « au cas où », hardcode club, rewrite déguisé) peuvent se réintroduire avant la validation utilisateur.

---

## Décision

1. **Gate obligatoire** : à la fin de chaque module, après les **Tests** et **avant** la **Validation utilisateur**, exécuter un **Architecture Review** selon `ARCHITECTURE_REVIEW.md`.
2. Cycle figé (cleanup : [ADR-0005](./ADR-0005-cleanup-requires-user-go.md)) :

   ```
   Analyse → Conception → Refactor
     → Tests → Architecture Review (obligatoire)
     → Corrections si FAIL → (rejouer Review jusqu’à PASS)
     → Cleanup Proposal (obligatoire — pas de delete)
     → Validation suppressions (optionnel, GO item/batch)
     → Validation utilisateur → Documentation
     → Module suivant (seulement après GO)
   ```

3. Un module n’est **jamais** « terminé » sans Architecture Review **PASS** (zéro FAIL ouvert sur la checklist).
4. **Double contrôle :**
   - **Humain / architecte** : checklist `ARCHITECTURE_REVIEW.md` (source de décision).
   - **Automatique** : heuristiques `scripts/architecture_review.ps1` avec **`-AppRoot` = racine `dvcr_appli`** — **ne remplace pas** la review humaine.
5. Toute dérive détectée doit être **corrigée** avant PASS et avant démo GO.
6. Écart durable → **ADR** daté ; pas de « dette temporaire » sur les interdits non négociables.

---

## Conséquences

### Positives

- Filet anti-dette à chaque incrément (dès Module Foundation).
- Alignement ADR-0001 / ADR-0002 / ADR-0004 / SCOPE / PACKAGE_POLICY.
- Validation utilisateur sur une base déjà conforme.

### Négatives / coûts

- Temps de review + éventuel rework avant GO.
- Faux positifs script possibles → arbitrage humain (`ARCHITECTURE_REVIEW.md` nuances).

### Suivi

- Historique dans `ARCHITECTURE_REVIEW.md`.
- Script CI : AppRoot = repo `dvcr_appli` (pas `dvcr-v2/app`).
- Pas de refactor sans GO ADR-0004 + module (`MODERNIZATION_PLAN.md`).
