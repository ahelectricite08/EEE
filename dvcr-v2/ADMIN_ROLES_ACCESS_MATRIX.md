# Matrice d’accès Admin — rôles × modules

> Audit code (2026-07-26). Source de vérité UI : `RolePermissionsService.defaultPermissions` + overrides Firestore `config/role_permissions`.  
> **Aucune permission modifiée** dans cet audit (docs only).

Références : `lib/services/role_permissions_service.dart`, `lib/screens/admin/admin_tab_registry.dart`, `lib/screens/admin/admin_nav_model.dart`, `lib/screens/admin/admin_controller.dart`, `lib/screens/admin_portal/admin_web_screen.dart`, `lib/screens/profile_screen.dart`, `lib/features/admin/domain/admin_rbac.dart`, `docs/admin_access.md`, `firestore.rules`.

---

## 1. Liste des rôles (tels que dans le code)

| Clé Firestore | Enum `UserRole` | Libellé UI | Accès Admin Center ? |
|---------------|-----------------|------------|----------------------|
| `admin` | `admin` | Admin | ✅ plein pouvoir (toutes perms) |
| `community_manager` | `communityManager` | Community Manager | ✅ périmètre CM |
| `editor` | `editor` | Éditeur | ✅ Actus (+ accès panel) |
| `statisticien` | `statisticien` | Statisticien | ✅ Stats + Direct **lecture seule** |
| `team_dvcr` | `teamDvcr` | Team DVCR | ❌ panel admin ; ✅ espace **Bénévoles** (app) |
| `supporter` | `supporter` | Membre | ❌ |
| `donateur` / `partenaire` | dépréciés | → normalisés en Membre | ❌ |

**Précision « bénévoles »** : ce n’est **pas** un rôle staff Admin. C’est le rôle membre `team_dvcr` (espace PDF/planning) + l’onglet admin `admin.benevoles` (gestion, admin-only par défaut).

Rôles staff badge (`kStaffBadgeRoles`) : admin, CM, éditeur, statisticien.

---

## 2. Tableau — Rôle × Module / Onglet / Action

Légende : ✅ accès · ❌ pas d’accès · ⚠️ partiel / lecture seule / asymétrie

### 2.1 Entrée au panel (`admin.access`)

| | Admin | CM | Éditeur | Statisticien | Team DVCR | Membre |
|--|:---:|:---:|:---:|:---:|:---:|:---:|
| Gate `AdminWebScreen` / route `/admin` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Raccourci Profil (app mobile) | ✅ | ✅ | ✅ | ⚠️ **absent** | ❌ | ❌ |
| Web Hosting (`home: AdminWebScreen`) | ✅ si connecté + perm | idem | idem | ✅ | ❌ | ❌ |

### 2.2 Onglets Admin Center (defaults)

| Onglet | Permission | Admin | CM | Éditeur | Statisticien |
|--------|------------|:---:|:---:|:---:|:---:|
| Pilotage | `admin.dashboard` | ✅ | ✅ | ❌ | ❌ |
| Direct | `admin.direct` | ✅ | ✅ | ❌ | ⚠️ **lecture seule** |
| Matchs | `admin.matches` | ✅ | ✅ | ❌ | ❌ |
| Statistiques match | `admin.stats` | ✅ | ❌ | ❌ | ✅ |
| Actus | `admin.articles` | ✅ | ❌ | ✅ | ❌ |
| Équipes & stades | `admin.stades` | ✅ | ❌ | ❌ | ❌ |
| Notifications | `admin.notifs` | ✅ | ❌ | ❌ | ❌ |
| Membres | `admin.users` | ✅ | ❌ | ❌ | ❌ |
| Chat & modération | `admin.community` | ✅ | ✅ | ❌ | ❌ |
| Bénévoles (gestion) | `admin.benevoles` | ✅ | ❌ | ❌ | ❌ |
| Adhérents | `admin.adherents` | ✅ | ❌ | ❌ | ❌ |
| Pronos & jeux | `admin.pronos` | ✅ | ✅ | ❌ | ❌ |
| XP & Niveaux | `admin.xp` | ✅ | ❌ | ❌ | ❌ |
| Réglages | `admin.settings` | ✅ | ❌ | ❌ | ❌ |
| Android TV | `admin.tv` | ✅ | ❌ | ❌ | ❌ |
| Journal | `admin.logs` | ✅ | ❌ | ❌ | ❌ |
| Staff & permissions | `admin.staff` | ✅ | ❌ | ❌ | ❌ |

