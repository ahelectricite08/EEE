# DVCR V2 — Politique d’ajout de packages

**Objectif :** limiter la surface de dépendances et éviter la dette supply-chain.  
**Date :** 2026-07-26

---

## Stack de base (autorisée sans ADR)

Flutter SDK, Firebase (Auth, Firestore, Storage, Messaging, Functions), Riverpod, GoRouter, Dio, Freezed, json_serializable, build_runner, flutter_lints, Material 3 (SDK), packages de test Flutter officiels / emulator liés au workflow CI.

---

## Ajouter un package — critères (tous requis)

1. **Open source** et licence compatible (OSI, usage commercial OK).
2. **Gratuit** pour l’usage prévu (pas de SaaS payant obligatoire caché).
3. **Maintenu** (commits / releases récents, issues traitées, compatible dernière Flutter stable).
4. **Largement utilisé** (adoption communautaire crédible ; pas un one-shot GitHub).
5. **Justification** : problème précis non couvert par la stack de base ou le SDK.

---

## Processus

1. Proposer le besoin + 1–2 alternatives (y compris « code maison »).
2. Vérifier les 4 critères ci-dessus.
3. Rédiger un **ADR** court (contexte, décision, conséquences).
4. Ajouter la dépendance **uniquement** après GO architecture / lead.

Sans ADR → **pas** d’ajout hors stack de base.

En fin de module, `ARCHITECTURE_REVIEW.md` (et le script `scripts/architecture_review.ps1`) vérifient qu’aucune dépendance hors politique n’a été introduite sans ADR.

---

## Exemples typiques nécessitant un ADR

Lecteurs vidéo, charts, markdown/HTML, share, connectivity, Lottie, deep-links avancés, etc. — même s’ils existaient en V1, chaque ajout V2 est **conscient** et documenté.
