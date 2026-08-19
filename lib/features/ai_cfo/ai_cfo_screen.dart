import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

/// 원 단위 축약 (억/만).
String _won(num n) {
  final a = n.abs();
  if (a >= 1e8) return '${(n / 1e8).toStringAsFixed(1)}억';
  if (a >= 1e4) return '${(n / 1e4).round()}만';
  return '${n.round()}';
}

class AiCfoScreen extends ConsumerStatefulWidget {
  const AiCfoScreen({super.key});

  @override
  ConsumerState<AiCfoScreen> createState() => _AiCfoScreenState();
}

class _AiCfoScreenState extends ConsumerState<AiCfoScreen> {
  bool _analyzing = false;

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      final sb = ref.read(supabaseProvider);
      final uid = sb.auth.currentUser!.id;

      // ── 데이터 수집 (로드맵/거래장부 기반, 앱에서 직접 계산) ──
      final metrics = await ref.read(dashboardMetricsProvider.future);
      final flows = await ref.read(monthlyCashflowProvider.future);
      final shorts = await ref.read(shortsProvider.future);
      final land = await ref.read(landProvider.future);
      final phases = await ref.read(planPhasesProvider.future);
      final allocs = await ref.read(planAllocationsProvider.future);
      final conds = await ref.read(planConditionsProvider.future);
      final entries = await ref.read(flowEntriesProvider.future);
      final cfThisMonth = await ref.read(nonSalaryCashflowThisMonthProvider.future);

      final cashflow = metrics.nonSalaryCashflow;
      final freedomTarget = metrics.freedomTarget;
      final freedom = metrics.freedomScore;
      final now = DateTime.now();

      // 월간 성장률(MoM).
      final withData = flows.where((f) => f.nonSalary > 0).toList();
      double mom = 0;
      if (withData.length >= 2) {
        final last = withData[withData.length - 1].nonSalary;
        final prev = withData[withData.length - 2].nonSalary;
        if (prev > 0) mom = (last - prev) / prev * 100;
      }

      // 최종 목표까지 남은 개월.
      int etaMonths = 24;
      if (cashflow >= freedomTarget) {
        etaMonths = 0;
      } else if (mom > 0.5 && cashflow > 0) {
        etaMonths = (math.log(freedomTarget / cashflow) / math.log(1 + mom / 100)).ceil();
      }
      etaMonths = etaMonths.clamp(0, 120);
      final eta = DateTime(now.year, now.month + etaMonths, 1);

      // ── 현재 단계(로드맵) ──
      final current = phases.isEmpty
          ? null
          : phases.firstWhere((p) => p.isCurrent, orElse: () => phases.first);
      final curAllocs =
          current == null ? <PlanAllocation>[] : allocs.where((a) => a.phaseNo == current.phaseNo).toList();
      final curConds =
          current == null ? <PlanCondition>[] : conds.where((c) => c.phaseNo == current.phaseNo).toList();

      // 카테고리 ↔ 거래 라벨 키워드 매칭 + 누적/이번달 집계.
      bool match(String cat, String label) {
        final l = label.toLowerCase();
        for (final t in cat.split(RegExp(r'[\s/·]+'))) {
          if (t.length >= 2 && l.contains(t.toLowerCase())) return true;
        }
        return false;
      }
      double allTime(String cat) {
        double s = 0;
        for (final e in entries) {
          if (!e.isIn && match(cat, e.label)) s += e.amount;
        }
        return s;
      }
      double thisMonth(String cat) {
        double s = 0;
        for (final e in entries) {
          if (!e.isIn && e.date.year == now.year && e.date.month == now.month && match(cat, e.label)) {
            s += e.amount;
          }
        }
        return s;
      }

