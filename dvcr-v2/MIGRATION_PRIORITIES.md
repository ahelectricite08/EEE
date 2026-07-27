# DVCR V2 — Priorités de modernisation (synthèse)

**Date :** 2026-07-26  
**Source :** [`AUDIT_CURRENT_STATE.md`](./AUDIT_CURRENT_STATE.md) + `MODERNIZATION_PLAN.md` + ADR-0002 / ADR-0004  
**App :** `dvcr_appli` (in-place)  
**Règle d’ordre :** Foundation → **Auth** → **Home** → simple → complexe.  
**Interdit core :** Esti’DVCR / World Cup / tournois temporaires (ADR-0002).

---

## État des modules socle

| Module | Doc | État code (vérifié) | Action |
|--------|-----|---------------------|--------|
| **0 — Foundation** | `modules/FOUNDATION_DONE.md` | `lib/core/` + Riverpod + `ProviderScope` | **Terminé** — ne pas rouvrir |
| **1 — Auth** | `modules/AUTH.md` (pas de `AUTH_DONE.md`) | `lib/features/auth/` branché (écrans + façade + `_AppEntry`) mais Freezed **non généré**, tests absents, Review/GO manquants | **À clôturer** |
| **2 — Home** | (conception à rédiger) | `lib/screens/home/*` legacy | **Après GO Auth** |
| **3 — Sponsors** | — | `sponsor_service` + widgets | Après Home |
| **⛔ Esti / WC / tournois** | ADR-0002 | Code encore dans le repo | **Ne pas moderniser en core** |

---

## Priorités Forte

### F1 — Clôturer Auth (immédiat)

**Pourquoi :** premier feature fonctionnel du plan ; structure déjà posée ; DoD incomplet = risque de partir sur Home avec un socle session bancal.

**À faire (docs/plan — pas scope de cet audit) :**

1. Générer Freezed (`auth_user` / `auth_session`) et stabiliser le build  
2. Tests mappers + repo fake (DoD `AUTH.md`)  
3. Architecture Review PASS + `AUTH_DONE.md` + **GO user**  
4. Mettre à jour `AUTH.md` (constats « Auth absent » obsolètes)

**Ne pas :** démarrer Home / Sponsors / refactors transverses Auth consumers (`FirebaseAuth.instance` hors périmètre) avant GO.

### F2 — Home (composition) après GO Auth

**Pourquoi :** cœur de l’app mobile ; compose live, actus, MOTM, dons, sections — bénéfice produit immédiat une fois la session propre.

**Cadre :** orchestration via providers / APIs publiques ; **pas de redesign** ; un module à la fois.

### F3 — Garde-fou ADR-0002 (permanent pendant la modernisation)

**Pourquoi :** Esti / World Cup / tournois / `tournament_scoring.js` / rollouts / admin sections sont **encore dans le monorepo**. La tentation de les « nettoyer en Feature First » reconstituerait de la dette dans le core commercialisable.

**Action :** aucune industrialisation core ; pas de dossiers `features/esti` / `features/tournaments` cœur ; extensions isolées seulement si besoin produit + ADR dédié.

---

## Priorités Moyenne

| ID | Item | Justification |
|----|------|---------------|
| M1 | **Sponsors** Feature First | Petit terrain post-Home ; valide le cycle Analyse→Review→GO |
| M2 | Dualité **Prono** (`features/prono` vs `screens/prono`) | Amorcé ; réduire sans big-bang |
| M3 | **Articles** (lecture) ou tranche Prono | Simple → complexe selon GO |
| M4 | Isolation progressive imports WC/Esti | Dette repo sans les porter en core |
| M5 | **TenantConfig** sur code nouvellement touché | Sortir hardcodes CSSA (`club_branding.dart`, etc.) |

---

## Priorités Faible

| ID | Item | Justification |
|----|------|---------------|
| f1 | GoRouter | Différé (Foundation OUT ; module Navigation) |
| f2 | Migration massive `FirebaseAuth.instance` | Hors DoD Auth |
| f3 | Dio vs `http` | Non bloquant |
| f4 | Suppression suspects morts (`OnboardingScreen`, scripts one-shot) | Après confirmation usage |
| f5 | Refactor admin shell global | Découper par domaine plus tard |
| f6 | ADR packages média/charts/markdown | Au moment du module concerné |

---

## File d’attente recommandée (ordre)

```
[DONE] 0 Foundation
[NOW]  1 Auth → clôture DoD + Review + GO
[NEXT] 2 Home composition
       3 Sponsors
       4 Articles (lecture) et/ou Prono (tranche)
       5+ Matches → Live → Notifs → Chat → XP → Profile → Admin (par domaine)
[NEVER en core] Esti / World Cup / tournois (ADR-0002)
```

---

## Top 3 à retenir

1. **Finir Auth** (codegen, tests, Review, GO) — avant tout autre feature.  
2. **Home** ensuite — composition, UX inchangée.  
3. **Ne pas moderniser Esti/WorldCup/tournois** dans le core — ADR-0002.

---

## Hors file (rappels)

- Pas de rewrite / second app (`dvcr_appli_v2` gelé — ADR-0004).  
- Pas de scaffold massif de features vides.  
- Pas de changement UX non demandé.  
- Un module à la fois ; Architecture Review obligatoire (ADR-0003).

---

*Synthèse docs only — zéro modification de code applicatif.*
