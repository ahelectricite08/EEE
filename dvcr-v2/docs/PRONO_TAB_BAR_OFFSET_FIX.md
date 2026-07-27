# Prono — barre d’onglets trop haute (offset)

**Date :** 2026-07-26  
**Fichier :** `lib/features/prono/presentation/shell/prono_root_shell.dart`

## Symptôme

La barre d’onglets interne Prono (Accueil / Matchs / Progression / Social) flottait trop haut au-dessus de la bottom nav principale (pilule flottante).

## Cause

Le shell principal (`main_navigation.dart`) utilise `Scaffold(extendBody: true)` + une nav pilule.

Avec `extendBody: true`, Flutter (`Scaffold._BodyBuilder`) injecte déjà la **hauteur complète** de la `bottomNavigationBar` dans `MediaQuery.padding.bottom` du body :

```dart
bottom = max(metrics.padding.bottom, bodyConstraints.bottomWidgetsHeight)
```

Le shell Prono ajoutait en plus un offset fixe :

```dart
// AVANT (double comptage)
MediaQuery.paddingOf(context).bottom + 76
```

→ hauteur nav déjà présente **+ 76 px** → barre Prono trop haute (~écart visible important).

## Fix

Utiliser uniquement le padding injecté par le shell parent :

```dart
final mainNavClearance = MediaQuery.paddingOf(context).bottom;
```

Ce padding est lu sur le contexte **parent** (avant le nested `Scaffold`), car le slot `bottomNavigationBar` du Scaffold enfant retire le padding bas de son `MediaQuery`.

Aucun changement métier Prono ; `screens/prono/prono_shell.dart` (ancien hub) n’est pas concerné.

## Vérification

1. Ouvrir l’onglet Prono (mobile).
2. Confirmer que Accueil / Matchs / Progression / Social est juste au-dessus de la pilule principale (petit espace naturel ≈ padding haut de la nav).
3. Changer d’onglet Prono : pas de saut de layout.
4. Web (si Prono y est exposé) : même positionnement relatif.
5. `flutter analyze lib/features/prono/presentation/shell/prono_root_shell.dart`
