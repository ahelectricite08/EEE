# DVCR — Script Architecture Review (heuristiques)

**Rôle :** filet automatique. La checklist humaine `../ARCHITECTURE_REVIEW.md` reste **obligatoire**.  
**App Flutter (ADR-0004) :** racine **`dvcr_appli`** (`pubspec.yaml` + `lib/`) — **pas** `dvcr-v2/app/`.

## Usage

```powershell
cd dvcr-v2
.\scripts\architecture_review.ps1
.\scripts\architecture_review.ps1 -AppRoot ..
```

## Codes de sortie

| Code | Signification |
|------|----------------|
| 0 | Heuristiques OK (ou uniquement des *warnings* documentés) |
| 1 | Au moins un FAIL heuristique |
| 2 | `pubspec.yaml` absent sous AppRoot |

## Note modernisation in-place

Un **FAIL global** sur tout `lib/` est **attendu** tant que la dette legacy n’est pas résorbée module par module.  
La review humaine juge le **périmètre du module ouvert** (ne pas bloquer un module Sponsors sur des FAIL dans `screens/chat/`).  
Le script reste un filet de tendance / CI future (filtre par module = amélioration ultérieure).

## CI

Brancher ce script en fin de module / CI avec AppRoot = racine du repo `dvcr_appli`.
