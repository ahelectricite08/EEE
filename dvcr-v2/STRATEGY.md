# DVCR — Stratégie (1 page)

**Date :** 2026-07-26  
**Décision :** [ADR-0004](./ADR-0004-progressive-modernization-in-place.md) — modernisation progressive **in-place**  
**Plan :** [MODERNIZATION_PLAN.md](./MODERNIZATION_PLAN.md)  
**App de vérité :** repo `dvcr_appli` (`lib/`, `functions/`) — **pas** un second projet Flutter

---

## En une phrase

**Conserver l’UX et le produit qui marchent ; transformer l’architecture interne module par module.**

---

## Ce qu’on fait / ce qu’on ne fait pas

| On conserve | On transforme | On ne fait pas |
|-------------|---------------|----------------|
| Écrans, parcours, identité graphique | Feature First dans `lib/features/` | Rewrite / second app (`dvcr_appli_v2`, `dvcr-v2/app`) |
| Logique métier utile | Presentation / Domain / Data | Changer l’UX sans demande explicite |
| Firebase + Functions stables | Riverpod, Repository, Freezed | Big-bang destructif Firestore |
| Features production | Moins de services statiques / Maps UI | Scaffold massif de features vides |
| | Perf + tests par module | Casser les modules voisins |

---

## « V2 » = architecture cible, même app

« V2 » ne désigne **plus** un repo séparé. C’est la **cible d’architecture** documentée ici, atteinte **progressivement** dans `dvcr_appli`.

Docs : `ARCHITECTURE.md`, `SCOPE_V2.md`, `ARCHITECTURE_REVIEW.md`, ADR-0001 (stack) → ADR-0005 (cleanup GO).

---

## Méthode (cycle figé)

```
Analyse → Conception → Refactor (comportement inchangé)
  → Tests → Architecture Review (PASS obligatoire)
  → Cleanup Proposal (obligatoire — proposals only)
  → Validation suppressions (optionnel, GO item/batch)
  → Validation utilisateur → Module suivant
```

**Un module à la fois.** Gate review : [ARCHITECTURE_REVIEW.md](./ARCHITECTURE_REVIEW.md) (ADR-0003).  
**Cleanup :** identifier mort / doublons / legacy → **ne jamais supprimer sans GO** ([ADR-0005](./ADR-0005-cleanup-requires-user-go.md)).

---

## Ordre des modules (validé archi — à confirmer user)

1. **Foundation** — Riverpod, `ProviderScope`, `core/`, conventions ([`modules/FOUNDATION.md`](./modules/FOUNDATION.md))
2. **Auth** — premier chantier **fonctionnel** : `features/auth`, Repository, session ; UX login/register/reset **identique** ([`modules/AUTH.md`](./modules/AUTH.md))  
   *Pourquoi pas Sponsors en #1 :* Auth est en **dette élevée** (service static, `FirebaseAuth` partout, pas de Feature First) — voir analyse dans `MODERNIZATION_PLAN.md`.
3. **Accueil (Home)** — composition cœur app
4. Ensuite du **simple → complexe** : Sponsors (valider le pattern sur petite surface), Articles / Prono, Matches, Live…

Détail : `MODERNIZATION_PLAN.md`.

---

## Sibling gelé

`dvcr_appli_v2` : **abandonné / gelé** — ne plus y développer. Suppression éventuelle = décision user ultérieure.

---

## Pour l’IA / l’équipe

1. Lire ADR-0004 + ADR-0005 + ce fichier avant tout chantier.
2. Analyser le module existant → refactor interne → ne jamais réécrire from scratch.
3. Pas de code métier sans GO user sur ADR-0004 + module en cours (ordre : Foundation → Auth → Home…).
4. Après Review PASS : Cleanup Proposal ; **zéro delete** sans GO explicite.
5. Chemins de review = `lib/` de `dvcr_appli`, pas `dvcr-v2/app`.

*Une page — la vérité opérationnelle.*