`team_dvcr` / `supporter` : ❌ tous les onglets ci-dessus (pas de `admin.access`).

### 2.3 Actions sensibles (`AdminAction`)

| Action | Règle effective | Admin | CM | Éditeur | Statisticien |
|--------|-----------------|:---:|:---:|:---:|:---:|
| Attribuer rôles staff | rôle `admin` hardcodé | ✅ | ❌ | ❌ | ❌ |
| Attribuer rôles communauté | admin **ou** CM | ✅ | ✅ | ❌ | ❌ |
| Supprimer user Firebase | rôle `admin` | ✅ | ❌ | ❌ | ❌ |
| Ajustement XP manuel | rôle `admin` | ✅ | ❌ | ❌ | ❌ |
| Éditer matrice RBAC | rôle `admin` | ✅ | ❌ | ❌ | ❌ |
| Piloter le live | `admin.direct` **et** pas `isDirectReadOnly` | ✅ | ✅ | ❌ | ❌ |
| Push notifs bénévoles | `admin.benevoles.notifs` | ✅ | ❌ | ❌ | ❌ |

### 2.4 Hors panel Admin (contexte)

| Surface | Admin | CM | Éditeur | Statisticien | Team DVCR |
|---------|:---:|:---:|:---:|:---:|:---:|
| Espace Bénévoles (app profil) | ✅ aperçu | ❌ | ❌ | ❌ | ✅ |
| Chat (`chat.access` default) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `comments.moderate` (matrice) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Modération chat réelle (UI) | ✅ hardcodé admin/CM | ✅ | ❌ | ❌ | ⚠️ signalement seulement |

---

## 3. Doublons

### D1 — Triple couche RBAC (redondance majeure)
Trois systèmes coexistent pour « qui peut quoi » :
1. **`RolePermissionsService`** (+ Firestore) — utilisé pour onglets Admin / gate web.
2. **`UserService.canManage*` / `canAccessAdminPanel` / `canAccessStats`** — listes de rôles **hardcodées**, largement **mortes** (définies, quasi jamais appelées pour le panel).
3. **`AdminRbac`** (`lib/features/admin/domain/admin_rbac.dart`) — couche « features » **non branchée** (aucun appel hors fichier).

→ Risque : un admin lit une couche, le code runtime en utilise une autre.

### D2 — Mapping permission → onglet dupliqué
- `adminTabDefs[].permission` dans `admin_tab_registry.dart`
- **et** `allowedTabIndices()` dans `admin_nav_model.dart` (switch manuel permission → index)

Toute nouvelle permission d’onglet doit être ajoutée **deux fois** ; dérive possible.

### D3 — Permission orpheline `admin.badges`
Toujours dans `allPermissions` / matrice Staff, **aucun onglet** ne la gate. L’UI badges est sous **`admin.staff`** (onglet Staff). Deep-link `badges` → redirige vers Staff si `admin.staff`.

### D4 — Deux chemins d’entrée Admin (volontaire mais asymétrique)
| Chemin | Plateforme | Gate |
|--------|------------|------|
| Firebase Hosting → `AdminWebScreen` | Web | `admin.access` |
| Route `/admin` + push Profil | App | même gate **si** on ouvre l’écran |
| Carte « Admin » Profil | App | **hardcodé** admin ∪ CM ∪ éditeur — **pas** de check `admin.access` / **pas** statisticien |

### D5 — `comments.moderate` vs modération réelle
Présente dans la matrice RBAC (éditeur + CM), mais le chat / commentaires s’appuient surtout sur **`UserService.canModerateChat` / `canReportMessage*`** (rôles hardcodés), pas sur `RolePermissionsService.commentsModerate`.

### D6 — Espace Bénévoles : deux portes
- App : `BenevoleSpaceScreen` (Team DVCR + aperçu admin).
- Admin : onglet Bénévoles (`admin.benevoles`) pour config PDF / Sheet / push.

