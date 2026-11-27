# Level Up

An offline, privacy-first training system for Android and iOS, built with
Flutter. You are the hunter, training is the dungeon, and progress is the
level-up system.

** Level Up adds the "System" game layer and a new look.

## Run it

Flutter 3.47 or newer.

```
flutter pub get
flutter run
flutter test
```

Android and iOS projects are included. App ID: `com.levelup.app`. Change it
before you publish.

## What you get

### From GymMane (the training core, unchanged in behaviour)

- Body-map workout picker, set-by-set logging, warm-up / drop / failure /
  rest-pause / cluster sets, RPE/RIR, supersets, plate math, rest timer with
  alarm, crash-safe live session.
- Routines, weekly plans, rotations, rest days that keep streaks, progression
  rules, deload weeks, exercise progression ladders.
- **466 built-in exercises with animated illustrations** and instructions,
  filters by muscle / equipment / level / kind, custom exercises and media,
  "Places" for available equipment.
- Analytics: volume, streaks, weekly goals, PRs by rep range, e1RM, strength
  curves, heatmap, muscle split, monthly recap.
- Bodyweight, measurements, progress photos, Health Connect / Apple Health.
- Nutrition: 500+ foods, macros, water, supplements, meal plans and prep,
  fasting.
- CSV export, ZIP backup, imports from Hevy / Strong / Lyfta / FitNotes /
  openGym / GymMane, Strava export, widgets, journal, calculators, 17 languages.

### The Hunter System (`lib/system/`)

The app opens on the **Hunter dashboard**. GymMane's training screens live in
the *Training hub*, and every workout logged there feeds the System.

- **Registration** replaces the generic onboarding: `[SYSTEM INITIALIZATION]`
  boot sequence, hunter name, experience, path (class), training ground,
  session time, weekly target, limitations, PAR-Q+ safety check, awakening.
  New players start at E-Rank, Level 1, 0 XP, every attribute at level 1.
- **XP ledger**: every reward is an `XpTransaction` with a deterministic id
  (its idempotency reference). The same activity never pays twice, editing
  or deleting history never removes XP, and the ledger is visible in the app.
  Level formula `100 + 25 × (level − 1)`. Workouts pay by duration tier
  (20 / 35 / 50 / 70 / 85), recovery 25–35, mobility 20–30, with a daily cap.
- **Attributes**: Strength, Endurance, Mobility, Consistency, Recovery Mastery,
  each with its own XP and level (`75 + 15 × (level − 1)`). Tap one for its
  history graph, related exercises, quests, milestones and skills.
- **Daily quests**: Main, Side, Strength/Endurance/Mobility, Recovery,
  Discipline and Bonus, generated from experience, equipment, time,
  limitations, injuries, readiness and recent training. Accept, start (a real
  workout), pause, shorten, replace an exercise, reschedule or skip. Partial
  work pays in proportion. Difficulty E–S comes from experience, never level.
- **Weekly missions** adapt to the weekly target. The System proposes target
  changes and you approve them.
- **Ranks E → S** by level band, plus promotion requirements (quests, weekly
  missions, workouts, categories) and a promotion trial. Ranks are never
  removed. Promotion screen, history and rewards included.
- **Skill tree** (Strength, Endurance, Mobility, Discipline, Recovery): skills
  unlock from real training and cost a skill point (one per level and per
  promotion).
- **26 achievements** (Common → Legendary), **10 titles** (equip one),
  **profile frames**, **personal records** (with previous values, compared
  like with like), **boss quests** with beginner/advanced variants,
  **dungeons**, a **comeback** plan after 7+ days away, a **progression
  timeline**, a **notification inbox**, and pop-ups for level-ups, ranks,
  achievements, records and quests. Pop-ups, sound and particles are
  configurable and respect reduced motion.
- **Vitals**: readiness check-in, daily briefing, load management, shadow
  army (muscle balance), injury log and red-flag safety info.

All balance numbers are in `hunter_rules.dart` and `hunter_catalog.dart`.
System data is stored under the `hunter` key of the main save, so it is backed
up, restored and wiped together with the rest of the app's data.

```
lib/system/
  hunter_rules.dart        balance numbers and formulas
  hunter_catalog.dart      ranks, achievements, titles, skills, bosses, trials
  hunter_models.dart       player, XP transaction, quest, rank change, record
  quest_generator.dart     builds quests from the player's real situation
  hunter_engine.dart       ledger sync, attributes, ranks, quests, comeback
  registration_screen.dart hunter registration
  hunter_home.dart         home dashboard and quest board
  system_screen.dart       Status · Quests · Bosses · Rank · Skills · Awards ·
                           Records · Timeline · Vitals
  system_sheets.dart       quest, attribute, comeback, inbox, settings sheets
  system_alerts.dart       level-up / rank-up / achievement pop-ups
test/hunter_system_test.dart, test/system_screen_test.dart
```

## Not built yet

Guild / party / raid mode, encrypted cloud sync, an AI coach, voice logging,
coach dashboards, and push notifications for System alerts (they show in-app). These need a backend or accounts, and GymMane and Level
Up have neither. Health screening, red flags and injury guidance are general
education, not medical advice.

## Licence

Level Up is a modified version of GymMane, Copyright (C) 2026 InlitX,
released under the GNU GPL version 3 with an additional attribution term.
Modifications by the Level Up authors, November 2026: rebranding, the System
palette, a new app icon, and the System game layer in `lib/system/`
plus the hooks for it in the shell, home, profile and state files.

- Code: GPLv3, see [LICENSE](LICENSE) and [ADDITIONAL_TERMS.md](ADDITIONAL_TERMS.md).
  The About screen displays "Based on GymMane by InlitX", as required.
- The app is English only.
- Exercise art: CC BY-SA 4.0, see [CREDITS.md](CREDITS.md).
- Fonts: Nunito, SIL Open Font License.

The upstream README is kept at `docs/readme/README.upstream-gymmane.md`.
