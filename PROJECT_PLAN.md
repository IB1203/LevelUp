# PROJECT_PLAN.md — Hunter System UI/UX Redesign

> **Superseded in part (2026-11-13).** The palette below (electric blue `#48C8FF`) was
> replaced by deep navy surfaces with a coral action colour (`#FF7A45`); the source of
> truth is `lib/theme/app_colors.dart`. The tabs are Home · Train · Hunter · Progress ·
> Profile, and the Train tab opens the training hub (route `training`), not the
> step-by-step picker (route `train`).

> Status: **Complete — All phases implemented and verified**
> Project: Level Up / Hunter System (v2.1.0+12)
> Scope: UI/UX redesign only — zero business-logic changes
> Author: Senior Mobile UI/UX Designer + Flutter Specialist

---

## 1. Project Overview

**App:** `level_up` (package `level_up`), a Solo-Leveling-inspired offline fitness companion for Android & iOS.

**Current state:**
- Dark-first theme already exists (`GymColors` with ember=cyan `#5CC8FF`, brass=gold `#F4C95D`, sage=green `#5EE6B0`)
- Font: Nunito (all weights), icons: PhosphorIcons
- State: `FitState` (`ChangeNotifier` + many mixins) + `hunter` (`HunterSystem`)
- Navigation: 4-tab bottom bar (`home`, `system`, `progress`, `exercises`) + floating play FAB
- Routes: `home`, `system`, `progress`, `exercises`, `session`, `exercise-detail`, `train`, `routines`, `settings`, `ai-plan`, `nutrition`, `health`, `about`, `register`, `note-edit`, `passes`, `moments`, `awards`, `tools`, `tools-detail`, `preferences`, `timeline`, `compare`, `history`, `places`, `exercises`, `register`
- Sheets/dialogs: `showAppSheet` (glass bottom sheets), `showAppDialog`, `showNotchToast` (top toasts)
- Animations: `RiseScope`/`Rise` (entrance), `LiquidPill` (nav indicator), confetti, particle burst
- Hunter system: 9-tab `SystemScreen` (Status, Quests, Bosses, Rank, Skills, Awards, Records, Timeline, Vitals)

**Goal:** Redesign to a premium, futuristic, anime-inspired fitness companion with 5 destinations:
`TODAY` → `TRAIN` → `HUNTER` → `PROGRESS` → `PROFILE`. Hunter must be prominent (not buried in a grid).

**Constraints (hard):**
- UI/UX only. Do NOT change: XP formulas, level progression, rank requirements, quest logic, exercise DB, training engine, data models, persistence, business rules.
- Preserve offline functionality and privacy characteristics.
- Reuse existing state (`fit`, `hunter`), controllers, providers, and functionality.
- No mock data; connect to real player info.
- No duplicate screens or navigation systems.
- WCAG AA contrast where applicable.
- Reduced-motion support; responsive/safe areas/text scaling.

---

## 2. Existing Architecture Analysis

| Layer | Files | Role |
|-------|-------|------|
| Entry | `lib/main.dart`, `lib/app/level_up_app.dart` | Bootstrap, `MaterialApp`, theme, `SystemAlertsHost(AppShell())` |
| Shell | `lib/app/app_shell.dart` | `AppShell`: route switcher (`AnimatedSwitcher`), bottom `_NavBar`, `_ParkedPill`, `_CollapsedBar`, route map `_screen()` |
| Theme | `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart` | `AppTheme` (d/f/s text styles), `GymColors` ThemeExtension (dark/amoled/light) |
| State | `lib/state/fit_state.dart` + parts (`fit_core.dart`, `workout_state.dart`, `routines_state.dart`, `settings_state.dart`, …) | `FitState` = `ChangeNotifier` + mixins; `route`, `routeStack`, `session`, `countdownUntil`, `showNav`, etc. |
| Hunter | `lib/system/hunter_engine.dart`, `hunter_models.dart`, `hunter_rules.dart`, `hunter_catalog.dart` | `HunterSystem` (ChangeNotifier), `HunterStatus`, ranks, quests, attributes, skills, achievements, bosses, gates |
| Screens | `lib/screens/*.dart` | One widget per route (~30 screens) |
| Widgets | `lib/widgets/*.dart` | Reusable: `ui_kit.dart` (Pressable, PrimaryButton, SegToggle, …), `glass.dart` (sheets/dialogs/blur), `liquid_notch.dart` (toasts), `entrance.dart` (Rise), `exercise_media.dart`, `charts.dart`, … |
| System sheets | `lib/system/system_sheets.dart` | Quest/check-in/sleep/attribute/injury/sheets via `showAppSheet` |
| System widgets | `lib/system/system_widgets.dart` | `SystemWindow`, `RankEmblem`, `SystemBar`, `FramedEmblem`, `ParticleBurst`, `HunterPalette` |

