import 'models.dart';

/// The built-in exercise library.
///
/// These entries were written for this app, so there is no third-party
/// licence to track. If you import a larger open dataset later, map it onto
/// [Exercise] and keep the source and licence alongside each record.
///
/// Difficulty and "stresses" labels are training filters only. Have a
/// qualified coach review them before a public release.
class ExerciseCatalog {
  const ExerciseCatalog._();

  static final Map<String, Exercise> _byId = {for (final e in all) e.id: e};

  static Exercise byId(String id) => _byId[id] ?? all.first;

  static const _knee = Limitation.knee;
  static const _shoulder = Limitation.shoulder;
  static const _back = Limitation.lowerBack;
  static const _wrist = Limitation.wrist;
  static const _ankle = Limitation.ankle;

  static const _str = ExerciseCategory.strength;
  static const _core = ExerciseCategory.core;
  static const _cardio = ExerciseCategory.cardio;
  static const _mob = ExerciseCategory.mobility;

  static const List<Exercise> all = [
    // ---- Horizontal push ------------------------------------------------
    Exercise(
      id: 'wall_push_up', name: 'Wall push-up', category: _str,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps, shoulders',
      steps: [
        'Stand an arm\'s length from a wall, hands on it at chest height.',
        'Bend your elbows and bring your chest toward the wall.',
        'Press back until your arms are straight.',
      ],
      cue: 'Keep your body in one straight line from head to heels.',
    ),
    Exercise(
      id: 'incline_push_up', name: 'Incline push-up', category: _str,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps, shoulders',
      stresses: {_wrist},
      steps: [
        'Place your hands on a sturdy table, counter or sofa arm.',
        'Step back so your body forms a straight line.',
        'Lower your chest to the edge, then press away.',
      ],
      cue: 'The higher the surface, the easier the rep.',
    ),
    Exercise(
      id: 'knee_push_up', name: 'Knee push-up', category: _str,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps, shoulders',
      stresses: {_wrist},
      steps: [
        'Start on hands and knees, hands slightly wider than shoulders.',
        'Walk your hands forward until hips, shoulders and knees line up.',
        'Lower your chest toward the floor, then press up.',
      ],
      cue: 'Elbows point back at about 45 degrees, not straight out.',
    ),
    Exercise(
      id: 'push_up', name: 'Push-up', category: _str, difficulty: 2,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps, shoulders, core',
      stresses: {_wrist, _shoulder},
      steps: [
        'Start in a high plank, hands just wider than shoulders.',
        'Lower until your chest is a fist\'s height from the floor.',
        'Press the floor away until your arms are straight.',
      ],
      cue: 'Squeeze your glutes so your hips do not sag.',
    ),
    Exercise(
      id: 'decline_push_up', name: 'Decline push-up', category: _str, difficulty: 3,
      pattern: MovementPattern.horizontalPush, muscles: 'Upper chest, shoulders, triceps',
      equipment: {Equipment.bench}, stresses: {_wrist, _shoulder},
      steps: [
        'Place your feet on a bench or chair and your hands on the floor.',
        'Lower your chest toward the floor under control.',
        'Press back up without letting your hips drop.',
      ],
      cue: 'Brace your core before every rep.',
    ),
    Exercise(
      id: 'diamond_push_up', name: 'Diamond push-up', category: _str, difficulty: 3,
      pattern: MovementPattern.horizontalPush, muscles: 'Triceps, chest',
      stresses: {_wrist, _shoulder},
      steps: [
        'Set up in a plank with your thumbs and index fingers touching.',
        'Lower your chest toward your hands, elbows close to your ribs.',
        'Press back up.',
      ],
      cue: 'If your elbows flare, switch to a regular push-up.',
    ),
    Exercise(
      id: 'db_floor_press', name: 'Dumbbell floor press', category: _str,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps',
      equipment: {Equipment.dumbbells},
      steps: [
        'Lie on your back, knees bent, a dumbbell in each hand above your chest.',
        'Lower the weights until your upper arms rest on the floor.',
        'Press back up until your arms are straight.',
      ],
      cue: 'Pause on the floor for a beat; do not bounce.',
    ),
    Exercise(
      id: 'db_bench_press', name: 'Dumbbell bench press', category: _str, difficulty: 2,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps, shoulders',
      equipment: {Equipment.dumbbells, Equipment.bench}, stresses: {_shoulder},
      steps: [
        'Lie on a bench with a dumbbell in each hand at chest level.',
        'Press the weights up until your arms are straight.',
        'Lower slowly until your elbows are just below the bench line.',
      ],
      cue: 'Keep your feet planted and shoulder blades pulled together.',
    ),
    Exercise(
      id: 'band_chest_press', name: 'Band chest press', category: _str,
      pattern: MovementPattern.horizontalPush, muscles: 'Chest, triceps',
      equipment: {Equipment.bands},
      steps: [
        'Loop the band behind your upper back and hold an end in each hand.',
        'Press both hands forward until your arms are straight.',
        'Return slowly to your chest.',
      ],
      cue: 'Stagger your feet for balance.',
    ),

    // ---- Vertical push --------------------------------------------------
    Exercise(
      id: 'pike_push_up', name: 'Pike push-up', category: _str, difficulty: 2,
      pattern: MovementPattern.verticalPush, muscles: 'Shoulders, triceps',
      stresses: {_wrist, _shoulder},
      steps: [
        'From a plank, walk your feet in so your hips point at the ceiling.',
        'Bend your elbows and lower the top of your head toward the floor.',
        'Press back up to the pike position.',
      ],
      cue: 'Look at your feet, not the floor ahead.',
    ),
    Exercise(
      id: 'db_shoulder_press', name: 'Dumbbell shoulder press', category: _str, difficulty: 2,
      pattern: MovementPattern.verticalPush, muscles: 'Shoulders, triceps',
      equipment: {Equipment.dumbbells}, stresses: {_shoulder},
      steps: [
        'Hold a dumbbell in each hand at shoulder height, palms forward.',
        'Press both weights overhead until your arms are straight.',
        'Lower back to your shoulders under control.',
      ],
      cue: 'Ribs down: do not lean back to finish the press.',
    ),
    Exercise(
      id: 'band_overhead_press', name: 'Band overhead press', category: _str,
      pattern: MovementPattern.verticalPush, muscles: 'Shoulders, triceps',
      equipment: {Equipment.bands}, stresses: {_shoulder},
      steps: [
        'Stand on the band and hold the ends at shoulder height.',
        'Press overhead until your arms are straight.',
        'Lower slowly.',
      ],
      cue: 'Keep your wrists stacked over your elbows.',
    ),
    Exercise(
      id: 'wall_slide', name: 'Wall slide', category: _str,
      pattern: MovementPattern.verticalPush, muscles: 'Shoulders, upper back',
      steps: [
        'Stand with your back, head and forearms against a wall.',
        'Slide your arms up overhead, keeping contact with the wall.',
        'Slide back down until your elbows are below your shoulders.',
      ],
      cue: 'Go only as high as you can without your back arching.',
    ),

    // ---- Horizontal pull ------------------------------------------------
    Exercise(
      id: 'superman', name: 'Superman', category: _str,
      pattern: MovementPattern.horizontalPull, muscles: 'Lower back, glutes, upper back',
      stresses: {_back},
      steps: [
        'Lie face down with your arms stretched out in front.',
        'Lift your chest, arms and legs a few centimetres off the floor.',
        'Hold for a second, then lower.',
      ],
      cue: 'Lift long, not high. Keep your neck neutral.',
    ),
    Exercise(
      id: 'prone_y_raise', name: 'Prone Y raise', category: _str,
      pattern: MovementPattern.horizontalPull, muscles: 'Upper back, rear shoulders',
      steps: [
        'Lie face down, arms overhead in a Y shape, thumbs up.',
        'Lift your arms off the floor by squeezing your shoulder blades.',
        'Lower slowly.',
      ],
      cue: 'Keep your forehead resting on the floor.',
    ),
    Exercise(
      id: 'band_row', name: 'Band row', category: _str,
      pattern: MovementPattern.horizontalPull, muscles: 'Upper back, biceps',
      equipment: {Equipment.bands},
      steps: [
        'Sit tall with your legs out and the band looped around your feet.',
        'Pull the ends toward your ribs, squeezing your shoulder blades.',
        'Straighten your arms slowly.',
      ],
      cue: 'Lead with your elbows, not your hands.',
    ),
    Exercise(
      id: 'band_pull_apart', name: 'Band pull-apart', category: _str,
      pattern: MovementPattern.horizontalPull, muscles: 'Rear shoulders, upper back',
      equipment: {Equipment.bands},
      steps: [
        'Hold the band at chest height with straight arms.',
        'Pull your hands apart until the band touches your chest.',
        'Return slowly.',
      ],
      cue: 'Shoulders stay down, away from your ears.',
    ),
    Exercise(
      id: 'db_row', name: 'One-arm dumbbell row', category: _str, difficulty: 2,
      pattern: MovementPattern.horizontalPull, muscles: 'Lats, upper back, biceps',
      equipment: {Equipment.dumbbells}, perSide: true,
      steps: [
        'Rest one hand on a chair or your thigh, back flat, weight in the other hand.',
        'Pull the dumbbell toward your hip.',
        'Lower until your arm is straight.',
      ],
      cue: 'Keep your shoulders square to the floor.',
    ),
    Exercise(
      id: 'db_bent_over_row', name: 'Bent-over dumbbell row', category: _str, difficulty: 3,
      pattern: MovementPattern.horizontalPull, muscles: 'Upper back, lats, biceps',
      equipment: {Equipment.dumbbells}, stresses: {_back},
      steps: [
        'Hinge forward at the hips with a flat back, a dumbbell in each hand.',
        'Row both weights to your ribs.',
        'Lower under control.',
      ],
      cue: 'If your back rounds, stand up and reset.',
    ),

    // ---- Vertical pull --------------------------------------------------
    Exercise(
      id: 'dead_hang', name: 'Dead hang', category: _str, tracking: Tracking.seconds,
      pattern: MovementPattern.verticalPull, muscles: 'Grip, lats, shoulders',
      equipment: {Equipment.pullUpBar}, stresses: {_shoulder},
      steps: [
        'Grip the bar slightly wider than your shoulders.',
        'Hang with straight arms and your feet off the floor.',
        'Step down before your grip gives out.',
      ],
      cue: 'Pull your shoulders gently away from your ears.',
    ),
    Exercise(
      id: 'band_lat_pulldown', name: 'Band lat pulldown', category: _str,
      pattern: MovementPattern.verticalPull, muscles: 'Lats, biceps',
      equipment: {Equipment.bands},
      steps: [
        'Anchor the band high, such as over a closed door.',
        'Kneel and pull the ends down to your collarbones.',
        'Return slowly until your arms are straight.',
      ],
      cue: 'Check the anchor holds before every set.',
    ),
    Exercise(
      id: 'chin_up', name: 'Chin-up', category: _str, difficulty: 3,
      pattern: MovementPattern.verticalPull, muscles: 'Lats, biceps',
      equipment: {Equipment.pullUpBar}, stresses: {_shoulder},
      steps: [
        'Hang from the bar with your palms facing you.',
        'Pull until your chin clears the bar.',
        'Lower all the way down under control.',
      ],
      cue: 'No swinging: start each rep from a still hang.',
    ),
    Exercise(
      id: 'pull_up', name: 'Pull-up', category: _str, difficulty: 3,
      pattern: MovementPattern.verticalPull, muscles: 'Lats, upper back, biceps',
      equipment: {Equipment.pullUpBar}, stresses: {_shoulder},
      steps: [
        'Hang from the bar with your palms facing away.',
        'Pull your chest toward the bar.',
        'Lower until your arms are straight.',
      ],
      cue: 'Drive your elbows down toward your hips.',
    ),

    // ---- Squat ----------------------------------------------------------
    Exercise(
      id: 'chair_squat', name: 'Chair squat', category: _str,
      pattern: MovementPattern.squat, muscles: 'Quads, glutes',
      steps: [
        'Stand in front of a chair, feet shoulder-width apart.',
        'Sit back until you lightly touch the seat.',
        'Stand up by pushing through your whole foot.',
      ],
      cue: 'Use the chair as a target, not a rest stop.',
    ),
    Exercise(
      id: 'bodyweight_squat', name: 'Bodyweight squat', category: _str,
      pattern: MovementPattern.squat, muscles: 'Quads, glutes, hamstrings',
      stresses: {_knee},
      steps: [
        'Stand with feet shoulder-width apart, toes slightly out.',
        'Bend your hips and knees to lower as far as is comfortable.',
        'Stand back up tall.',
      ],
      cue: 'Knees track over your toes; chest stays proud.',
    ),
    Exercise(
      id: 'wall_sit', name: 'Wall sit', category: _str, tracking: Tracking.seconds,
      pattern: MovementPattern.squat, muscles: 'Quads, glutes',
      stresses: {_knee},
      steps: [
        'Lean your back against a wall and slide down.',
        'Stop when your thighs are near parallel to the floor.',
        'Hold, then push up through your heels to stand.',
      ],
      cue: 'Sit higher if your knees complain.',
    ),
    Exercise(
      id: 'goblet_squat', name: 'Goblet squat', category: _str, difficulty: 2,
      pattern: MovementPattern.squat, muscles: 'Quads, glutes, core',
      equipment: {Equipment.dumbbells}, stresses: {_knee},
      steps: [
        'Hold one dumbbell upright against your chest.',
        'Squat down between your knees, elbows inside your thighs.',
        'Drive up to standing.',
      ],
      cue: 'Keep the weight glued to your chest.',
    ),
    Exercise(
      id: 'jump_squat', name: 'Jump squat', category: _str, difficulty: 3,
      pattern: MovementPattern.squat, muscles: 'Quads, glutes, calves',
      impact: Impact.high, stresses: {_knee, _ankle, _back},
      steps: [
        'Squat down to a comfortable depth.',
        'Jump straight up, reaching tall.',
        'Land softly and sink into the next squat.',
      ],
      cue: 'Quiet landings. If they get loud, stop the set.',
    ),

    // ---- Lunge ----------------------------------------------------------
    Exercise(
      id: 'step_up', name: 'Step-up', category: _str, perSide: true,
      pattern: MovementPattern.lunge, muscles: 'Quads, glutes',
      stresses: {_knee},
      steps: [
        'Stand facing a low, stable step or stair.',
        'Step up with one foot and stand tall on it.',
        'Step back down with control.',
      ],
      cue: 'Push through the top foot instead of springing off the floor.',
    ),
    Exercise(
      id: 'reverse_lunge', name: 'Reverse lunge', category: _str, difficulty: 2, perSide: true,
      pattern: MovementPattern.lunge, muscles: 'Quads, glutes, hamstrings',
      stresses: {_knee},
      steps: [
        'Stand tall, then take a long step backward.',
        'Lower your back knee toward the floor.',
        'Push through your front foot to return.',
      ],
      cue: 'Keep most of your weight on the front leg.',
    ),
    Exercise(
      id: 'split_squat', name: 'Split squat', category: _str, difficulty: 2, perSide: true,
      pattern: MovementPattern.lunge, muscles: 'Quads, glutes',
      stresses: {_knee},
      steps: [
        'Stand in a long stride, one foot forward and one back.',
        'Lower straight down until your back knee nearly touches.',
        'Press back up without moving your feet.',
      ],
      cue: 'Hold a wall or chair if balance is the hard part.',
    ),
    Exercise(
      id: 'bulgarian_split_squat', name: 'Bulgarian split squat', category: _str, difficulty: 3,
      perSide: true, pattern: MovementPattern.lunge, muscles: 'Quads, glutes',
      equipment: {Equipment.bench}, stresses: {_knee},
      steps: [
        'Stand a stride in front of a bench with your back foot resting on it.',
        'Lower until your front thigh is near parallel.',
        'Drive up through the front foot.',
      ],
      cue: 'Lean slightly forward to keep the work in your glutes.',
    ),

    // ---- Hinge ----------------------------------------------------------
    Exercise(
      id: 'glute_bridge', name: 'Glute bridge', category: _str,
      pattern: MovementPattern.hinge, muscles: 'Glutes, hamstrings',
      steps: [
        'Lie on your back, knees bent, feet flat and hip-width apart.',
        'Press through your heels and lift your hips.',
        'Squeeze at the top, then lower slowly.',
      ],
      cue: 'Finish with your glutes, not by arching your back.',
    ),
    Exercise(
      id: 'good_morning', name: 'Bodyweight good morning', category: _str,
      pattern: MovementPattern.hinge, muscles: 'Hamstrings, glutes, lower back',
      stresses: {_back},
      steps: [
        'Stand tall with hands behind your head and knees soft.',
        'Push your hips back and tip your chest forward with a flat back.',
        'Squeeze your glutes to stand up.',
      ],
      cue: 'Imagine closing a car door with your hips.',
    ),
    Exercise(
      id: 'single_leg_bridge', name: 'Single-leg glute bridge', category: _str, difficulty: 2,
      perSide: true, pattern: MovementPattern.hinge, muscles: 'Glutes, hamstrings',
      steps: [
        'Set up for a glute bridge and lift one foot off the floor.',
        'Drive through the planted heel to raise your hips.',
        'Lower with control.',
      ],
      cue: 'Keep your hips level; do not let one side drop.',
    ),
    Exercise(
      id: 'db_rdl', name: 'Dumbbell Romanian deadlift', category: _str, difficulty: 2,
      pattern: MovementPattern.hinge, muscles: 'Hamstrings, glutes, lower back',
      equipment: {Equipment.dumbbells}, stresses: {_back},
      steps: [
        'Stand holding dumbbells in front of your thighs.',
        'Push your hips back and slide the weights down your legs.',
        'Stand tall once you feel a stretch in your hamstrings.',
      ],
      cue: 'Back stays flat and the weights stay close.',
    ),

    // ---- Core -----------------------------------------------------------
    Exercise(
      id: 'dead_bug', name: 'Dead bug', category: _core,
      pattern: MovementPattern.core, muscles: 'Deep core',
      steps: [
        'Lie on your back, arms straight up, knees bent at 90 degrees.',
        'Lower one arm and the opposite leg toward the floor.',
        'Return and switch sides.',
      ],
      cue: 'Keep your lower back gently pressed into the floor.',
    ),
    Exercise(
      id: 'bird_dog', name: 'Bird dog', category: _core,
      pattern: MovementPattern.core, muscles: 'Core, lower back, glutes',
      steps: [
        'Start on hands and knees.',
        'Reach one arm forward and the opposite leg back.',
        'Pause, return, and switch sides.',
      ],
      cue: 'Move slowly enough that a glass of water on your back would stay put.',
    ),
    Exercise(
      id: 'knee_plank', name: 'Knee plank', category: _core, tracking: Tracking.seconds,
      pattern: MovementPattern.core, muscles: 'Core, shoulders',
      steps: [
        'Rest on your forearms and knees.',
        'Form a straight line from head to knees.',
        'Hold while breathing steadily.',
      ],
      cue: 'Tuck your tailbone slightly.',
    ),
    Exercise(
      id: 'plank', name: 'Plank', category: _core, tracking: Tracking.seconds, difficulty: 2,
      pattern: MovementPattern.core, muscles: 'Core, shoulders',
      stresses: {_shoulder},
      steps: [
        'Rest on your forearms and toes.',
        'Brace your core so your body forms one straight line.',
        'Hold while breathing steadily.',
      ],
      cue: 'When your hips sag, the set is over.',
    ),
    Exercise(
      id: 'crunch', name: 'Crunch', category: _core,
      pattern: MovementPattern.core, muscles: 'Abdominals',
      steps: [
        'Lie on your back, knees bent, hands by your temples.',
        'Curl your shoulder blades off the floor.',
        'Lower slowly.',
      ],
      cue: 'Do not pull on your neck.',
    ),
    Exercise(
      id: 'side_plank', name: 'Side plank', category: _core, tracking: Tracking.seconds,
      difficulty: 2, perSide: true, pattern: MovementPattern.core, muscles: 'Obliques, shoulders',
      stresses: {_shoulder},
      steps: [
        'Lie on your side, propped on your forearm.',
        'Lift your hips so your body forms a straight line.',
        'Hold, then switch sides.',
      ],
      cue: 'Bend your bottom knee to make it easier.',
    ),
    Exercise(
      id: 'bicycle_crunch', name: 'Bicycle crunch', category: _core, difficulty: 2,
      pattern: MovementPattern.core, muscles: 'Abdominals, obliques',
      steps: [
        'Lie on your back, hands by your temples, legs lifted.',
        'Bring one elbow toward the opposite knee as the other leg extends.',
        'Switch sides in a smooth pedalling motion.',
      ],
      cue: 'Slow beats fast here.',
    ),
    Exercise(
      id: 'mountain_climber', name: 'Mountain climber', category: _core, difficulty: 2,
      pattern: MovementPattern.core, muscles: 'Core, shoulders, hip flexors',
      impact: Impact.medium, stresses: {_wrist, _shoulder},
      steps: [
        'Start in a high plank.',
        'Drive one knee toward your chest.',
        'Switch legs quickly while keeping your hips low.',
      ],
      cue: 'Shoulders stay over your wrists.',
    ),
    Exercise(
      id: 'leg_raise', name: 'Lying leg raise', category: _core, difficulty: 2,
      pattern: MovementPattern.core, muscles: 'Lower abdominals, hip flexors',
      stresses: {_back},
      steps: [
        'Lie on your back with your legs straight.',
        'Raise your legs until they point at the ceiling.',
        'Lower slowly, stopping just above the floor.',
      ],
      cue: 'Bend your knees if your lower back lifts.',
    ),
    Exercise(
      id: 'hollow_hold', name: 'Hollow hold', category: _core, tracking: Tracking.seconds,
      difficulty: 3, pattern: MovementPattern.core, muscles: 'Abdominals',
      stresses: {_back},
      steps: [
        'Lie on your back and press your lower back into the floor.',
        'Lift your shoulders and legs a little off the floor, arms overhead.',
        'Hold the banana shape.',
      ],
      cue: 'Raise your legs higher if your back starts to arch.',
    ),

    // ---- Cardio ---------------------------------------------------------
    Exercise(
      id: 'walk', name: 'Brisk walk', category: _cardio, tracking: Tracking.seconds,
      pattern: MovementPattern.walk, muscles: 'Heart, legs',
      steps: [
        'Walk at a pace where you can still talk in full sentences.',
        'Swing your arms naturally and stand tall.',
        'Indoors, pacing a hallway or marching in place counts.',
      ],
      cue: 'Comfortable and steady. This is not a race.',
    ),
    Exercise(
      id: 'march_in_place', name: 'March in place', category: _cardio, tracking: Tracking.seconds,
      pattern: MovementPattern.cardio, muscles: 'Heart, hip flexors',
      steps: [
        'Stand tall and lift one knee to hip height.',
        'Lower it and lift the other.',
        'Pump your arms in rhythm.',
      ],
      cue: 'Land softly on the whole foot.',
    ),
    Exercise(
      id: 'step_jack', name: 'Step jack', category: _cardio, tracking: Tracking.seconds,
      pattern: MovementPattern.cardio, muscles: 'Heart, shoulders, legs',
      steps: [
        'Step one foot out to the side while raising both arms overhead.',
        'Step back in and lower your arms.',
        'Repeat on the other side.',
      ],
      cue: 'A no-jump version of the jumping jack.',
    ),
    Exercise(
      id: 'shadow_boxing', name: 'Shadow boxing', category: _cardio, tracking: Tracking.seconds,
      pattern: MovementPattern.cardio, muscles: 'Heart, shoulders, core',
      steps: [
        'Stand in a staggered stance, hands up by your chin.',
        'Throw light, relaxed punches at an imaginary target.',
        'Keep your feet moving.',
      ],
      cue: 'Stop each punch just short of locking your elbow.',
    ),
    Exercise(
      id: 'jumping_jack', name: 'Jumping jack', category: _cardio, tracking: Tracking.seconds,
      difficulty: 2, impact: Impact.medium, stresses: {_knee, _ankle},
      pattern: MovementPattern.cardio, muscles: 'Heart, shoulders, calves',
      steps: [
        'Jump your feet apart while swinging your arms overhead.',
        'Jump your feet together and lower your arms.',
        'Find a steady rhythm.',
      ],
      cue: 'Stay light on the balls of your feet.',
    ),
    Exercise(
      id: 'jog_in_place', name: 'Jog in place', category: _cardio, tracking: Tracking.seconds,
      difficulty: 2, impact: Impact.medium, stresses: {_knee, _ankle},
      pattern: MovementPattern.cardio, muscles: 'Heart, legs',
      steps: [
        'Jog on the spot with relaxed shoulders.',
        'Lift your feet just clear of the floor.',
        'Breathe in a steady rhythm.',
      ],
      cue: 'Short, quick steps.',
    ),
    Exercise(
      id: 'high_knees', name: 'High knees', category: _cardio, tracking: Tracking.seconds,
      difficulty: 3, impact: Impact.high, stresses: {_knee, _ankle},
      pattern: MovementPattern.cardio, muscles: 'Heart, hip flexors, calves',
      steps: [
        'Run on the spot, driving each knee up to hip height.',
        'Pump your arms.',
        'Stay tall; do not lean back.',
      ],
      cue: 'Slow to a march the moment your form slips.',
    ),
    Exercise(
      id: 'burpee', name: 'Burpee', category: _cardio, difficulty: 3,
      impact: Impact.high, stresses: {_knee, _wrist, _shoulder, _back, _ankle},
      pattern: MovementPattern.cardio, muscles: 'Whole body',
      steps: [
        'Squat and place your hands on the floor.',
        'Step or jump your feet back to a plank, then return.',
        'Stand up and finish with a small jump.',
      ],
      cue: 'Stepping instead of jumping is always allowed.',
    ),

    // ---- Mobility -------------------------------------------------------
    Exercise(
      id: 'cat_cow', name: 'Cat-cow', category: _mob,
      pattern: MovementPattern.mobilitySpine, muscles: 'Spine',
      steps: [
        'Start on hands and knees.',
        'Round your back toward the ceiling and tuck your chin.',
        'Then let your belly drop and look gently forward.',
      ],
      cue: 'Move with your breath.',
    ),
    Exercise(
      id: 'childs_pose', name: 'Child\'s pose', category: _mob, tracking: Tracking.seconds,
      pattern: MovementPattern.mobilitySpine, muscles: 'Back, hips, shoulders',
      steps: [
        'Kneel and sit back toward your heels.',
        'Fold forward and reach your arms out in front.',
        'Rest your forehead down and breathe slowly.',
      ],
      cue: 'Widen your knees if your hips feel tight.',
    ),
    Exercise(
      id: 'thoracic_rotation', name: 'Thoracic rotation', category: _mob, perSide: true,
      pattern: MovementPattern.mobilitySpine, muscles: 'Upper back',
      steps: [
        'Start on hands and knees and place one hand behind your head.',
        'Rotate that elbow up toward the ceiling.',
        'Bring it back down toward the opposite arm.',
      ],
      cue: 'Follow your elbow with your eyes.',
    ),
    Exercise(
      id: 'cobra', name: 'Cobra stretch', category: _mob, tracking: Tracking.seconds,
      pattern: MovementPattern.mobilitySpine, muscles: 'Abdominals, spine',
      stresses: {_back, _wrist},
      steps: [
        'Lie face down with your hands under your shoulders.',
        'Gently press your chest up, hips staying on the floor.',
        'Hold a comfortable height and breathe.',
      ],
      cue: 'Only go as high as feels easy.',
    ),
    Exercise(
      id: 'shoulder_stretch', name: 'Cross-body shoulder stretch', category: _mob,
      tracking: Tracking.seconds, perSide: true,
      pattern: MovementPattern.mobilityUpper, muscles: 'Rear shoulder',
      steps: [
        'Bring one arm straight across your chest.',
        'Use the other arm to hug it gently closer.',
        'Hold, then switch sides.',
      ],
      cue: 'Keep the shoulder down, away from your ear.',
    ),
    Exercise(
      id: 'chest_opener', name: 'Chest opener', category: _mob, tracking: Tracking.seconds,
      pattern: MovementPattern.mobilityUpper, muscles: 'Chest, front shoulders',
      steps: [
        'Clasp your hands behind your back.',
        'Straighten your arms and lift your chest.',
        'Hold and breathe.',
      ],
      cue: 'Think "proud chest", not "bent back".',
    ),
    Exercise(
      id: 'arm_circles', name: 'Arm circles', category: _mob,
      pattern: MovementPattern.mobilityUpper, muscles: 'Shoulders',
      steps: [
        'Stand tall with your arms out to the sides.',
        'Draw slow circles, small at first and then larger.',
        'Reverse direction halfway through.',
      ],
      cue: 'Stay within a pain-free range.',
    ),
    Exercise(
      id: 'hip_flexor_stretch', name: 'Hip flexor stretch', category: _mob,
      tracking: Tracking.seconds, perSide: true,
      pattern: MovementPattern.mobilityLower, muscles: 'Hip flexors',
      steps: [
        'Kneel on one knee with the other foot in front.',
        'Tuck your tailbone and shift your hips gently forward.',
        'Hold, then switch sides.',
      ],
      cue: 'Put a cushion under your knee.',
    ),
    Exercise(
      id: 'hamstring_stretch', name: 'Hamstring stretch', category: _mob,
      tracking: Tracking.seconds, perSide: true,
      pattern: MovementPattern.mobilityLower, muscles: 'Hamstrings',
      steps: [
        'Sit with one leg straight and the other foot against your inner thigh.',
        'Hinge forward from the hips over the straight leg.',
        'Hold, then switch sides.',
      ],
      cue: 'Reach your chest forward rather than your head down.',
    ),
    Exercise(
      id: 'calf_stretch', name: 'Calf stretch', category: _mob,
      tracking: Tracking.seconds, perSide: true,
      pattern: MovementPattern.mobilityLower, muscles: 'Calves',
      steps: [
        'Face a wall and place both hands on it.',
        'Step one foot back and press that heel into the floor.',
        'Hold, then switch sides.',
      ],
      cue: 'Back leg straight, toes pointing forward.',
    ),
    Exercise(
      id: 'ankle_circles', name: 'Ankle circles', category: _mob, perSide: true,
      pattern: MovementPattern.mobilityLower, muscles: 'Ankles',
      steps: [
        'Sit or stand and lift one foot off the floor.',
        'Draw slow circles with your toes.',
        'Reverse direction, then switch feet.',
      ],
      cue: 'Make the circle as big as is comfortable.',
    ),
    Exercise(
      id: 'worlds_greatest', name: 'World\'s greatest stretch', category: _mob, difficulty: 2,
      perSide: true, pattern: MovementPattern.mobilityLower, muscles: 'Hips, hamstrings, upper back',
      stresses: {_wrist, _knee},
      steps: [
        'Step into a long lunge and place both hands inside your front foot.',
        'Rotate your inside arm up toward the ceiling.',
        'Bring it back down and switch sides.',
      ],
      cue: 'Keep your back leg long and strong.',
    ),
    Exercise(
      id: 'box_breathing', name: 'Box breathing', category: _mob, tracking: Tracking.seconds,
      pattern: MovementPattern.breath, muscles: 'Nervous system',
      steps: [
        'Sit or lie down comfortably.',
        'Breathe in for four counts and hold for four.',
        'Breathe out for four counts and hold for four. Repeat.',
      ],
      cue: 'Shorten the counts if you feel light-headed.',
    ),
  ];
}
