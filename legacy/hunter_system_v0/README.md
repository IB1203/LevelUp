# Hunter System

A fitness RPG for Android and iOS, built with Flutter. Real training earns XP,
levels and hunter rank. The System hands you a daily quest sized to your time,
equipment and how you feel, guides you through it set by set, and pays you for
the work you actually do.

This is the playable core of the product described in the planning documents,
not all 60 modules. See "What is and isn't built" below.

## Run it

You need Flutter 3.27 or newer (`flutter --version`).

```
cd hunter_system
flutter create --platforms=android,ios --project-name hunter_system --org com.example .
flutter pub get
flutter run
```

The `flutter create` line generates the `android/` and `ios/` folders for your
machine. It leaves `lib/`, `pubspec.yaml` and the assets alone. If it adds a
`test/widget_test.dart`, delete that file (it refers to a template app that
doesn't exist here). Change `com.example` to your own identifier before you
publish. Building for iOS needs a Mac with Xcode.

Run the tests with `flutter test`.

## What is and isn't built

Built and working together:

| Area | What you get |
| --- | --- |
| Awakening | Boot sequence, five-question assessment, "player awakened" reveal |
| Status | Rank emblem, level, XP bar, streak, last-7-days figures, System messages |
| Daily quests | Generated from experience, goal, equipment, time, flagged body areas, check-in and recent training load, with a plain-language "why this quest" |
| Readiness | Energy, soreness and sleep check-in; low readiness or 3 training days in a row schedules recovery; reporting pain forces gentle movement and protects the streak |
| Workout | Set-by-set guide, rep counter, hold and rest timers, how-to sheet, replace with a reason, skip, finish early, progress saved after every set |
| Rewards | XP proportional to work done, streak bonus, levels with carry-over, ranks E to S, 16 achievements, personal bests, attribute points |
| Missed days | One missed day puts the streak at risk and a comeback quest saves it; longer breaks reset the streak only. XP and levels are never removed |
| Bonus quests | Request by time and focus, half XP, two a day |
| Library | 67 exercises written for this app, with search, filters, steps, cues and alternatives |
| Profile | Edit training profile (rebuilds today's quest), emblem style, animation and vibration switches, delete all data |

Not built yet: accounts and cloud sync, the Spring Boot backend, push
notifications, step/GPS tracking and wearables, weight logging for gym lifts,
dungeons and boss battles, skill tree, world map, companions, storyline,
nutrition, sleep, habits, social features, voice, camera form analysis, and the
AI coach. The app is fully offline: all data lives on the device.

## How the code is organised

```
lib/
  core/        game_rules.dart (every balance number), theme, shared widgets
  domain/      pure Dart, no Flutter imports
    models.dart            player, quest, readiness, save format
    exercise_catalog.dart  the exercise library
    quest_generator.dart   fitness logic: what to do today
    engine.dart            reward logic: XP, levels, streaks, achievements
  state/       app_controller.dart (Riverpod notifier + save store)
  features/    onboarding, home, quests, workout, library, progress, profile
test/          game_logic_test.dart (26 tests on the domain layer)
```

Two rules from the planning documents are enforced by this structure:

- **Fitness decisions and rewards are separate.** `quest_generator.dart`
  decides what is suitable; `engine.dart` decides what it is worth. The reward
  side cannot override a recovery day or a flagged body area.
- **Nothing is hardcoded in screens.** To rebalance the game, edit
  `core/game_rules.dart`. When a backend exists, that file is the one to
  replace with remote config.

Saving goes through the small `SaveStore` interface in `app_controller.dart`,
so a database or synced store can replace `shared_preferences` later without
touching the screens.

## Things to know before releasing

- The exercise difficulty and "loads this body area" labels are my training
  filters, not medical clearance. Have a qualified coach review the library
  and progression numbers.
- The exercise datasets named in the planning notes (Kinetic, RepDB,
  OpenExerciseDB) are not bundled. Check that each exists and read its licence
  yourself before importing; map records onto the `Exercise` class.
- The screen can dim during long holds. Adding the `wakelock_plus` package and
  enabling it in `WorkoutScreen` fixes that.
- Rajdhani is bundled under the SIL Open Font License (`assets/fonts/OFL.txt`).
- All names, art and copy are original. Keep it that way: don't add characters
  or assets from Solo Leveling.