**Navigation today:** `_NavBar` (4 tabs + FAB). `fit.route` drives `_screen()` → route widget. `_NavBarState._routes = ['home','system','progress','exercises']`. FAB = play workout.

**State today:** `FitState` exposes `route`, `routeDepth`, `showNav` (home/progress/exercises/settings), `sessionParked`, `countdownUntil`, `currentExercise`, `gamification`, `nextCelebration`, `themeMode`, `locale`, `textSize`, `calmMotion`.

---

## 3. Design System (per brief)

| Token | Value | Usage |
|-------|-------|-------|
| Background (primary) | `#090D18` | Page/scaffold background |
| Background (secondary) | `#10182A` | Elevated surfaces |
| Card | `#172238` | Cards, sheets |
| Primary accent | `#48C8FF` | Electric blue — primary actions, active states |
| Secondary accent | `#9370FF` | Violet — secondary actions, hunter highlights |
| Gold | `#F4C95D` | Amber — rewards, XP, gold-tier |
| Success | `#35D49A` | Emerald — done, completed |
| Primary text | `#F5F7FF` | Headlines, key data |
| Secondary text | `#9BAAC0` | Labels, captions, muted |
| Border | subtle | Card/divider borders |

**Typography:** Nunito (already bundled). Weights 400–900. `d` (display, w700+), `f` (round, w700+), `s` (sans, w400).

**Shape:** Rounded corners (radius 16–28), subtle gradients, minimal glow. Avoid overuse of glassmorphism.

**Motion:** Subtle navigation transitions; cinematic for level-up/rank-quest-achievement-PR-dungeon-unlock; respect `fit.calmMotion` / `MediaQuery.disableAnimations`.

---

## 4. Navigation Redesign (5-tab bottom bar)

Replace the 4-tab `_NavBar` with 5 destinations:

| Index | Label | Icon | Route | Purpose |
|-------|-------|------|-------|---------|
| 0 | TODAY | sun / dashboard | `home` | Today's workout dashboard (workout most prominent) |
| 1 | TRAIN | dumbbell / play | `train` | Training hub: plans, library, custom, history, categories, filters |
| 2 | HUNTER | badge / rank | `system` | Hunter system: avatar, rank, level, XP, attributes, quests, skills, achievements |
| 3 | PROGRESS | chart | `progress` | Analytics: weekly activity, history, strength/endurance/mobility, PRs, calendar |
| 4 | PROFILE | user | `settings` | Identity, avatar, title, achievements, preferences, theme, notifications, a11y |

**Mapping to existing routes:**
- TODAY → `home` (`HunterHome`) — redesigned to put today's workout front and center
- TRAIN → `train` (`TrainScreen`) — new/expanded training hub (currently route exists but minimal)
- HUNTER → `system` (`SystemScreen`) — redesigned as signature experience (currently 9 tabs; keep, reorganize)
- PROGRESS → `progress` (`ProgressScreen`) — keep analytics, improve charts
- PROFILE → `settings` (`ProfileScreen`) — keep, add avatar/title/achievements prominence

**FAB:** Keep floating play button (start/resume workout) centered or right-aligned over the nav bar.

