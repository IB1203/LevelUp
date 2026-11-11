import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/quests/quests_screen.dart';
import 'state/app_controller.dart';

class HunterApp extends StatelessWidget {
  const HunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hunter System',
      debugShowCheckedModeBanner: false,
      theme: buildHunterTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have started while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      ref.read(appProvider.notifier).refreshDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    if (!state.loaded) {
      return const Scaffold(
        body: Center(child: SystemLine('Loading', center: true)),
      );
    }
    if (state.player == null) return const OnboardingScreen();
    return const _Shell();
  }
}

class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          HomeScreen(),
          QuestsScreen(),
          LibraryScreen(),
          ProgressScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).go(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hexagon_outlined), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Quests'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Exercises'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
