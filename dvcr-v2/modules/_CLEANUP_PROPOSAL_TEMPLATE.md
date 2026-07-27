# Cleanup Proposal — Module : `<NOM>`

**Module :** `<N — Nom>`  
**Date :** YYYY-MM-DD  
**Review liée :** `docs/reviews/<MODULE>_ARCHITECTURE_REVIEW.md`  
**ADR :** [ADR-0005](../ADR-0005-cleanup-requires-user-go.md)  
**Statut global :** **Awaiting user GO** — **aucune suppression effectuée**

---

## Règle

1. Identifier code **mort**, **doublons**, **legacy** après modernisation.
2. Proposer supprimer / fusionner / garder façade / différer.
3. **Ne jamais** supprimer ou fusionner du code applicatif sans **GO utilisateur explicite** (item ou batch nommé).
4. Après GO : cocher les items exécutés ; laisser le reste en Awaiting.

---

## Contexte (1 paragraphe)

> État du module (tranche, dualité screens/features, façades…).

---

## Candidats

| Item | Type | Chemins | Risque | Recommandation | Statut |
|------|------|---------|--------|----------------|--------|
| … | mort / doublon / legacy | `lib/…` | Faible / Moyen / Élevé | supprimer / fusionner / garder façade / différer | **Awaiting user GO** |

### Légende Type

| Type | Sens |
|------|------|
| **mort** | Aucun call site utile (ou orphelin après migration) |
| **doublon** | Deux chemins / APIs pour la même intention |
| **legacy** | Ancienne forme encore consommée (façade, re-export, Map model) |

### Légende Recommandation

| Reco | Sens |
|------|------|
| **supprimer** | Retirer après GO (vérifier analyze + smoke) |
| **fusionner** | Une seule impl ; migrer call sites puis retirer l’autre |
| **garder façade** | Temporary bridge OK ; documenter consumers restants |
| **différer** | Attendre module / tranche suivante |

---

## Batches GO suggérés (optionnel)

| Batch | Items | Prérequis |
|-------|-------|-----------|
| A | … | … |

---

## Rappel

- **Zéro** suppression dans le chantier proposal.
- Validation suppressions **optionnelle** et **séparable** de la Validation fonctionnelle module.
- Objectif : **une seule implémentation** par fonctionnalité.

---

*Proposal only — pas de code applicatif modifié par ce document.*