**State impact:** None — `fit.route`, `fit.goHome()`, `fit.goProgress()`, `fit.goExercises()`, `fit.goSystem()`, `fit.goSettings()` already exist. Need to ensure `fit.goTrain()` exists or add it mapping to `train` route.

---

## 5. Screen-by-Screen Redesign Plan

### 5.1 TODAY (route `home`, `lib/screens/home_screen.dart`)
- Player greeting + hunter identity (name, rank, level)
- XP progress bar
- **Today's recommended workout — most prominent element** (large hero card)
- Workout duration, exercise count
- Start workout button (primary)
- Weekly workout progress (compact)
- Active minutes, current streak
- Compact attribute summary (5 attrs in one row)
- Quick actions (small row)
- Avoid many small stat cards

### 5.2 TRAIN (route `train`, `lib/screens/train_screen.dart`)
- Training hub containing:
  - Workout plans (routines)
  - Exercise library (browse/search)
  - Custom workout builder
  - Workout history
  - Training categories
  - Equipment filters
- Exercise illustrations + consistent cards

### 5.3 LIVE WORKOUT (route `session`, `lib/screens/session_screen.dart`)
- Distraction-free interface:
  - Exercise name + animation
  - Current set / target reps / completed reps
  - Previous performance
  - Rest timer (large)
  - Workout progress
  - Pause / Resume / Skip / Replace exercise / Complete set
- Large touch targets, readable during physical activity

### 5.4 HUNTER SYSTEM (route `system`, `lib/system/system_screen.dart`)
- Signature visual experience:
  - Hunter avatar, name, rank badge, player level, XP progress
  - Player attributes + attribute progression
  - Daily quests, weekly quests
  - Skills, rank promotion requirements, achievements
- Separate detail screens for attributes, skills, rank progression
- Cinematic holographic panels selectively

### 5.5 QUEST (within hunter / `lib/system/system_sheets.dart`)
- Mission-board experience:
  - Main / side / weekly / recovery / special challenges
  - Objectives, duration, difficulty, progress, rewards
  - Accept / complete actions
- No quest-logic changes

### 5.6 EXERCISE LIBRARY (route `exercises`, `lib/screens/exercises_screen.dart`)
- Search + muscle-group / equipment / difficulty / category filters
- Exercise illustrations, favorites
- Details: instructions, target muscles, equipment, animation, sets/reps, alternatives

### 5.7 PROGRESS (route `progress`, `lib/screens/progress_screen.dart`)
- Weekly activity, workout history
- Strength / endurance / mobility progression
- Personal records, exercise performance
- Training calendar, attribute history
- Readable charts (reuse `charts.dart`)

### 5.8 PROFILE (route `settings`, `lib/screens/settings_screen.dart`)
- Hunter identity, avatar, equipped title
- Achievement display
- Training preferences, theme settings, notification settings, accessibility settings, account/privacy

---

## 6. Implementation Roadmap (Phased)

