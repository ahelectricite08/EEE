# Architecture Review — Module 2 — Home (tranche 2)

| Champ | Valeur |
|-------|--------|
| Date | 2026-07-26 |
| Auteur review | Auto (Lead Architect gate) |
| Branche / commit | `main` + working tree Home T2 |
| AppRoot | `dvcr_appli` (repo root) |
| Script auto | **PASS heuristique périmètre Home T2** : **0 FAIL Firestore/présentation** sous `lib/features/home/**` ; FAILs restants Home = **hardcode club copy préexistante** (parité UX, critère 3.12 « pas de hardcode **nouveau** ») ; FAILs script globaux = hybride `features/prono/*` préexistant (hors module — même note qu’Auth / Home T1) |
| Verdict | **PASS** |

#### Corrections obligatoires (si FAIL)
- *(aucune bloquante sur le périmètre Home tranche 2)*

---

#### 1. Conformité ADR-0001 (stack Flutter) + ADR-0004 (in-place)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 1.1 | Stack = Flutter + Dart + Firebase (+ Riverpod / Freezed) | OK | |
| 1.2 | Pas de stack Next.js / React séparée | OK | |
| 1.3 | Modernisation **in-place** dans `lib/` — pas `dvcr_appli_v2` | OK | |
| 1.4 | Refactor — **pas** rewrite from scratch | OK | Move / split / adapters |
| 1.5 | UX / identité inchangées | OK | Copy, sections, navigations conservées |

#### 2. Conformité ADR-0002 (pas d’événements permanents)
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 2.1 | Pas d’industrialisation `world_cup` / `esti` | OK | Mini-card WC isolée en part + commentaire ADR |
| 2.2 | Pas de nouvelle route événementielle | OK | |
| 2.3 | Client core ne s’accroche pas aux collections événementielles | OK | WC via `TournamentService` legacy inchangé |
| 2.4 | Pas de portage « au cas où » | OK | |

#### 3. Conformité ARCHITECTURE.md
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 3.1 | Feature First densifié sur Home | OK | UI sous `features/home/presentation` |
| 3.2 | Widget → Provider → UseCase → Repository | OK | Données home-owned ; hub via adapters |
| 3.3 | Pas d’imports croisés features introduits | OK | Auth via barrel public (`authSessionProvider`) |
| 3.4 | `core` / `shared` n’importent pas `features/*` | OK | |
| 3.5 | `presentation` n’appelle pas Firestore / HTTP directement | OK | Datasources + adapters (predictions / leaderboard / stadium / match lookup) |
| 3.6 | `domain` sans widgets ni SDK Firestore | OK | |
| 3.7 | Fichiers touchés ≤ 300 lignes (hors générés) | OK | Tous `features/home/**` ≤ 300 L |
| 3.8 | Pas de God class / singleton métier **nouveau** | OK | Façades legacy conservées |
| 3.9 | Pas de `Map` Firestore bruts dans UI modernisée (home-owned) | OK | Config Freezed ; Maps timeline live = legacy hub |
| 3.10 | Pas de dette navigation **nouvelle** | OK | Navigator legacy (WARN script) |
| 3.11 | État métier via Riverpod (layout / banner / podcast / adapters) | OK | |
| 3.12 | Tenant-first : zéro hardcode club **nouveau** | OK | Strings Sedan/CSSA = copy Accueil préexistante (parité) — voir dettes |

#### 4–5. SCOPE / PACKAGE_POLICY
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 4.x | Aligné HOME.md tranche 2 | OK | |
| 5.x | Aucun package ajouté | OK | |

#### 6. Clean Architecture / SOLID
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 6.1–6.5 | Use cases / repos / dependency rule | OK | + adapters hub Live/Match/Articles |
| 6.6 | `setState` = UI locale / live hub mirror | OK | Documenté |

#### 7. Tests
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 7.1 | Unit mappers / use cases / adapters smoke | OK | `test/features/home/` |
| 7.2 | Widget smoke HomeScreen | N/A | Parité manuelle checklist HOME.md |
| 7.4 | `flutter analyze` clean erreurs sur périmètre | OK | 0 error |

#### 8. Dette technique
| # | Critère | OK / N/A / FAIL | Note |
|---|---------|-----------------|------|
| 8.3 | Dettes listées | OK | Ci-dessous + `HOME_CLEANUP_PROPOSAL.md` |

### Dettes acceptées (Home tranche 2)

1. **Copy club (Sedan/CSSA)** dans UI Accueil — préexistante ; TenantConfig reporté (changer = UX).
2. **Adapters legacy** Live / MatchController / ArticleService — modules hors périmètre ; pas de migration Matchs/Articles.
3. **`FirebaseAuth.instance.authStateChanges()`** encore dans `_NextMatchCard` (prono footer) — session Auth partielle via `authSessionProvider` sur hero seulement.
4. **Façades** `HomeSectionsService` / `HomeBannerService` + re-exports `screens/home/*`.
5. **World Cup mini-card** — ADR-0002, part dédiée.
6. **GoRouter** — non introduit (WARN Navigator).
7. **`-StrictFeatures` FAILs prono** — hors chantier Home.
8. **Placeholders** `screens/home/home_feed_*.dart` etc. — suppression = GO cleanup séparé (`HOME_CLEANUP_PROPOSAL.md`).

### Verdict final

**PASS** — tranche 2 (UI Feature First + split ≤ 300 L + adapters hub + re-exports Auth-style).  
**STOP** — awaiting **GO user** avant Sponsors / tout autre module.  
Cleanup destructif : **interdit** sans GO explicite sur `HOME_CLEANUP_PROPOSAL.md`.