Pas un bug, mais deux surfaces à documenter clairement (déjà partiellement dans le code).

---

## 4. Incohérences (recommandations — pas de fix sans GO)

### I1 — Statisticien : UI Direct lecture seule ≠ Firestore écriture match
- UI : `isDirectReadOnly` bloque le pilotage live.
- `firestore.rules` : `canWriteMatchOperations()` inclut **statisticien** (faits / scores limités).
- `AdminRbac.canEditMatchOperations` dit aussi « stats peut éditer ».

**Reco** : trancher produit — soit durcir les rules (stats = stats sheets seulement), soit documenter que le RO Direct est cosmétique et que l’écriture passe par Stats / API.

### I2 — Profil app : statisticien sans raccourci Admin
Il a `admin.access` (web / `/admin` OK) mais la carte Profil l’exclut (`adminish` sans statisticien).

**Reco** : aligner sur `UserService.canAccessAdminPanel` **ou** sur `admin.access` (une seule source).

### I3 — `UserService.canManageDirect` = admin + statisticien (exclut CM)
À l’opposé de la matrice (`admin.direct` pour CM + pilotage plein) et de `isDirectReadOnly` (CM = écriture). Méthode legacy dangereuse si réutilisée.

**Reco** : supprimer ou déléguer à `RolePermissionsService` + `AdminAction.pilotLive`.

### I4 — CM : editorial Firestore vs onglet Actus
`canWriteEditorialContent()` (rules) autorise CM ; defaults UI **sans** `admin.articles`. CM peut écrire côté data sans onglet Actus (ou via autre UI).

**Reco** : soit ajouter `admin.articles` au CM, soit retirer CM des rules editorial.

### I5 — Commentaire `admin.adherents` « invisible app mobile »
Aucun filtre `kIsWeb` dans le shell : l’onglet apparaît aussi en admin embarqué app si la permission est présente (admin-only par défaut). Commentaire trompeur.

### I6 — Actions admin hardcodées hors matrice
`assignStaffRoles`, `editRbacMatrix`, etc. ignorent `config/role_permissions` : on ne peut pas déléguer via le panel Staff sans changer le code.

**Reco** : acceptable pour sécurité ; documenter explicitement « non surchargeable ».

### I7 — Docs `admin_access.md` vs réalité Profil
La doc décrit bien web + `/admin` et les defaults CM / stats / admin, mais **ne mentionne pas** l’asymétrie statisticien Profil ni la permission morte `admin.badges`.

---

## 5. Résumé product (≤ 10 lignes)

1. Quatre rôles ouvrent l’Admin Center : **Admin, CM, Éditeur, Statisticien** (`admin.access`).
2. **Admin** = tout ; **CM** = Pilotage, Direct, Matchs, Communauté, Pronos ; **Éditeur** = Actus ; **Statisticien** = Stats + Direct en lecture seule.
3. **Team DVCR** n’est pas staff Admin : espace Bénévoles app seulement ; gestion = onglet admin (admin-only).
4. Les permissions effectives peuvent être surchargées dans Firestore, sauf actions critiques hardcodées (RBAC matrix, delete user, rôles staff…).
5. Gros doublon : matrice configurable + helpers `UserService` morts + `AdminRbac` non branché.
6. Doublon technique : `adminTabDefs` et `allowedTabIndices` doivent rester synchronisés.
7. Asymétrie web/app : statisticien OK sur le portail web, **sans** bouton Admin sur le profil mobile.
8. Asymétrie sécurité : Direct RO côté UI pour le statisticien, mais rules Firestore lui permettent encore des écritures match limitées.
9. `admin.badges` est une permission zombie ; badges = sous-onglet de **Staff & permissions**.
10. Avant tout changement de droits : GO produit explicite (pas de patch silencieux hors bug critique).

---

## Top 3 à traiter en priorité

1. **Statisticien Direct RO vs rules write** (I1) — écart UI / sécurité réel.
2. **Raccourci Profil sans statisticien** (I2 / D4) — asymétrie web vs app.
3. **Triple RBAC + `admin.badges` orpheline** (D1 / D3) — dette et confusion opérationnelle.
