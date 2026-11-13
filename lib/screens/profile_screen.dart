import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/l10n.dart';
import '../models/profile.dart';
import '../services/food_library.dart';
import '../services/media_store.dart';
import '../state/fit_state.dart';
import '../system/hunter_engine.dart';
import '../system/system_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/file_thumb.dart';
import '../widgets/glass.dart';
import '../widgets/medal_shelf.dart';
import '../widgets/name_ticker.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/ui_kit.dart';
import 'gym_pass_screen.dart';
import 'recap_screen.dart';
import 'settings_screen.dart';

const List<String> kProfileBadges = ['gold', 'blue', 'green'];

Color badgeColor(String id) => switch (id) {
  'blue' => const Color(0xFF4A9EEB),
  'green' => const Color(0xFF54B979),
  _ => const Color(0xFFE8B84B),
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  static const _reach = 210.0;
  final _scroll = ScrollController();
  final _pull = ValueNotifier<double>(0);
  late final AnimationController _back;
  double _from = 0;
  bool _armed = false;
  bool _opening = false;
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    if (fit.nutritionBeta) FoodLibrary.load();
    _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))
      ..addListener(() => _pull.value = _from * (1 - Curves.easeOutCubic.transform(_back.value)));
  }

  @override
  void dispose() {
    _back.dispose();
    _scroll.dispose();
    _pull.dispose();
    super.dispose();
  }

  void _move(PointerMoveEvent e) {
    if (_opening || !_scroll.hasClients) return;
    final dy = e.delta.dy;
    final atTop = _scroll.position.pixels <= 0.5;
    if (_pull.value <= 0 && !(atTop && dy > 0)) return;
    _back.stop();
    final drag = dy < 0 ? 0.8 : 0.66 * (1 - (_pull.value / (_reach * 1.45)).clamp(0.0, 0.88));
    _pull.value = (_pull.value + dy * drag).clamp(0.0, _reach * 1.3);
    if (_scroll.position.pixels != 0) _scroll.jumpTo(0);
    final armed = _pull.value >= _reach;
    if (armed != _armed) {
      _armed = armed;
      if (armed) {
        HapticFeedback.heavyImpact();
        _burst++;
      }
    }
  }

  Future<void> _release(PointerEvent _) async {
    if (_opening || _pull.value <= 0) return;
    if (_pull.value >= _reach) {
      _opening = true;
      await openRecap(context);
      _pull.value = 0;
      _armed = false;
      _opening = false;
      return;
    }
    _from = _pull.value;
    _armed = false;
    _back.forward(from: 0);
  }

  Future<void> _pickBanner() async {
    if (_busy) return;
    final source = await pickPhotoSource(context);
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 82,
      );
      if (shot == null) return;
      fit.setProfileBanner(await File(shot.path).readAsBytes());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _snapshot() async {
    if (_busy) return;
    final source = await pickPhotoSource(context);
    if (source == null) return;
    setState(() => _busy = true);
    try {
      if (source == ImageSource.gallery) {
        final shots = await ImagePicker().pickMultiImage(maxWidth: 1440, maxHeight: 1920, imageQuality: 88);
        for (final shot in shots) {
          await fit.addMoment(shot.path);
        }
        return;
      }
      final shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (shot == null) return;
      await fit.addMoment(shot.path);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final top = MediaQuery.paddingOf(context).top;
    final s = hunter.status;
    final showRpg = fit.gamification;
    final scroll = RiseScope(
      id: 'profile',
      child: CustomScrollView(
        controller: _scroll,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileHeader(
              gc: gc,
              top: top,
              pull: _pull,
              reach: _reach,
              onBanner: _pickBanner,
              onEdit: () => showProfileSheet(context),
              rankLetter: showRpg ? s.rank.letter : null,
              levelLabel: showRpg ? t.levelShort(s.level) : null,
              frame: showRpg ? s.frame : 'basic',
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Rise(index: 0, child: _stats(gc, showRpg)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (fit.gamification) ...[
                        Rise(
                          index: 1,
                          child: _panel(
                            gc,
                            title: t.awardsTitle,
                            count: '${fit.awardCount}/${AwardId.values.length}',
                            onMore: fit.goAwards,
                            accent: context.sx.gold,
                            child: const MedalShelf(size: 54),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Rise(
                        index: 2,
                        child: _panel(
                          gc,
                          title: t.historyTitle,
                          count: fit.sessions.isEmpty ? null : '${fit.sessions.length}',
                          onMore: fit.sessions.isEmpty ? null : fit.goHistory,
                          accent: context.sx.holo,
                          child: _year(gc),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Rise(
                        index: 3,
                        child: _panel(
                          gc,
                          title: t.snapshots,
                          count: fit.momentCount > 0 ? '${fit.momentCount}' : null,
                          onMore: fit.momentCount > 0 ? fit.goMoments : null,
                          accent: context.sx.violet,
                          child: _photos(gc),
                        ),
                      ),
                      if (fit.passOn) ...[
                        const SizedBox(height: 18),
                        Rise(
                          index: 4,
                          child: _panel(
                            gc,
                            title: t.gymPass,
                            count: fit.gymPasses.length > 1 ? '${fit.gymPasses.length}' : null,
                            onMore: fit.goGymPasses,
                            accent: context.sx.holo,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: fit.lastPass == null
                                  ? GymPassEmpty(onTap: () => addGymPass(context))
                                  : GymPassCarousel(key: ValueKey(fit.gymPasses.length)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Listener(
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedBuilder(
        animation: _pull,
        child: scroll,
        builder: (context, child) {
          final pull = _pull.value;
          final p = (pull / _reach).clamp(0.0, 1.0);
          final size = MediaQuery.sizeOf(context);
          return Stack(
            children: [
              Positioned.fill(
                child: p <= 0
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        child: Opacity(
                          opacity: Curves.easeIn.transform(((p - 0.15) / 0.85).clamp(0.0, 1.0)),
                          child: Transform.scale(
                            scale: 1.3 - 0.3 * Curves.easeOutCubic.transform(p),
                            child: NameTicker(
                              text: fit.displayName,
                              color: gc.text.withValues(alpha: 0.07),
                              rows: 0,
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, pull * 0.55),
                  child: Opacity(opacity: (1 - p).clamp(0.0, 1.0), child: child),
                ),
              ),
              if (p > 0) _traveller(gc, size, top, pull, p),
            ],
          );
        },
      ),
    );
  }

  Widget _traveller(GymColors gc, Size size, double top, double pull, double p) {
    final big = 86 + (kRecapAvatar - 86) * Curves.easeInOutSine.transform(p);
    final center = Offset(size.width / 2, recapAvatarY(size));
    final ring = math.min(size.width / 2 - kRecapAvatar / 2 - 14, 120.0);
    const startAngle = math.pi * 0.82;
    final entry = center + Offset(math.cos(startAngle), math.sin(startAngle)) * ring;
    final start = Offset(67, top + 145 + pull * 0.55);
    const split = 0.3;
    final Offset spot;
    if (p < split) {
      spot = Offset.lerp(start, entry, Curves.easeIn.transform(p / split))!;
    } else {
      final v = (p - split) / (1 - split);
      final angle = startAngle - 1.05 * math.pi * Curves.easeInOutSine.transform(v);
      final shrink = Curves.easeInCubic.transform(((v - 0.35) / 0.65).clamp(0.0, 1.0));
      spot = center + Offset(math.cos(angle), math.sin(angle)) * ring * (1 - shrink);
    }
    final at = spot - Offset(big / 2, big / 2);
    final armed = pull >= _reach;
    final pop = armed ? 1.06 : 1.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (armed)
              Positioned(
                left: center.dx - (kRecapAvatar + 200) / 2,
                top: center.dy - (kRecapAvatar + 200) / 2,
                child: StoryRings(key: ValueKey(_burst), size: kRecapAvatar, color: Colors.white),
              ),
            Positioned(
              left: at.dx,
              top: at.dy,
              child: AnimatedScale(
                scale: pop,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: ProfileAvatar(size: big),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: center.dy + kRecapAvatar / 2 + 34,
              child: Opacity(
                opacity: ((p - 0.55) / 0.45).clamp(0.0, 1.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    armed ? t.recapRelease : t.recapPull(t.monthInline(fit.recapMonth.month)),
                    key: ValueKey(armed),
                    textAlign: TextAlign.center,
                    style: AppTheme.f(15, weight: FontWeight.w800, color: armed ? gc.text : gc.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _year(GymColors gc) {
    final months = fit.sessionsByMonth;
    final peak = months.fold(1, math.max);
    final thisMonth = DateTime.now().month;
    final best = fit.bestMonthThisYear;
    final lifted = fit.liftedSpanOf(fit.volumeThisYearKg);

    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _yearStat(gc, '${fit.sessionsThisYear}', '', t.statWorkouts)),
              Expanded(child: _yearStat(gc, lifted.$1, lifted.$2, t.statLifted)),
              Expanded(child: _yearStat(gc, '${fit.monthsTrainedThisYear}', '/12', t.yearMonths)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 58,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var m = 1; m <= 12; m++) ...[
                  if (m > 1) const SizedBox(width: 5),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: months[m - 1] > 0
                          ? () => fit.goHistory(month: DateTime(DateTime.now().year, m))
                          : null,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: months[m - 1] / peak),
                        duration: Duration(milliseconds: 650 + m * 35),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Container(
                          height: 6 + 52 * v,
                          decoration: BoxDecoration(
                            color: m == thisMonth
                                ? gc.ember
                                : (months[m - 1] > 0 ? gc.textTertiary : gc.bgRaised2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var m = 1; m <= 12; m++) ...[
                if (m > 1) const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    t.monthInitial(m),
                    textAlign: TextAlign.center,
                    style: AppTheme.f(
                      9.5,
                      weight: FontWeight.w600,
                      color: m == thisMonth ? gc.text : gc.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (best > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${t.yearBestMonth} · ',
                          style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textTertiary),
                        ),
                        TextSpan(
                          text: t.monthName(best),
                          style: AppTheme.f(12, weight: FontWeight.w700, color: gc.textSecondary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _yearStat(GymColors gc, String value, String unit, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Ltr(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RollIn(
                  value,
                  style: AppTheme.f(26, weight: FontWeight.w800, color: gc.text),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.f(9.5, weight: FontWeight.w600, color: gc.textTertiary, letterSpacing: 0.9),
        ),
      ],
    );
  }

  Widget _stats(GymColors gc, bool showRpg) {
    final sx = context.sx;
    final s = hunter.status;
    final tiles = <Widget>[
      HunterStatTile(
        label: t.statWorkouts,
        value: '${fit.totalSessions}',
        icon: PhosphorIconsRegular.barbell,
        color: sx.mana,
      ),
      HunterStatTile(
        label: t.statTrained,
        value: '${fit.trainedSpan.$1} ${fit.trainedSpan.$2}',
        icon: PhosphorIconsRegular.timer,
        color: sx.holo,
      ),
      HunterStatTile(
        label: t.statLifted,
        value: '${fit.liftedSpan.$1} ${fit.liftedSpan.$2}',
        icon: PhosphorIconsRegular.trendUp,
        color: sx.gold,
      ),
      if (showRpg)
        HunterStatTile(
          label: t.statStreak,
          value: '${s.streak}d',
          icon: PhosphorIconsRegular.fire,
          color: sx.vital,
        )
      else
        HunterStatTile(
          label: 'This year',
          value: '${fit.sessionsThisYear}',
          icon: PhosphorIconsRegular.calendarCheck,
          color: sx.vital,
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gc.border.withValues(alpha: 0.8)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(sx.mana.withValues(alpha: 0.055), gc.bgRaised), gc.bgRaised],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TRAINING STATS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(10, weight: FontWeight.w800, color: gc.textTertiary, letterSpacing: 1.4),
                ),
              ),
              if (showRpg) ...[
                const SizedBox(width: 8),
                StatusChip(
                  label: '${s.rank.letter}-Rank',
                  color: sx.rank(s.rank.letter),
                  icon: PhosphorIconsRegular.shieldCheck,
                  dense: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
              );
            },
          ),
          if (showRpg) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Text(
                  t.levelShort(s.level),
                  style: AppTheme.f(11.5, weight: FontWeight.w800, color: sx.mana),
                ),
                const Spacer(),
                Text(
                  '${s.into}/${s.need} XP',
                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SystemBar(
              value: s.levelRatio,
              height: 4,
              color: sx.violet,
              semanticsLabel: 'Hunter level progress',
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(
    GymColors gc, {
    required String title,
    String? count,
    VoidCallback? onMore,
    Color? accent,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: gc.bgRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gc.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
            child: Row(
              children: [
                if (accent != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(14.5, weight: FontWeight.w800, color: gc.text),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 7),
                  Text(
                    count,
                    style: AppTheme.f(11.5, weight: FontWeight.w800, color: gc.textTertiary),
                  ),
                ],
                const Spacer(),
                if (onMore != null) _seeAll(gc, onMore),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 10), child: child),
        ],
      ),
    );
  }

  Widget _seeAll(GymColors gc, VoidCallback onTap) => Semantics(
    button: true,
    label: t.healthSeeAll,
    excludeSemantics: true,
    child: Pressable(
      onTap: onTap,
      scale: 0.94,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: gc.bgRaised2, borderRadius: BorderRadius.circular(15)),
            child: Text(
              t.healthSeeAll,
              style: AppTheme.f(11.5, weight: FontWeight.w700, color: gc.text),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _photos(GymColors gc) {
    final shots = fit.momentsNewest.take(6).map((m) => m.file).toList();
    if (shots.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: gc.bgRaised2.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gc.border.withValues(alpha: 0.65)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.sx.violet.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIconsRegular.camera, size: 18, color: context.sx.violet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No photos yet',
                    style: AppTheme.f(13.5, weight: FontWeight.w800, color: gc.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Progress photos stay private on this device.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: _snapshot,
              scale: 0.95,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: gc.text, borderRadius: BorderRadius.circular(18)),
                child: Text(
                  t.addPhoto,
                  style: AppTheme.f(11.5, weight: FontWeight.w800, color: gc.bg),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: shots.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => i == shots.length ? _addPhotoTile(gc) : _photoTile(gc, shots[i]),
      ),
    );
  }

  Widget _photoTile(GymColors gc, String file) => Semantics(
    button: true,
    label: t.photosCard,
    child: Pressable(
      onTap: fit.goMoments,
      scale: 0.96,
      child: Container(
        width: 70,
        height: 88,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: gc.bgRaised2,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: gc.border.withValues(alpha: 0.7)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: FileThumb(
            MediaStore.pathFor(file) ?? '',
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => ColoredBox(color: gc.bgRaised2),
          ),
        ),
      ),
    ),
  );

  Widget _addPhotoTile(GymColors gc) => Semantics(
    button: true,
    label: t.addPhoto,
    child: Pressable(
      onTap: _snapshot,
      scale: 0.96,
      child: Container(
        width: 70,
        height: 88,
        decoration: BoxDecoration(
          color: gc.bgRaised2.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: gc.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.plus, size: 16, color: gc.textSecondary),
            const SizedBox(height: 4),
            Text(
              t.addPhoto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.f(9, weight: FontWeight.w700, color: gc.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GrabberPainter extends CustomPainter {
  const _GrabberPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final half = 16 - 4 * t;
    final lift = 5 * t;
    final path = Path()
      ..moveTo(size.width / 2 - half, mid - lift)
      ..lineTo(size.width / 2, mid + lift)
      ..lineTo(size.width / 2 + half, mid - lift);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.22 + 0.4 * t),
    );
  }

  @override
  bool shouldRepaint(_GrabberPainter old) => old.t != t || old.color != color;
}

class _ProfileHeader extends SliverPersistentHeaderDelegate {
  _ProfileHeader({
    required this.gc,
    required this.top,
    required this.pull,
    required this.reach,
    required this.onBanner,
    required this.onEdit,
    required this.rankLetter,
    required this.levelLabel,
    required this.frame,
  });

  final GymColors gc;
  final double top;
  final ValueNotifier<double> pull;
  final double reach;
  final VoidCallback onBanner;
  final VoidCallback onEdit;

  /// Null when the Hunter System is switched off or the player is unregistered.
  final String? rankLetter;
  final String? levelLabel;
  final String frame;

  static const _bar = 60.0;
  static const _cover = 150.0;
  static const _avatar = 84.0;
  static const _ring = _avatar + 10;
  static const _card = 108.0;

  @override
  double get maxExtent => top + _cover + 82;

  @override
  double get minExtent => top + _bar;

  @override
  bool shouldRebuild(_ProfileHeader old) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final shrunk = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final bytes = fit.profileBanner;
    final p = fit.profile;
    final coverBottom = math.max(minExtent, top + _cover - shrinkOffset);
    final cardTop = coverBottom - 26;
    final avatarTop = coverBottom - 52;
    final fade = (1 - shrunk * 2.5).clamp(0.0, 1.0);
    final bar = ((shrunk - 0.72) / 0.28).clamp(0.0, 1.0);
    final sx = context.sx;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: coverBottom,
          child: ValueListenableBuilder<double>(
            valueListenable: pull,
            builder: (_, v, child) {
              final drag = (v / reach).clamp(0.0, 1.0);
              if (drag <= 0) return child!;
              final sigma = 14 * drag;
              final zoomed = Transform.scale(
                scale: 1 + 0.35 * drag,
                alignment: Alignment.topCenter,
                child: child,
              );
              return Opacity(
                opacity: (1 - drag).clamp(0.0, 1.0),
                child: blurEffects
                    ? ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                        child: zoomed,
                      )
                    : zoomed,
              );
            },
            child: GestureDetector(
              onTap: onBanner,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: gc.bgRaised,
                      image: DecorationImage(
                        image: bytes == null ? kDefaultBanner : MemoryImage(bytes),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.46),
                            Colors.black.withValues(alpha: 0.04),
                            gc.bg.withValues(alpha: 0.58),
                            gc.bg,
                          ],
                          stops: const [0, 0.3, 0.78, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            sx.mana.withValues(alpha: 0),
                            sx.mana.withValues(alpha: 0.55),
                            sx.gold.withValues(alpha: 0.35),
                            sx.mana.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: top + 12,
          child: IgnorePointer(
            child: Opacity(
              opacity: fade * 0.9,
              child: Text(
                'HUNTER PROFILE',
                style: AppTheme.f(9.5, weight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.8)
                    .copyWith(
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1))],
                    ),
              ),
            ),
          ),
        ),
        Positioned(
          top: top + 7,
          right: 14,
          child: _round(PhosphorIconsRegular.gearSix, fit.goPreferences, 'Settings'),
        ),
        Positioned(
          right: 16,
          top: math.max(top + 52, coverBottom - 52),
          child: IgnorePointer(
            ignoring: fade < 0.2,
            child: Opacity(opacity: fade, child: _coverAction(PhosphorIconsRegular.camera)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: cardTop,
          height: _card,
          child: IgnorePointer(
            ignoring: fade < 0.1,
            child: Opacity(
              opacity: fade,
              child: Container(
                decoration: BoxDecoration(
                  color: gc.bgRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gc.border.withValues(alpha: 0.85)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 14 + _ring + 10,
                      right: 50,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.25,
                          child: _identity(context, p),
                        ),
                      ),
                    ),
                    Positioned(right: 12, top: 12, child: _editButton()),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: avatarTop,
          child: ValueListenableBuilder<double>(
            valueListenable: pull,
            builder: (_, v, child) => Opacity(opacity: v > 0 ? 0 : fade, child: child),
            child: _avatarRing(context),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: cardTop - 9,
          child: IgnorePointer(
            child: Opacity(
              opacity: fade,
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: pull,
                  builder: (_, v, _) => CustomPaint(
                    size: const Size(44, 18),
                    painter: _GrabberPainter(
                      Curves.easeOutCubic.transform((v / 64).clamp(0.0, 1.0)),
                      gc.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (bar > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: bar,
                child: EdgeBlur(height: top + 64, sigma: 14),
              ),
            ),
          ),
        Positioned(
          left: 62,
          right: 62,
          top: top + 9,
          height: 38,
          child: IgnorePointer(
            child: Opacity(
              opacity: bar,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - bar)),
                child: Center(child: _compact(context, p)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarRing(BuildContext context) {
    final sx = context.sx;
    final ring = rankLetter == null ? sx.muted : frameColor(frame, sx);
    return Container(
      width: _ring,
      height: _ring,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [ring, sx.mana, ring.withValues(alpha: 0.35), ring]),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(shape: BoxShape.circle, color: gc.bg),
        child: const ProfileAvatar(size: _avatar),
      ),
    );
  }

  Widget _identity(BuildContext context, Profile p) {
    final sx = context.sx;
    final rank = rankLetter;
    final level = levelLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(20.5, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.35),
              ),
            ),
            if (p.badge.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(PhosphorIconsFill.sealCheck, size: 16, color: badgeColor(p.badge)),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          '@${fit.profileHandle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary),
        ),
        if (rank != null && level != null) ...[
          const SizedBox(height: 7),
          Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: sx.rank(rank).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: sx.rank(rank).withValues(alpha: 0.32)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsRegular.shieldCheck, size: 10.5, color: sx.rank(rank)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$rank-Rank · $level',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(10.2, weight: FontWeight.w800, color: sx.rank(rank)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, String label) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _coverAction(IconData icon) {
    return Semantics(
      button: true,
      label: 'Change cover image',
      excludeSemantics: true,
      child: Pressable(
        onTap: onBanner,
        scale: 0.92,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _editButton() {
    return Semantics(
      button: true,
      label: t.editProfile,
      excludeSemantics: true,
      child: Pressable(
        onTap: onEdit,
        scale: 0.92,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: gc.bgRaised2,
            shape: BoxShape.circle,
            border: Border.all(color: gc.border),
          ),
          child: Icon(PhosphorIconsRegular.pencilSimple, size: 15, color: gc.textSecondary),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, Profile p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileAvatar(size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fit.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(15.5, weight: FontWeight.w800, color: gc.text, letterSpacing: -0.2),
          ),
        ),
        if (rankLetter != null) ...[
          const SizedBox(width: 6),
          Text(
            '$rankLetter',
            style: AppTheme.f(10.5, weight: FontWeight.w900, color: context.sx.rank(rankLetter!)),
          ),
        ],
        if (p.badge.isNotEmpty) ...[
          const SizedBox(width: 4),
          Icon(PhosphorIconsFill.sealCheck, size: 13, color: badgeColor(p.badge)),
        ],
      ],
    );
  }
}
