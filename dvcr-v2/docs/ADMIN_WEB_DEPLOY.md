# Admin Web — Deploy Hosting

**Date :** 2026-07-26  
**Commandes :** `flutter build web --release` → `firebase deploy --only hosting`  
**URL live :** https://drapeau-vert-app.web.app/

## Indexes `friend_requests` (réf.)

- `fromUid` + `status` + `createdAt` → demandes **envoyées**
- `toUid` + `status` + `createdAt` → demandes **reçues**
- `status` + `toUid` + `createdAt` → ancien ordre de champs encore **Activé** (redondant possible) — ne pas supprimer sans GO user ; fusion à proposer plus tard
