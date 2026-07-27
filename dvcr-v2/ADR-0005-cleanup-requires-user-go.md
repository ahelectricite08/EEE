# ADR-0005 — Cleanup proposal only ; delete / merge after explicit user GO

**Statut :** Accepté  
**Date :** 2026-07-26  
**Décideurs :** Lead Architect DVCR  
**Compléments :** `ARCHITECTURE_REVIEW.md`, `MODERNIZATION_PLAN.md`, `STRATEGY.md`, `ADR-0003`, `ADR-0004`, `modules/_CLEANUP_PROPOSAL_TEMPLATE.md`

---

## Contexte

Chaque module modernisé laisse souvent :

- du **code mort** (call sites disparus, façades orphelines) ;
- des **doublons** (re-exports, dual `screens/` + `features/`, deux modèles pour le même concept) ;
- du **legacy** utile temporairement (façade static, consumers hors périmètre).

Sans règle, la tentation est de « nettoyer » immédiatement après Review PASS — au risque de casser un call site oublié, de supprimer une façade encore consommée, ou de fusionner trop tôt.

Objectif produit / archi : **une seule implémentation par fonctionnalité**, architecture simple — **sans** suppression impulsive.

---

## Décision

1. **Fin de chaque module** (après Architecture Review PASS) : produire une **Cleanup Proposal** (pas une cleanup exécutée).
2. La proposal **identifie** uniquement : code mort, doublons, anciennes implémentations / legacy à fusionner ou retirer.
3. **Interdit** de supprimer, fusionner ou déplacer du code applicatif au titre du cleanup **sans GO utilisateur explicite** écrit (item par item ou batch nommé dans la proposal).
4. Statut par défaut de chaque item : **`Awaiting user GO`**. Après GO : exécuter uniquement le batch validé ; le reste reste proposé.
5. La Validation « suppressions » peut être **séparée** de la Validation fonctionnelle du module (parité UX) — optionnel mais recommandé pour ne pas bloquer le GO module suivant.
6. Cycle figé (complète ADR-0003) :

   ```
   … → Tests → Architecture Review (PASS)
     → Cleanup Proposal (obligatoire, docs)
     → Validation suppressions (optionnel, GO item/batch)
     → Validation utilisateur module → Documentation
     → Module suivant (seulement après GO module)
   ```

7. Livrable type : `dvcr-v2/modules/<MODULE>_CLEANUP_PROPOSAL.md` (template `_CLEANUP_PROPOSAL_TEMPLATE.md`).
8. L’Architecture Review doit contenir une section **« Cleanup candidates (dead / duplicate / legacy) »** avec statut **Proposed (not deleted)** — voir `ARCHITECTURE_REVIEW.md`.
9. **Zéro suppression** dans le même chantier que la rédaction de la proposal (sauf GO préalable déjà écrit).

---

## Conséquences

### Positives

- Une seule implémentation cible, sans big-bang delete risqué.
- Trace écrite des dettes / candidats avant tout GO.
- Découplage possible : GO fonctionnel module ≠ GO cleanup.

### Négatives / coûts

- Coexistence temporaire façades + feature (attendu ADR-0004).
- Discipline : l’IA / l’équipe ne « range » pas le repo sans validation.

### Suivi

- Proposals existantes : `FOUNDATION_CLEANUP_PROPOSAL.md`, `AUTH_CLEANUP_PROPOSAL.md`, `HOME_CLEANUP_PROPOSAL.md`.
- Gate review : section cleanup dans `ARCHITECTURE_REVIEW.md`.
- Rappel ops : **aucune suppression code applicatif** sans GO.

---

*Décision process — aucun code applicatif Flutter dans ce document.*