      // ── 에비 자금(누적 목표) → 오픈 시점 ──
      final eviAllocs = curAllocs
          .where((a) => a.kind == 'target' && (a.amount ?? 0) > 0 && a.category.contains('에비'))
          .toList();
      String airbnbOpenEta;
      String airbnbReco;
      if (eviAllocs.isNotEmpty) {
        final a = eviAllocs.first;
        final target = a.amount!;
        final acc = allTime(a.category);
        final m = thisMonth(a.category);
        final pct = (acc / target * 100).clamp(0, 100);
        final remain = math.max(0.0, target - acc);
        if (remain <= 0) {
          airbnbOpenEta = '${a.category} ${_won(acc)}/${_won(target)}원 (100%) — 목표 달성, 오픈 준비 완료';
        } else if (m > 0) {
          final months = (remain / m).ceil();
          final d = DateTime(now.year, now.month + months, 1);
          airbnbOpenEta =
              '${a.category} ${_won(acc)}/${_won(target)}원 (${pct.toStringAsFixed(0)}%) · 월 ${_won(m)}원 적립 시 약 $months개월 뒤(${d.toIso8601String().substring(0, 7)})';
        } else {
          airbnbOpenEta =
              '${a.category} ${_won(acc)}/${_won(target)}원 (${pct.toStringAsFixed(0)}%) · 이번 달 적립 없음 — 적립 시작 시 오픈 시점 계산';
        }
        airbnbReco = remain > 0
            ? '${a.category} 잔여 ${_won(remain)}원 우선 충당 (에비 오픈이 현금흐름을 가장 크게 늘림)'
            : '${a.category} 달성 — 다음 호점 준비 검토';
      } else {
        airbnbOpenEta = current == null
            ? '로드맵(Goals)에서 단계를 설정하세요'
            : '현재 단계(${current.title})에 에비 자금 목표가 없습니다 — 로드맵에서 추가';
        airbnbReco = '로드맵에서 에비 자금 목표(누적)를 설정하면 오픈 시점을 계산합니다';
      }

      // ── 다음 현금흐름 목표(현재 단계 조건) ──
      final cfConds = curConds
          .where((c) => c.kind == 'cashflow' && (c.targetValue ?? 0) > 0)
          .toList()
        ..sort((x, y) => x.targetValue!.compareTo(y.targetValue!));
      String nextGoal;
      if (cfConds.isNotEmpty) {
        final t = cfConds.first.targetValue!;
        final pct = (cfThisMonth / t * 100).clamp(0, 100);
        nextGoal = '이번 달 현금흐름 ${_won(cfThisMonth)}/${_won(t)}원 (${pct.toStringAsFixed(0)}%)';
      } else {
        nextGoal = '이번 달 현금흐름 ${_won(cfThisMonth)}원';
      }
      final doneCnt = curConds
          .where((c) =>
              c.done ||
              (c.kind == 'cashflow' && (c.targetValue ?? 0) > 0 && cfThisMonth >= c.targetValue!))
          .length;

      // ── 토지(현재 단계 배분 note 기반) ──
      final landAllocs = curAllocs.where((a) => a.category.contains('토지')).toList();
      final landHold = landAllocs.isNotEmpty && (landAllocs.first.note?.contains('보류') ?? false);
      final landOk = !landHold;
      final landReason = landAllocs.isNotEmpty
          ? '현재 단계 방침: ${landAllocs.first.note ?? (landOk ? '토지 진입 가능' : '토지 보류')}'
          : (landOk ? '토지 신규 진입 검토 가능' : '토지 보류');

      final shortsProfit = shorts.fold(0.0, (s, c) => s + c.netProfit);
      final wan = shortsProfit / 10000;
      final shortsAllocation = wan < 50
          ? '월 50만 미만 — 콘텐츠 재투자 100%'
          : wan < 150
              ? '월 50~150만 — 에어비앤비 40% · 콘텐츠 40% · ETF 10% · 현금 10%'
              : '월 150만 이상 — 에어비앤비 35% · 콘텐츠 20% · ETF 25% · 토지 10% · 현금 10%';

      final phaseLabel = current == null ? '로드맵 미설정' : 'Phase ${current.phaseNo} · ${current.title}';