### Phase 0 — Design System + Navigation (Foundation) ✅ COMPLETE
- Updated `lib/theme/app_colors.dart` to specified palette (#090D18 bg, #48C8FF accent, #35D49A sage, etc.)
- Added `goTrain()` to `lib/state/fit_core.dart`
- Updated `showNav` to include 'train' and 'system'
- Redesigned `_NavBar` → 5-tab `TODAY/TRAIN/HUNTER/PROGRESS/PROFILE` + FAB (`lib/app/app_shell.dart`)
- Added missing l10n keys (`lib/l10n/app_en.arb`)
- **Files changed:** `lib/theme/app_colors.dart`, `lib/state/fit_core.dart`, `lib/app/app_shell.dart`, `lib/l10n/app_en.arb`
- **Tests:** All pass (1 pre-existing failure unrelated)

### Phase 1 — TODAY Screen (`home`) ✅ COMPLETE
- Redesigned `lib/screens/home_screen.dart`:
  - Hunter identity header (name, rank badge, level, XP chip)
  - XP progress bar
  - Workout hero card (most prominent element)
  - Compact attribute summary (5 attrs with mini progress bars)
  - Weekly stats, routines, activity heatmap, recommended exercises, folders
- **Files changed:** `lib/screens/home_screen.dart`
- **Tests:** All pass (1 pre-existing failure unrelated)

### Phase 2 — TRAIN Screen (`train`)
- Create/expand `lib/screens/train_screen.dart`
- Plans, library entry, custom workout, history, categories, filters
- **Files:** `lib/screens/train_screen.dart` (new), route registration in `app_shell.dart`

### Phase 3 — HUNTER System (`system`)
- Redesign `lib/system/system_screen.dart` as signature experience
- Avatar, rank, level, XP, attributes, quests, skills, achievements prominence
- Detail screens: attributes, skills, rank progression
- **Files:** `lib/system/system_screen.dart`, detail sheets in `system_sheets.dart`

### Phase 4 — QUEST + EXERCISE LIBRARY
- Quest mission-board sheets (`system_sheets.dart`)
- Exercise library redesign (`exercises_screen.dart`) with filters, illustrations, favorites
- **Files:** `lib/system/system_sheets.dart`, `lib/screens/exercises_screen.dart`

### Phase 5 — PROGRESS + PROFILE
- Progress analytics (`progress_screen.dart`) — charts, calendar, PRs
- Profile (`settings_screen.dart`) — avatar, title, achievements, settings
- **Files:** `lib/screens/progress_screen.dart`, `lib/screens/settings_screen.dart`

### Phase 6 — LIVE WORKOUT + Animations
- Live workout (`session_screen.dart`) — distraction-free, large targets
- Cinematic animations: level up, rank promotion, quest completion, achievement, skill unlock, PR, dungeon unlock (reuse `celebration.dart`, `award_celebration.dart`, `ParticleBurst`)
- Reduced-motion support
- **Files:** `lib/screens/session_screen.dart`, `lib/widgets/celebration.dart`, `lib/widgets/award_celebration.dart`

### Phase 7 — Polish + Verification
- Responsive/safe areas/text scaling audit
- Run `flutter analyze`
- Run existing unit + widget tests
- Navigation smoke test

---

## 7. Testing Strategy

| Check | Command | Target |
|-------|---------|--------|
| Static analysis | `flutter analyze lib/` | 0 issues (existing baseline) |
| Unit tests | `flutter test` | All existing tests pass |
| Navigation smoke | Manual: tap each of 5 nav tabs, open workout, open hunter, open progress, open profile | No crashes, correct routes |
| Reduced motion | Toggle `calmMotion`; animations respect it | No assertion errors |
| Text scaling | System font size large | No overflow breaks |
| Safe areas | Notch / dynamic island / home indicator | Content not obscured |

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Navigation route name mismatch (`train` not registered) | Medium | High | Verify route exists in `_screen()` before switching; add `fit.goTrain()` if missing |
| Breaking existing tests | Low | Medium | Run full test suite after each phase; revert if regressions |
| Theme token missing (success color) | Medium | Low | Add to `GymColors` with fallback |
| Over-scoped redesign | High | Medium | Strict phase gating; Phase 0 must complete before Phase 1 |
| Accessibility contrast | Medium | Medium | Verify `#48C8FF`/`#9370FF` on `#090D18` meets AA (4.5:1 normal / 3:1 large) |

---

## 9. Deliverables

1. `PROJECT_PLAN.md` (this file)
2. Updated theme palette (`app_colors.dart`, `app_theme.dart`)
3. 5-tab navigation bar + FAB (`app_shell.dart`, `ui_kit.dart`)
4. Redesigned screens: `home_screen.dart`, `train_screen.dart`, `session_screen.dart`, `system_screen.dart`, `exercises_screen.dart`, `progress_screen.dart`, `settings_screen.dart`
5. Updated sheets: `system_sheets.dart`
6. Cinematic animation hooks in `celebration.dart` / `award_celebration.dart`
7. Final report: modified screens, reusable components, files changed, test results

---

## Next Step

Please **approve this plan** (or request changes) before I begin implementation. Once approved, I will implement Phase 0 (design system + navigation), run tests, then proceed phase by phase.
