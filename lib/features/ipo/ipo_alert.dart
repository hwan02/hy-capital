// 공모주 «오늘» 알림.
//
// 청약은 마감일을 넘기면 끝이다. 목록을 열어봐야 아는 구조로는 놓친다.
// 그래서 대시보드 맨 위와 공모주 화면 맨 위에 «오늘 할 일»만 띄운다.
//
// 오늘 아무 일도 없으면 아무것도 그리지 않는다 — 빈 배너로 자리를 먹지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

/// 알림 한 줄. 급한 순서대로 만든다.
class IpoAlert {
  final String head; // 오늘 마감
  final String body; // 종목 · 밴드 · 주관사
  final Color color;
  final IconData icon;
  final int rank; // 낮을수록 급하다

  const IpoAlert({
    required this.head,
    required this.body,
    required this.color,
    required this.icon,
    required this.rank,
  });
}

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);
bool _is(DateTime? a, DateTime b) => a != null && _d(a) == b;

String _line(IpoSubscription e) {
  final bits = <String>[e.name];
  if ((e.broker ?? '').isNotEmpty) bits.add(e.broker!);
  if (e.bandLabel.isNotEmpty) bits.add(e.bandLabel);
  return bits.join(' · ');
}

/// 오늘·내일 기준 공모주 알림. 없으면 빈 목록.
final ipoAlertsProvider = FutureProvider<List<IpoAlert>>((ref) async {
  final list = await ref.watch(ipoProvider.future);
  final today = _d(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final out = <IpoAlert>[];

  for (final e in list) {
    // 1) 오늘 마감 — 가장 급하다. 놓치면 끝.
    if (_is(e.subEnd, today)) {
      out.add(IpoAlert(
        head: '오늘 청약 마감',
        body: _line(e),
        color: AppColors.rose,
        icon: Icons.priority_high_rounded,
        rank: 0,
      ));
    } else if (_is(e.subStart, today)) {
      // 2) 오늘 시작
      final end = e.subEnd;
      out.add(IpoAlert(
        head: '오늘 청약 시작',
        body: end == null
            ? _line(e)
            : '${_line(e)} · ${end.month}/${end.day} 마감',
        color: AppColors.gold,
        icon: Icons.play_arrow_rounded,
        rank: 1,
      ));
    } else if (e.phase == '청약중') {
      // 3) 청약 기간 중 (오늘 시작·마감은 아님)
      final left = e.daysToSubEnd;
      out.add(IpoAlert(
        head: left == null ? '청약중' : '청약중 · 마감 D-$left',
        body: _line(e),
        color: AppColors.gold,
        icon: Icons.pending_rounded,
        rank: 2,
      ));
    } else if (_is(e.subStart, tomorrow)) {
      // 4) 내일 시작 — 미리 알려준다
      out.add(IpoAlert(
        head: '내일 청약 시작',
        body: _line(e),
        color: AppColors.sky,
        icon: Icons.event_rounded,
        rank: 3,
      ));
    }

    // 상장·환불은 청약과 별개로 같이 뜬다
    if (_is(e.listingDate, today)) {
      out.add(IpoAlert(
        head: e.sold ? '오늘 상장 (매도 기록됨)' : '오늘 상장 · 매도 판단',
        body: _line(e),
        color: AppColors.primary,
        icon: Icons.trending_up_rounded,
        rank: 1,
      ));
    }
    if (_is(e.refundDate, today)) {
      out.add(IpoAlert(
        head: '오늘 환불',
        body: _line(e),
        color: AppColors.textFaint,
        icon: Icons.payments_rounded,
        rank: 4,
      ));
    }
  }

  out.sort((a, b) => a.rank.compareTo(b.rank));
  return out;
});

/// 오늘 공모주 알림 배너. 없으면 아무것도 그리지 않는다.
class IpoTodayBanner extends ConsumerWidget {
  /// 대시보드에서는 눌러서 공모주 화면으로 간다.
  final bool linkToIpo;
  const IpoTodayBanner({super.key, this.linkToIpo = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(ipoAlertsProvider).asData?.value ?? const [];
    if (alerts.isEmpty) return const SizedBox.shrink();

    final top = alerts.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        accent: top.color,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        onTap: linkToIpo ? () => context.go('/ipo') : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: top.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(top.icon, size: 17, color: top.color),
              ),
              const Gap(11),
              Expanded(
                child: Text('공모주 — ${top.head}',
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        color: top.color)),
              ),
              if (alerts.length > 1)
                Text('외 ${alerts.length - 1}건',
                    style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: AppFont.caption)),
              if (linkToIpo) ...[
                const Gap(6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textFaint),
              ],
            ]),
            const Gap(10),
            for (final a in alerts.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                        color: a.color,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const Gap(9),
                  SizedBox(
                    width: 118,
                    child: Text(a.head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w800,
                            color: a.color)),
                  ),
                  Expanded(
                    child: Text(a.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.label,
                            color: AppColors.textPrimary)),
                  ),
                ]),
              ),
            if (alerts.length > 4) ...[
              const Gap(6),
              Text('그 외 ${alerts.length - 4}건',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
            ],
          ],
        ),
      ),
    );
  }
}
