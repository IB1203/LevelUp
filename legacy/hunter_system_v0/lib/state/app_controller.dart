import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/engine.dart';
import '../domain/models.dart';

/// Where the save file lives. Swap this for a synced store later without
/// touching the rest of the app.
abstract class SaveStore {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

class PrefsSaveStore implements SaveStore {
  static const _key = 'hunter_system_save_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String data) async {
    await (await SharedPreferences.getInstance()).setString(_key, data);
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

class MemorySaveStore implements SaveStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async => data = d;
  @override
  Future<void> clear() async => data = null;
}

final saveStoreProvider = Provider<SaveStore>((ref) => PrefsSaveStore());

final appProvider = NotifierProvider<AppController, AppState>(AppController.new);

/// Which bottom tab is showing.
final tabProvider = NotifierProvider<TabIndex, int>(TabIndex.new);

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;
  void go(int index) => state = index;
}

String todayKey() => dateKey(DateTime.now());

class AppController extends Notifier<AppState> {
  SaveStore get _store => ref.read(saveStoreProvider);

  @override
  AppState build() {
    Future.microtask(_load);
    return AppState();
  }

  Future<void> _load() async {
    AppState loaded;
    try {
      final raw = await _store.read();
      loaded = raw == null
          ? AppState(loaded: true)
          : AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A corrupt save should not lock the player out of the app.
      debugPrint('Could not read save: $e');
      loaded = AppState(loaded: true);
    }
    loaded.loaded = true;
    Engine.rollover(loaded, todayKey());
    state = loaded;
    _save();
  }

  void _commit() {
    state = state.touch();
    _save();
  }

  Future<void> _save() async {
    try {
      await _store.write(jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('Could not write save: $e');
    }
  }

  String _now() => DateTime.now().toIso8601String();

  /// Call when the app returns to the foreground: a new day may have started.
  void refreshDay() {
    if (!state.loaded) return;
    if (Engine.rollover(state, todayKey())) _commit();
  }

  void createPlayer(Player player) {
    Engine.startNewPlayer(state, player, todayKey());
    _commit();
  }

  void submitReadiness({
    required int energy,
    required int soreness,
    required int sleep,
    required bool pain,
  }) {
    Engine.submitReadiness(
      state,
      Readiness(
        dateKey: todayKey(),
        energy: energy,
        soreness: soreness,
        sleep: sleep,
        pain: pain,
      ),
    );
    _commit();
  }

  bool regenerateDaily({int? minutes, QuestFocus? focus}) {
    final ok = Engine.regenerateDaily(state, todayKey(), minutes: minutes, focus: focus);
    if (ok) _commit();
    return ok;
  }

  Quest? addBonusQuest({required int minutes, QuestFocus? focus}) {
    final q = Engine.addBonusQuest(state, todayKey(), minutes: minutes, focus: focus);
    if (q != null) _commit();
    return q;
  }

  bool logSet(Quest quest, int taskIndex, int amount) {
    final best = Engine.logSet(state, quest, taskIndex, amount);
    _commit();
    return best;
  }

  void skipTask(Quest quest, int taskIndex) {
    Engine.skipTask(quest, taskIndex);
    _commit();
  }

  void swapTask(Quest quest, int taskIndex, String exerciseId) {
    Engine.swapTask(state, quest, taskIndex, exerciseId);
    _commit();
  }

  QuestResult? finishQuest(Quest quest) {
    final result = Engine.finishQuest(state, quest, at: _now());
    _commit();
    return result;
  }

  /// Applies edits to the player and rebuilds today's quest if it has not
  /// been started, so the change takes effect immediately.
  void updatePlayer(void Function(Player) edit, {bool affectsQuests = false}) {
    final p = state.player;
    if (p == null) return;
    edit(p);
    if (affectsQuests) Engine.regenerateDaily(state, todayKey());
    _commit();
  }

  Future<void> resetEverything() async {
    await _store.clear();
    state = AppState(loaded: true);
  }
}
