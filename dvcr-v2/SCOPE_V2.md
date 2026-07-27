# DVCR — Périmètre architecture cible (SCOPE)

**Statut :** cadrage — aligné [ADR-0004](./ADR-0004-progressive-modernization-in-place.md)  
**Date :** 2026-07-26 (révisé : modernisation in-place)  
**Références :** `STRATEGY.md`, `ARCHITECTURE.md`, `ARCHITECTURE_REVIEW.md`, `MODERNIZATION_PLAN.md`, `FEATURES.md`, `ADR-0001` … `ADR-0004`, `PACKAGE_POLICY.md`.

> ### Bannière — « V2 » ne signifie plus un second repo
>
> **Avant (abandonné) :** V2 = nouvelle app Flutter (`dvcr-v2/app/`, sibling `dvcr_appli_v2`).  
> **Désormais :** V2 = **architecture cible dans la même app** `dvcr_appli` (Feature First, couches, Riverpod, Freezed…).  
> Décision : **ADR-0004**. Plan : **MODERNIZATION_PLAN.md**.  
> `dvcr_appli_v2` = **gelé / abandonné** — ne plus y développer.

---

## Sources de vérité

| Artefact | Rôle |
|----------|------|
| Code `dvcr_appli` (`lib/`, `functions/`) | **Produit & comportement** en production |
| `STRATEGY.md` | Résumé 1 page pour équipe / IA |
| `ARCHITECTURE.md` | Principes, couches, imports, DoD |
| `ARCHITECTURE_REVIEW.md` | Gate fin de module (PASS obligatoire) |
| `SCOPE_V2.md` (ce doc) | IN / OUT + sens de « V2 » |
| `MODERNIZATION_PLAN.md` | Ordre modules + cycle refactor |
| `MIGRATION_PLAN.md` | **Superseded** (historique rewrite) |
| `PACKAGE_POLICY.md` | Dépendances |
| `FEATURES.md` | Inventaire ✅ / ⛔ / ⚠️ |
| `ADR-0001` … `ADR-0004` | Décisions structurantes |
| `DVCR_AUDIT.md` | Pièges à ne pas reproduire / étendre |

Les docs dans `dvcr-v2/` sont les références d’**architecture** — plus un futur root Flutter.

---

## Intent

- **Produit :** plateforme club (CSSA / Sedan = premier tenant de référence) — viser tenant-ready **sans** hardcode club dans le code **nouvellement** écrit / refactoré.
- **Méthode :** modernisation progressive **in-place** — conserver UX, transformer l’intérieur.
- **App existante** = source de vérité comportementale **et** codebase à faire évoluer (pas une simple « référence à recopier ailleurs »).

---

## IN — Cœur à moderniser (modules permanents)

Même inventaire fonctionnel qu’auparavant — à traiter **dans** `lib/features/<module>/` au fil des modules :

| Domaine | Intention |
|---------|-----------|
| **Auth / Profile** | Compte, guest, session, guards, prefs, RGPD |
| **Home** | Feed compositeur |
| **Clubs / Matches** | Équipes, stades, calendrier, détail, classement, sync FFF |
| **Live (Direct)** | Consommation + admin match-day |
| **Stats** | Fiches stats + workbench staff |
| **Articles** | Actus, commentaires, éditorial |
| **Streaming** | DVCR TV / vidéos |
| **Notifications** | FCM, prefs, centre |
| **Chat / Communauté** | Salons, messages, modération |
| **Pronos** | Championnat + social (déjà partiellement sous `lib/features/prono/`) |
| **XP** | Niveaux, badges, referral |
| **Sponsors / Share** | Encars, templates — **1er module feature proposé** |
| **Benevoles / Adherents** | Team DVCR, HelloAsso |
| **Admin** | Shell RBAC + composition onglets |
| **Core / Foundation** | Bootstrap, theme, DI Riverpod, Freezed, CI, conventions |

Parité comportementale : `FEATURES.md` ✅.

---

## OUT — Hors modernisation « core »

| Élément | Traitement |
|---------|------------|
| **Rewrite / second app** (`dvcr-v2/app`, `dvcr_appli_v2` actif) | ❌ abandonné (ADR-0004) |
| **Coupe du Monde / World Cup** | ❌ pas d’industrialisation core — ADR-0002 |
| **Esti’DVCR** | ❌ idem |
| **Tournois temporaires** | ❌ idem |
| **Scaffold massif** de features vides | ❌ refusé |
| **Refactor code** avant GO ADR-0004 + module | ❌ refusé |
| **Hardcode club** dans code nouveau | ❌ refusé — TenantConfig / config |
| **Changement UX** non demandé | ❌ refusé |
| **Stack Next.js** | ❌ refusé (ADR-0001) |

Inventaire : `FEATURES.md` ⛔.

---

## Extensions (pattern)

Événements ponctuels = hors graphe d’imports du core modernisé ; flags tenant si besoin. Détail : ADR-0002.

---

## CSSA = config, pas code

Sur le code **refactoré / nouveau** :

- Nom, couleurs, logos, partenaires, compétitions FFF → config tenant
- Premier déploiement = seed / env CSSA, **fork interdit**

(La dette hardcode historique se résorbe module par module — ne pas l’étendre.)

---

## Ordre d’exécution (rappel)

```
Validation ADR-0004 + MODERNIZATION_PLAN (GO utilisateur)
  → Module 0 Foundation (Riverpod / Freezed / conventions)
  → Module 1 Sponsors (proposé)
  → Tests → Architecture Review PASS → Validation utilisateur
  → Prono (tranches) → Articles → … (voir MODERNIZATION_PLAN)
```

Sans **GO** sur ADR-0004 + premier module → **pas** de refactor `lib/`.  
Sans **Architecture Review PASS** → module non terminé (ADR-0003).

---

## Pushbacks architecte (non négociables)

1. Ne pas scaffolder toutes les features vides.
2. Ne pas industrialiser Esti / World Cup / tournois « au cas où ».
3. Ne pas démarrer le refactor sans GO ADR-0004.
4. Ne pas réécrire une feature from scratch.
5. Ne pas déclarer un module terminé sans Architecture Review PASS.
6. Ne pas développer dans `dvcr_appli_v2`.

---

*Cadrage uniquement — aucun code applicatif dans cette étape.*
