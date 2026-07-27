# Admin UTF-8 fix — accents cassés (�)

**Date :** 2026-07-26  
**Scope :** `lib/screens/admin/` (Pilotage / Direct)

## Cause

Deux fichiers Dart avaient été **sauvegardés en Windows-1252 (cp1252)** au lieu d’UTF-8 :

- `lib/screens/admin/tabs/dashboard/dashboard_tab.dart`
- `lib/screens/admin/tabs/direct/direct_tab.dart`

Les octets accentués (`é` = `0xE9`, tiret cadratin `—` = `0x97`, guillemets `«»`, etc.) ne sont pas du UTF-8 valide → l’UI affichait `�` / mojibake (`R�gie`, `sant�`, `syst�me`…).

Le reste de `lib/` était déjà UTF-8 valide (aucun autre fichier Dart invalide, pas de `Ã©` / U+FFFD restants).

## Correctif

1. Décodage **cp1252 → UTF-8** sur les 2 fichiers.
2. Sur Pilotage, remplacement des séparateurs ASCII `?` (copiés à la place des tirets) par `—` :
   - `Régie — activité, santé système…`
   - commentaires associés

## Avant / après

| Avant | Après |
| --- | --- |
| `R�gie ? activit�, sant� syst�me…` | `Régie — activité, santé système…` |
| `Compteurs op�rationnels` | `Compteurs opérationnels` |
| `D�MARRER UN MATCH` / `�MISSION` | `DÉMARRER UN MATCH` / `ÉMISSION` |
| `Lecture seule � suivi live…` | `Lecture seule — suivi live…` |

## Compteurs

- **2 fichiers** réencodés UTF-8
- **~102 caractères** non-ASCII restaurés
- **~58 lignes** UI / commentaires FR corrigées
- **4** séparateurs `?` → `—` (Pilotage)

## Prévention

Ouvrir / sauvegarder les `.dart` Admin en **UTF-8** (sans BOM) dans l’éditeur. Éviter un re-save « Western European / Windows-1252 » après un copier-coller Word / Outlook.
