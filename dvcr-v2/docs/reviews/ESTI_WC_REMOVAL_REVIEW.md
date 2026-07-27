# Architecture Review — Esti + World Cup Removal

**Date :** 2026-07-26  
**Scope :** GO ADR-0005 — suppression Esti’DVCR + Coupe du Monde / World Cup  
**Références :** ADR-0002, ADR-0005, `modules/ESTI_WC_REMOVAL_DONE.md`

---

## Verdict

**PASS** (cleanup produit aligné ADR-0002)

---

## Checklist

| Critère | Statut | Note |
|---------|--------|------|
| Plus de surface UI Esti / CdM dans le graphe client | OK | Dossiers + rollouts + services tournoi supprimés |
| Home sans mini-carte événementielle | OK | `home_secondary_tournament` + bloc body retirés |
| Admin sans toggles / sections WC-Esti | OK | Settings CdM + partner WC + tabs esti/tournament retirés |
| Prono championnat intact | OK | `prono_scoring` / UI prono non touchés |
| Functions scoring tournoi hors export | OK | `tournament_scoring.js` deleted ; `index.js` commenté |
| Pas de collision avec Sponsors | OK | Hors périmètre |
| Deep-links admin | OK | Alias URL esti/cdm retirés ; indices historiques redirigent encore vers Pronos |

---

## Risques résiduels

1. **Functions déjà déployées** — callables WC/Esti peuvent encore exister en prod jusqu’à undeploy manuel. Impact : faible (plus de client).
2. **Data Firestore legacy** (`tournaments`, `esti_dvcr_leagues`, flags `show_*_tab`) — inerte côté app ; purge data = GO séparé.
3. **Audits historiques** (`AUDIT_CURRENT_STATE.md`, etc.) — snapshots antérieurs ; vérité = `ESTI_WC_REMOVAL_DONE.md` + `FEATURES.md` §11.

---

## Cleanup candidates (post-removal)

| Item | Statut |
|------|--------|
| Undeploy Firebase des 4 callables WC/Esti | Proposed — ops |
| Purge docs Firestore tournoi / flags | Proposed — GO data |
| Rafraîchir audits rationalization (snapshots) | Optional docs |

---

## Décision

Cleanup **accepté**. Module événementiel hors produit. **STOP** avant Sponsors.
