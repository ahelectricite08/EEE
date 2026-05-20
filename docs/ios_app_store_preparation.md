# Dossier App Store iOS — DVCR (prêt à coller)

Document unique : **politique de confidentialité** (URL + source dans le repo), **fiche App Store** (FR), **checklist technique** avant build Mac.  
**État au repo** : la politique à jour est [`web/privacy.html`](web/privacy.html) ; après `flutter build web` + `firebase deploy --only hosting`, elle est servie sur `https://drapeau-vert-app.web.app/privacy`.  
À adapter si la réalité juridique ou le produit change — ce n’est pas un avis juridique.

---

## Bloc 1 — Politique de confidentialité (à héberger en HTTPS)

**URL publiée (Android + iOS)** : `https://drapeau-vert-app.web.app/privacy` — **une seule politique pour les deux stores** est la norme ; Apple et Google attendent une URL HTTPS cohérente avec l’app.  
Le fichier source dans le dépôt est [`web/privacy.html`](web/privacy.html) (déployé via Firebase Hosting, voir `firebase.json`).  
*(Le texte long plus bas dans ce doc reste un brouillon optionnel si tu veux aller plus loin juridiquement.)*

---

### Politique de confidentialité — application DVCR

*Dernière mise à jour : [DATE]*

**Qui sommes-nous**  
L’application mobile **DVCR** (« Drapeau Vert Carton Rouge ») est éditée dans le cadre de la communauté autour du **CS Sedan Ardennes** et des contenus DVCR. Pour toute question relative à vos données : **[CONTACT]**.

**Données que nous traitons**  
L’application permet notamment : actualités, lives / replays, matchs, pronostics, chat, profil utilisateur, notifications.

Nous pouvons traiter notamment :

- **Données de compte** : identifiant utilisateur, adresse e-mail (si tu utilises l’authentification par e-mail / mot de passe ou fournisseurs liés), pseudonyme ou nom d’affichage, photo de profil si tu en ajoutes une.
- **Données d’usage dans l’app** : contenus que tu consultes, messages que tu envoies dans le chat, pronostics, favoris, préférences (ex. notifications), interactions avec les fonctionnalités.
- **Données techniques** : type d’appareil, système, identifiants techniques nécessaires au bon fonctionnement (ex. jeton de notification push).
- **Contenus que tu publies** : textes, réactions dans les limites prévues par l’app et la modération.

**Finalités**  
Fourniture du service (compte, affichage des contenus, pronos, chat), sécurité et modération, amélioration de l’expérience, envoi de **notifications push** si tu les acceptes, respect des obligations légales.

**Base légale (résumé)**  
Exécution du service et, le cas échéant, **intérêt légitime** (sécurité, lutte contre les abus) ou **consentement** lorsque la loi l’exige (ex. certaines notifications marketing si un jour elles existent hors cadre strictement nécessaire au service).

**Prestataires techniques**  
Nous utilisons **Google Firebase** (hébergement des données applicatives, authentification, base de données temps réel ou équivalent, messagerie push selon configuration). Les données peuvent être traitées sur l’infrastructure de Google conformément à sa documentation et ses engagements.  
Il n’y a pas dans le code actuel de **SDK publicitaire** ou d’**analytics marketing** type « Firebase Analytics » dédié au suivi publicitaire ; les traitements principaux sont ceux liés au fonctionnement de l’app via Firebase.

**Durée de conservation**  
Les données sont conservées le temps nécessaire au fonctionnement du service et aux obligations légales. Certains contenus (ex. messages) peuvent être supprimés ou anonymisés selon les règles de modération et d’administration.

**Destinataires**  
Personnel autorisé et prestataires techniques (ex. Google). Pas de vente de données personnelles à des annonceurs dans le cadre décrit ici.

**Vos droits (RGPD — utilisateurs concernés)**  
Droit d’accès, de rectification, d’effacement, de limitation, d’opposition dans les conditions prévues par la loi, et droit d’introduire une réclamation auprès de la CNIL. Pour exercer tes droits : **[CONTACT]**.

**Sécurité**  
Mesures techniques et organisationnelles raisonnables pour protéger les données. Aucun système n’est exempt de risque.

**Mineurs**  
L’application peut ne pas être destinée aux très jeunes enfants. Si des fonctionnalités imposent un âge minimum, elles devront être alignées sur les règles App Store et la loi.

**Modifications**  
Nous pourrons mettre à jour cette politique ; la date en tête d’article sera révisée. L’usage continu de l’app après publication d’une nouvelle version vaut prise de connaissance, sauf disposition contraire obligatoire.

**Contact**  
**[CONTACT]**

---

## Bloc 2 — Fiche App Store (français France)

Champs typiques App Store Connect. Ajuste les longueurs si la console impose une limite stricte au moment du collage.

### Nom (30 caractères max)
```
DVCR
```
*(ou « DVCR - CSSA » si tu veux préciser Sedan et que ça passe en 30 caractères.)*

### Sous-titre (30 caractères max)
```
Actus, live, prono & communauté
```
*(29 caractères — à valider dans la console.)*

