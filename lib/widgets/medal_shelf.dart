import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../catalog/awards.dart';
import '../catalog/medal_look.dart';
import '../l10n/l10n.dart';
import '../state/fit_state.dart';
import '../system/system_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'medal.dart';
import 'ui_kit.dart';

class MedalShelf extends StatelessWidget {
  const MedalShelf({super.key, this.size = 54, this.max = 6});

  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final order = fit.profileMedals;

    if (fit.awardCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Medal(id: AwardId.firstStep, size: size, locked: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No medals yet',
                    style: AppTheme.f(13.5, weight: FontWeight.w800, color: gc.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Complete your first workout to start your trophy case.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final shown = order.take(max).toList();
    final item = size + 10;
    return SizedBox(
      height: size + 44,
      child: LayoutBuilder(
        builder: (context, box) {
          final needed = shown.length * item + (shown.length - 1) * 8;
          if (needed <= box.maxWidth) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final id in shown) _slot(context, id)],
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _slot(context, shown[i]),
          );
        },
      ),
    );
  }

  Widget _slot(BuildContext context, AwardId id) {
    final gc = context.gc;
    final sx = context.sx;
    final won = fit.hasAward(id);
    final fresh = fit.unseenAwards.contains(id);
    final rarity = medalRarity(id);
    final rarityTone = _rarityTone(rarity, sx);
    return Semantics(
      button: true,
      label: '${awardName(id)}. ${won ? 'Unlocked' : 'Locked'}. $rarity rarity.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showMedalSheet(context, id),
        child: SizedBox(
          width: size + 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Medal(id: id, size: size, locked: !won),
                    if (!won)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: gc.bgRaised,
                            shape: BoxShape.circle,
                            border: Border.all(color: gc.border),
                          ),
                          child: Icon(PhosphorIconsRegular.lockSimple, size: 9, color: gc.textTertiary),
                        ),
                      ),
                    if (fresh)
                      Positioned(
                        right: 1,
                        top: 1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: gc.accent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 24,
                child: Text(
                  awardName(id),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(
                    8.8,
                    weight: FontWeight.w700,
                    color: won ? gc.textSecondary : gc.textTertiary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: rarityTone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rarity,
                    maxLines: 1,
                    style: AppTheme.f(7.6, weight: FontWeight.w700, color: rarityTone, letterSpacing: 0.2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rarityTone(String rarity, HunterPalette sx) => switch (rarity) {
    'Bronze' => Color.lerp(sx.gold, sx.mana, 0.55)!,
    'Silver' => sx.muted,
    'Gold' => sx.gold,
    'Diamond' => sx.holo,
    _ => sx.muted,
  };
}

Future<void> showMedalSheet(BuildContext context, AwardId id) {
  fit.markAwardsSeen();
  return showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MedalSheet(id: id),
  );
}

class _MedalSheet extends StatelessWidget {
  const _MedalSheet({required this.id});

  final AwardId id;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final won = fit.hasAward(id);
    final at = fit.awardWonAt(id);

    return Container(
      padding: sheetPad(context),
      decoration: sheetDecoration(gc),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(margin: EdgeInsets.only(bottom: 22)),
          MedalSpin(id: id, size: 236, locked: !won),
          const SizedBox(height: 8),
          Text(
            t.awardSpinHint,
            style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textTertiary),
          ),
          const SizedBox(height: 22),
          Text(
            awardName(id),
            textAlign: TextAlign.center,
            style: AppTheme.f(21, color: gc.text),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              awardLine(id),
              textAlign: TextAlign.center,
              style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 18),
          if (won && at != null)
            Text(
              t.awardWonOn(t.shortDateYear(at)),
              style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textTertiary),
            )
          else
            _progress(gc),
        ],
      ),
    );
  }

  Widget _progress(GymColors gc) {
    final value = fit.awardValue(id);
    final goal = fit.awardGoal(id);
    return Column(
      children: [
        SizedBox(
          width: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: fit.awardProgress(id),
              minHeight: 5,
              backgroundColor: gc.bgRaised2,
              valueColor: AlwaysStoppedAnimation<Color>(gc.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${medalShort(value)} / ${medalShort(goal)}',
          style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textTertiary),
        ),
      ],
    );
  }
}

String medalShort(int v) =>
    v >= 1000 ? '${decimalText((v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1))}k' : '$v';