      final payload = {
        'current_pace':
            '월 현금흐름 ${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(1)}% MoM · 자유지수 ${freedom.toStringAsFixed(0)}%',
        'goal_eta': eta.toIso8601String().substring(0, 10),
        'goal_eta_reason':
            '현재 월 ${_won(cashflow)}원, 최종 목표 ${_won(freedomTarget)}원. 현 성장 속도 유지 시 약 $etaMonths개월 뒤.',
        'next_priority':
            '$phaseLabel · $nextGoal · 단계 조건 ${curConds.length}개 중 $doneCnt개 달성',
        'airbnb_reco': airbnbReco,
        'airbnb_open_eta': airbnbOpenEta,
        'land_ok': landOk,
        'land_reason': landReason,
        'land_principle': '원금은 토지에 재투자, 수익금만 에비·ETF 현금흐름 자산으로 이동',
        'etf_rebalance': freedom < 100
            ? '배당 성장주(SCHD) 비중 상향으로 현금흐름 가속'
            : '현 비중 유지, 성장/배당 균형',
        'shorts_reinvest': shortsAllocation,
        'land_count': land.length,
      };
      final summary = current == null
          ? '자유지수 ${freedom.toStringAsFixed(0)}% · 최종 목표까지 약 $etaMonths개월'
          : 'Phase ${current.phaseNo} ${current.title} · 자유지수 ${freedom.toStringAsFixed(0)}% · $nextGoal';

      final today = DateTime.now().toIso8601String().substring(0, 10);
      await sb.from('ai_reports').upsert({
        'user_id': uid,
        'report_date': today,
        'summary': summary,
        'payload': payload,
      }, onConflict: 'user_id,report_date');
      ref.invalidate(aiReportsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('재분석을 실행하지 못했습니다: $e'),
            backgroundColor: AppColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiReportsProvider);
    final analyzing = _analyzing;

    return ModulePage(
      title: 'AI CFO',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.violet,
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
        ),
        onPressed: analyzing ? null : _analyze,
        icon: analyzing
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('재분석'),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (reports) {
            if (reports.isEmpty) {
              return const EmptyState(
                  icon: Icons.auto_awesome, message: '아직 분석 리포트가 없습니다');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LatestReport(report: reports.first),
                if (reports.length > 1) ...[
                  const Gap(24),
                  const SectionHeader('지난 리포트'),
                  const Gap(12),
                  for (final r in reports.skip(1).take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded,
                                size: 16, color: AppColors.textFaint),
                            const Gap(10),
                            Expanded(
                              child: Text(r.summary ?? '리포트',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(Dates.ymd(r.reportDate),
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LatestReport extends StatelessWidget {
  final AiReport report;
  const _LatestReport({required this.report});

  @override
  Widget build(BuildContext context) {
    final p = report.payload;
    final items = <_Insight>[
      _Insight(Icons.flag_circle_rounded, '지금 먼저 투자할 곳',
          p['next_priority']?.toString()),
      _Insight(Icons.speed_rounded, '현재 속도', p['current_pace']?.toString()),
      _Insight(
          Icons.event_available_rounded,
          '목표 달성 예상',
          p['goal_eta'] != null
              ? '${Dates.ymd(DateTime.parse(p['goal_eta']))}  ·  ${p['goal_eta_reason'] ?? ''}'
              : null),
      _Insight(Icons.meeting_room_rounded, '에비 오픈 시점',
          p['airbnb_open_eta']?.toString()),
      _Insight(Icons.house_rounded, '에비 투자 추천', p['airbnb_reco']?.toString()),
      _Insight(
          Icons.terrain_rounded,
          '토지 투자',
          p.containsKey('land_ok')
              ? (p['land_ok'] == true
                  ? '가능 — ${p['land_reason'] ?? ''}'
                  : '보류 — ${p['land_reason'] ?? ''}')
              : null),
      _Insight(Icons.pie_chart_rounded, 'ETF 비중 조정', p['etf_rebalance']?.toString()),
      _Insight(Icons.play_circle_fill_rounded, '숏폼 수익 배분', p['shorts_reinvest']?.toString()),
      _Insight(Icons.recycling_rounded, '토지 원칙', p['land_principle']?.toString()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Insets.radius),
            gradient: const LinearGradient(
              colors: [Color(0xFF241B3D), Color(0xFF16213A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.violet, size: 18),
                  const Gap(8),
                  Text('${Dates.ymd(report.reportDate)} 분석',
                      style: const TextStyle(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ],
              ),
              const Gap(12),
              Text(report.summary ?? '',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.45)),
            ],
          ),
        ),
        const Gap(16),
        for (final i in items)
          if (i.value != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(i.icon, size: 18, color: AppColors.violet),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.label,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        const Gap(4),
                        Text(i.value!,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(10),
          ],
      ],
    );
  }
}

class _Insight {
  final IconData icon;
  final String label;
  final String? value;
  _Insight(this.icon, this.label, this.value);
}