### Texte promotionnel (170 caractères, optionnel, modifiable sans nouveau binaire)
```
L’app de la tribu DVCR : actus, directs, replays, matchs du CSSA, pronos et chat entre supporters. Reste branché club, partage et ambiance tribune.
```

### Description (extrait — complète avec tes USP réels, max ~4000 caractères)

```
DVCR, c’est l’app de la communauté autour du CS Sedan Ardennes et du projet Drapeau Vert Carton Rouge.

• Actus et contenus autour du club
• Lives, replays et suivis de rencontres
• Matchs, calendrier et infos pratiques
• Pronostics et jeux entre supporters (selon saisons / compétitions activées)
• Chat et espace social pour échanger dans le respect
• Profil, favoris et notifications pour ne rien manquer

Télécharge DVCR pour suivre le club au quotidien et vivre l’expérience avec les autres supporters.

Site : https://www.dvcr.fr
```

### Mots-clés (100 caractères max, séparés par des virgules, sans espace après la virgule — règles Apple)

```
cssa,sedan,football,club,actus,live,prono,supporters,dvcr,ardennes
```
*(À raccourcir si la console refuse — priorise ce qui différencie.)*

### URL de support (obligatoire en pratique)
```
https://www.dvcr.fr
```
*(Ou une page « Contact » dédiée si tu en as une.)*

### URL politique de confidentialité (obligatoire — la même pour iOS et Android)
```
https://drapeau-vert-app.web.app/privacy
```
*(Source : [`web/privacy.html`](web/privacy.html) ; déployer avec `flutter build web` puis `firebase deploy --only hosting`.)*

### Notes pour l’App Privacy (questionnaire Apple)

À déclarer de façon cohérente avec ton usage réel :

| Donnée / usage | Exemple de déclaration |
|----------------|-------------------------|
| Identifiant utilisateur / compte | Lié au compte, pour le fonctionnement du service |
| E-mail | Compte / contact, si collecté |
| Messages utilisateur | Chat, pour le fonctionnement du service |
| Diagnostics (si tu actives un jour un crash reporter tiers) | À ajouter seulement si vrai |

**Notifications** : déjà couvert par le cadre push ; pas de pub ciblée dans le code actuel repéré.

---

## Bloc 3 — Checklist Flutter / iOS avant build Mac (depuis Windows)

Coche au fur et à mesure.

### Identité de l’app

- [ ] **Bundle ID** identique partout : portail Apple `fr.dvcr.app` = Xcode = Firebase iOS = App Store Connect.  
  - *Aujourd’hui le dépôt a encore `com.example.dvcrAppli` dans* `ios/Runner.xcodeproj/project.pbxproj` *— à remplacer par `fr.dvcr.app` au moment du build (ou sur une branche `release/ios`).*
- [ ] **Version** : `pubspec.yaml` `version: x.y.z+build` avec `build` incrémenté à chaque soumission.

### Firebase

- [ ] App iOS créée dans la console Firebase avec **Bundle ID** définitif.
- [ ] `GoogleService-Info.plist` téléchargé et placé dans `ios/Runner/` (ne pas committer de secrets sur un repo public si risque — sinon OK en privé).
- [ ] FCM / APNs : capability **Push Notifications** sur l’App ID (déjà prévu chez Apple) ; clé APNs côté Firebase si demandé par la console.

### Xcode (sur Mac)

- [ ] `flutter pub get`
- [ ] `cd ios && pod install`
- [ ] Ouvrir `ios/Runner.xcworkspace`
- [ ] **Signing** : équipe *Drapeau Vert Carton Rouge*, certificat / profil automatiques OK.
- [ ] `Product > Archive` ou `flutter build ipa --release`

### Contenu store (sans Mac)

- [ ] Captures d’écran aux **tailles** requises par Apple pour ta cible d’appareils (prévoir iPhone 6,5" et 6,7" au minimum selon les règles en vigueur au moment du dépôt).
- [ ] Icône 1024×1024 sans transparence ni coins arrondis (App Store).
- [ ] Textes du bloc 2 collés dans App Store Connect.
- [ ] URL politique de confidentialité **en ligne** et en HTTPS (`https://drapeau-vert-app.web.app/privacy`).

### Tests

- [ ] `flutter analyze` sans erreurs bloquantes
- [ ] `flutter test`
- [ ] Build Android release OK (même codebase)

### Après upload

- [ ] **TestFlight** : groupe de test internes, puis externes si besoin.
- [ ] Vérifier **deep links** / ouverture depuis notification si tu utilises des `data` FCM.

---

## Résumé « jour J » App Store Connect débloqué

1. Vérifier que la politique est **à jour en ligne** : `flutter build web` → `firebase deploy --only hosting` → contrôler [drapeau-vert-app.web.app/privacy](https://drapeau-vert-app.web.app/privacy).  
2. Coller métadonnées + URLs dans App Store Connect (bloc 2) — **confidentialité** = `https://drapeau-vert-app.web.app/privacy`.  
3. Sur Mac : checklist bloc 3 → IPA → Transporter ou Xcode → TestFlight.

Si tu veux une **version anglaise** courte de la politique ou des textes App Store EN, demande en une phrase.
