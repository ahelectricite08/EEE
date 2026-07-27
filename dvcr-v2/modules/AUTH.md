# Module 1 — Auth (modernisation architecture)

**Statut :** code livré — Architecture Review **PASS** — awaiting GO user / GO Home  
**Date :** 2026-07-26  
**App :** `dvcr_appli`  
**Dépend de :** [FOUNDATION.md](./FOUNDATION.md) (Riverpod + `core/`)  
**Done :** [AUTH_DONE.md](./AUTH_DONE.md) · Review : [AUTH_ARCHITECTURE_REVIEW.md](../docs/reviews/AUTH_ARCHITECTURE_REVIEW.md)  
**Plan :** [MODERNIZATION_PLAN.md](../MODERNIZATION_PLAN.md)

---

## Verdict analyse (2026-07-26) — Auth = **dette élevée**

Auth **n’est pas** Feature First propre. Ne pas démarrer par Sponsors pour « valider la méthode » tant que le socle session/connexion n’est pas modernisé.

| Constat | Preuve |
|---------|--------|
| Pas de `features/auth/` | Écrans dans `lib/screens/auth/` (+ re-export `login_screen.dart`) |
| Service **statique** | `AuthService` (`signIn` / `register` / `signOut` / `resetPassword` / `errorMessage`) |
| Contournement du service | `LoginScreen` appelle **directement** `FirebaseAuth.instance.signInWithEmailAndPassword` |
| Couplage global | `FirebaseAuth.instance` / `authStateChanges` partout (bootstrap, home, chat, admin, prono, services…) |
| State | `setState` + phases `_AppEntry` ; **pas** Riverpod / GetX / Provider package |
| Modèle | `UserModel` + `UserRole` Map-based ; pas Freezed ; pas de Session domain |
| DI | Aucune — static + singleton Firebase |
| `lib/core/` | **Absent** |

→ Premier chantier **fonctionnel** après Foundation = Auth (refactor archi, UX figée).

---

## Intent

Refactor **interne** : Repository + Riverpod + Feature First sous `lib/features/auth/`.  
**Comportement UX identique** (connexion, inscription, MDP oublié, guest, tutoriel, persistance session Firebase).

---

## IN scope

- Extraire `features/auth/{data,domain,presentation}`
- **Auth Repository** (interface domain + impl Firebase/Firestore)
- Providers Riverpod : session / auth state / actions (sign-in, register, reset, sign-out)
- Modèles domain : User (+ Session si utile) — Freezed si Foundation l’a introduit
- Erreurs auth typées / mapping FR existant (`AuthService.errorMessage` → domain/presentation)
- Brancher écrans login / register / reset sur providers (widgets déplacés ou thin wrappers)
- Nav post-auth : conserver le flux `_AppEntry` (guest → register → tutorial → app) ; remplacer les lectures directes Firebase **dans le périmètre auth** par providers
- Façade temporaire sur `AuthService` static si besoin de non-casser les consommateurs hors périmètre (dépréciation documentée)
- Tests : mappers, repo fake, error mapping ; smoke widget login si pertinent

## OUT of scope

- Redesign login / register / couleurs / copy
- Nouveau provider OAuth / social login
- Refactor Profile complet, RBAC admin, account deletion (sauf si strictement nécessaire pour compiler le module)
- Remplacer **tous** les `FirebaseAuth.instance` de l’app (chat, admin, match services…) — tranche ultérieure / consumers
- GoRouter cutover
- Sponsors / Prono / Home composition large

---

## Comportement à conserver (parité UX)

1. **Connexion** email + mot de passe ; messages d’erreur FR (codes Firebase + filet anglais)
2. **Inscription** prénom, nom, email, MDP, confirmation ; rôle défaut `supporter` ; doc Firestore `users/{uid}` comme aujourd’hui
3. **Code parrainage** optionnel à l’inscription (`ReferralService.useCode` — échec silencieux)
4. **Mot de passe oublié** (`sendPasswordResetEmail`) + feedback UI actuel (`_resetSent` / messages)
5. **Persistance session** Firebase Auth (cold start → user déjà connecté)
6. **Flux entrée** : loading/splash → guest (actus) **ou** register **ou** tutorial **ou** app selon `authState` + `isTutorialDone`
7. **Post-login** : navigation vers `/` (ou phase parent) comme aujourd’hui ; pas de nouvel onboarding
8. **Déconnexion** : comportement visible inchangé sur les écrans déjà couverts par le module (profile / shell auth) — ne pas redesign admin logout
9. **Mode invité** : accès actus sans compte ; CTA vers inscription / login inchangé
10. **Marquage tutoriel** à l’inscription (`markTutorialDone`) conservé

---

## Couches cibles

```
lib/features/auth/
  data/           # FirebaseAuthDatasource, Firestore user fetch, AuthRepositoryImpl
  domain/         # User, Session?, AuthRepository, AuthFailure / Result, use cases
  presentation/   # auth providers, login/register pages (ou wrappers), state
  auth.dart       # exports publics minimaux
```

Consommateurs hors feature : import `features/auth/auth.dart` uniquement (pas l’intérieur data/).

---

## Risques

| Risque | Mitigation |
|--------|------------|
| Casser le flux `_AppEntry` (guest/tutorial) | Diff minimal sur bootstrap ; tests manuels checklist ci-dessous |
| Double source de vérité (AuthService + Repository) | Une impl ; static = façade dépréciée ou suppression après bascule écrans auth |
| Login bypass déjà présent vs `AuthService.signIn` | Unifier via Repository dès le refactor (même comportement Firebase) |
| Tentation de nettoyer tous les `FirebaseAuth.instance` | Hors scope ; documenter dette acceptée |
| Couplage Referral / Tutorial | Garder appels existants depuis presentation/usecase ; ne pas refactorer ces services |

---

## Tests & DoD

- [x] `lib/features/auth/{data,domain,presentation}` en place
- [x] Écrans auth n’appellent plus Firebase Auth **directement** (passent par providers/repo)
- [x] `AuthService` static : retiré du chemin chaud auth **ou** façade fine documentée
- [x] Parité checklist comportement (§ ci-dessus) — à valider manuellement user
- [x] Tests unit error mapping + repo fake (sign-in / register / reset)
- [x] Analyze clean ; **Architecture Review PASS** ; **GO user** ⏳

### Non-régression manuelle

- [ ] Login OK / mauvais MDP / email inconnu (messages FR)
- [ ] Reset password (email envoyé / feedback)
- [ ] Register + guest browse + retour guest
- [ ] Cold start connecté → tutorial ou app
- [ ] Cold start déconnecté → guest
- [ ] Sign-out depuis profil (si dans périmètre) → retour guest/login attendu

---

*Code livré 2026-07-26 — voir [AUTH_DONE.md](./AUTH_DONE.md).*
