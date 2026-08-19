import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/data/fx_provider.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/edit/field_spec.dart';
import '../../core/edit/record_form.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

class DividendScreen extends ConsumerWidget {
  const DividendScreen({super.key});

  Map<String, dynamic> _toMap(DividendHolding d) => {
        'ticker': d.ticker,
        'market': d.market,
        'symbol': d.symbol,
        'shares': d.shares,
        'purchase_amount': d.purchasePrice,
        'market_value': d.price,
        'annual_yield': d.annualYield,
      };

  /// 실시간 시세·배당 새로고침 — Edge Function(stock-price) 호출 →
  /// 각 종목 현재가·연배당률·이번 달 주당 배당을 갱신.
  Future<void> _refreshPrices(
      BuildContext context, WidgetRef ref, List<DividendHolding> holdings) async {
    final sb = ref.read(supabaseProvider);
    final withSym =
        holdings.where((d) => (d.symbol ?? '').trim().isNotEmpty).toList();
    void snack(String m) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    }

    if (withSym.isEmpty) {
      snack('종목에 티커/코드를 먼저 입력하세요');
      return;
    }
    try {
      final res = await sb.functions.invoke('stock-price',
          body: {'symbols': withSym.map((d) => d.symbol!.trim()).toList()});
      final data = (res.data as Map).cast<String, dynamic>();
      final now = DateTime.now();
      final m0 = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
      final uid = sb.auth.currentUser!.id;
      var updated = 0;
      for (final d in withSym) {
        final info = data[d.symbol!.trim()];
        if (info is! Map) continue;
        final price = (info['price'] as num?)?.toDouble();
        final div = (info['dividend'] as num?)?.toDouble();
        final upd = <String, dynamic>{};
        if (price != null && price > 0) {
          upd['market_value'] = price;
          if (div != null) upd['annual_yield'] = div * 12 / price * 100;
        }
        if (upd.isNotEmpty) {
          await sb.from('dividend_holdings').update(upd).eq('id', d.id);
          updated++;
        }
        if (div != null) {
          await sb.from('monthly_entries').upsert({
            'user_id': uid,
            'category': 'dividend',
            'ref_id': d.id,
            'ref_name': d.ticker,
            'month': m0,
            'amount': div,
          }, onConflict: 'user_id,category,ref_id,month');
        }
      }
      ref.invalidate(dividendProvider);
      ref.invalidate(monthlyEntriesProvider('dividend'));
      ref.invalidate(moduleIncomeThisMonthProvider);
      snack('시세·배당 갱신 완료 ($updated종목)');
    } catch (e) {
      snack('시세 조회 실패 — Edge Function 배포 여부 확인 ($e)');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dividendProvider);
    final rate = ref.watch(usdKrwProvider).asData?.value ?? 1400;
    final entries = ref.watch(monthlyEntriesProvider('dividend')).asData?.value ?? [];
    final now = DateTime.now();

    double actualThisMonthKrw(List<DividendHolding> holdings) {
      var sum = 0.0;
      for (final d in holdings) {
        for (final e in entries) {
          if (e.refId == d.id &&
              e.month.year == now.year &&
              e.month.month == now.month) {
            sum += d.krw(e.amount * d.shares, rate);
          }
        }
      }
      return sum;
    }

    return ModulePage(
      title: '배당금',
      icon: Icons.savings_rounded,
      color: AppColors.primary,
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (holdings) {
            if (holdings.isEmpty) {
              return Column(
                children: [
                  const EmptyState(icon: Icons.savings, message: '보유 종목이 없습니다'),
                  const Gap(8),
                  FilledButton.icon(
                    onPressed: () => editBuiltinRecord(context, ref, dividendSpec),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('종목 추가'),
                  ),
                ],
              );
            }
            // KRW 총액 (미장은 ×환율)
            double sumKrw(double Function(DividendHolding) f) =>
                holdings.fold(0.0, (s, d) => s + d.krw(f(d), rate));
            final value = sumKrw((d) => d.marketValue);
            final monthly = sumKrw((d) => d.monthlyDividend);
            final annual = sumKrw((d) => d.annualDividend);
            final yieldPct = value <= 0 ? 0.0 : annual / value * 100;
            final actual = actualThisMonthKrw(holdings);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('환율 USD ${_comma(rate)}원 · 실시간',
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _refreshPrices(context, ref, holdings),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('시세·배당 새로고침'),
                    ),
                  ],
                ),
                const Gap(8),
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.25,
                  children: [
                    StatTile(label: '평가 자산', value: '${Won.compact(value)}원',
                        icon: Icons.account_balance_rounded, color: AppColors.gold),
                    StatTile(label: '월 배당(추정)', value: '${Won.compact(monthly)}원',
                        icon: Icons.calendar_month_rounded, color: AppColors.primary),
                    StatTile(label: '연 배당(추정)', value: '${Won.compact(annual)}원',
                        icon: Icons.event_repeat_rounded, color: AppColors.sky),
                    StatTile(label: '평균 배당률', value: Pct.of(yieldPct, digits: 1),
                        icon: Icons.percent_rounded, color: AppColors.primary),
                    StatTile(label: '이번 달 배당금', value: '${Won.compact(actual)}원',
                        icon: Icons.paid_rounded, color: AppColors.gold),
                  ],
                ),
                const Gap(20),
                _PortfolioPie(holdings: holdings, rate: rate),
                const Gap(20),
                for (final market in const ['국장', '미장'])
                  _MarketGroup(
                    market: market,
                    rate: rate,
                    holdings: holdings.where((d) => d.market == market).toList(),
                    onAdd: () => editBuiltinRecord(context, ref, dividendSpec,
                        initial: {'market': market}),
                    onEdit: (d) => editBuiltinRecord(context, ref, dividendSpec,
                        initial: _toMap(d), id: d.id),
                    onDelete: (d) => deleteBuiltinRecord(
                        context, ref, dividendSpec, d.id, name: d.ticker),
                  ),
                const Gap(4),
                _DividendMonthly(holdings: holdings, entries: entries, rate: rate),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _comma(double v) {
    final s = v.round().toString();
    return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }
}

// ── 포트폴리오 원형(도넛) ─────────────────────────────────────
class _PortfolioPie extends StatelessWidget {
  final List<DividendHolding> holdings;
  final double rate;
  const _PortfolioPie({required this.holdings, required this.rate});

  static const _palette = [
    AppColors.primary, AppColors.sky, AppColors.gold, AppColors.rose,
    AppColors.violet, Color(0xFFB4844E), Color(0xFF34D399), Color(0xFFFB923C),
    Color(0xFFE879F9), Color(0xFF2DD4BF),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final d in holdings)
        MapEntry(d, d.krw(d.marketValue, rate)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('포트폴리오 구성'),
          const Gap(16),
          LayoutBuilder(builder: (context, c) {
            final chart = SizedBox(
              height: 180,
              width: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value,
                        color: _palette[i % _palette.length],
                        radius: 44,
                        showTitle: entries[i].value / total >= 0.06,
                        title:
                            '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                        titlePositionPercentageOffset: 0.58,
                      ),
                  ],
                ),
              ),
            );
            final legend = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 11, height: 11,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const Gap(8),
                        Flexible(
                          child: Text(entries[i].key.ticker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        const Gap(10),
                        Text(
                            '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppColors.textFaint, fontSize: 12.5)),
                        const Gap(10),
                        Text('${Won.compact(entries[i].value)}원',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            );
            if (c.maxWidth < 520) {
              return Column(children: [chart, const Gap(16), legend]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                chart,
                const Gap(28),
                Expanded(child: legend),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MarketGroup extends StatelessWidget {
  final String market;
  final double rate;
  final List<DividendHolding> holdings;
  final VoidCallback onAdd;
  final void Function(DividendHolding) onEdit;
  final void Function(DividendHolding) onDelete;
  const _MarketGroup({
    required this.market,
    required this.rate,
    required this.holdings,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final usd = market == '미장';
    final color = usd ? AppColors.primary : AppColors.sky;
    final value = holdings.fold(0.0, (s, d) => s + d.krw(d.marketValue, rate));
    final monthly = holdings.fold(0.0, (s, d) => s + d.krw(d.monthlyDividend, rate));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Pill(market + (usd ? ' \$' : ''), color: color),
                const Gap(10),
                Expanded(
                  child: Text('평가 ${Won.compact(value)}원 · 월 ${Won.compact(monthly)}원',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12.5)),
                ),
                const Gap(10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('추가'),
                ),
              ],
            ),
            if (holdings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('종목을 추가하세요',
                    style: TextStyle(color: AppColors.textFaint)),
              )
            else
              for (final d in holdings) ...[
                const Gap(10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(d.ticker.characters.first,
                          style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(d.ticker,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                              ),
                              const Gap(8),
                              Text('${d.shares.toStringAsFixed(0)}주',
                                  style: const TextStyle(
                                      color: AppColors.textFaint, fontSize: 11.5)),
                            ],
                          ),
                          const Gap(2),
                          Text(
                              '평가 ${Won.compact(d.krw(d.marketValue, rate))}원 · 손익 ${Pct.signed(d.returnPct)} · 배당률 ${Pct.of(d.annualYield, digits: 1)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${Won.compact(d.krw(d.monthlyDividend, rate))}원',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        const Text('월(추정)',
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: 11)),
                      ],
                    ),
                    RecordMenu(onEdit: () => onEdit(d), onDelete: () => onDelete(d)),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// 월별 추적 — 아무 달이나 종목별 '주당 분배금' 입력 → ×수량(×환율) = 실제 배당.
class _DividendMonthly extends ConsumerWidget {
  final List<DividendHolding> holdings;
  final List<MonthlyEntry> entries;
  final double rate;
  const _DividendMonthly(
      {required this.holdings, required this.entries, required this.rate});

  Future<void> _input(BuildContext context, WidgetRef ref) async {
    // 1) 기록할 월 선택 (월 전용)
    final picked = await pickMonth(context);
    if (picked == null) return;
    final month = DateTime(picked.year, picked.month);
    final monthStr = month.toIso8601String().substring(0, 10);
    // 2) 종목별 주당 분배금 입력
    final fields = [
      for (final d in holdings)
        FieldSpec(
            key: d.id,
            label: '${d.ticker} 주당 분배금${d.isUsd ? ' (\$)' : ''}',
            type: FieldType.number),
    ];
    final initial = <String, dynamic>{};
    for (final d in holdings) {
      for (final e in entries) {
        if (e.refId == d.id &&
            e.month.year == month.year &&
            e.month.month == month.month) {
          initial[d.id] = e.amount;
        }
      }
    }
    if (!context.mounted) return;
    final values = await showRecordForm(context,
        title: '${Dates.ym(month)} 주당 분배금',
        fields: fields,
        initial: initial,
        accent: AppColors.primary);
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser!.id;
    final rows = <Map<String, dynamic>>[];
    for (final d in holdings) {
      final v = values[d.id];
      if (v == null) continue;
      rows.add({
        'user_id': uid,
        'category': 'dividend',
        'ref_id': d.id,
        'ref_name': d.ticker,
        'month': monthStr,
        'amount': v,
      });
    }
    if (rows.isNotEmpty) {
      await sb.from('monthly_entries').upsert(rows,
          onConflict: 'user_id,category,ref_id,month');
    }
    ref.invalidate(monthlyEntriesProvider('dividend'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesById = {for (final d in holdings) d.id: d.shares};
    final usdById = {for (final d in holdings) d.id: d.isUsd};
    final byMonth = <String, double>{};
    for (final e in entries) {
      final krw = e.amount *
          (sharesById[e.refId] ?? 0) *
          ((usdById[e.refId] ?? false) ? rate : 1);
      final key = Dates.ym(e.month);
      byMonth[key] = (byMonth[key] ?? 0) + krw;
    }
    final months = byMonth.keys.toList()..sort();
    final recent = months.length > 8 ? months.sublist(months.length - 8) : months;
    final maxV = recent.fold(1.0, (a, k) => byMonth[k]! > a ? byMonth[k]! : a);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader('배당 월별 추적'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                onPressed: () => _input(context, ref),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('월 입력'),
              ),
            ],
          ),
          const Gap(16),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('“월 입력”으로 원하는 달의 주당 분배금을 기록하세요',
                  style: TextStyle(color: AppColors.textFaint)),
            )
          else
            SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final k in recent)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${Won.compact(byMonth[k]!)}원',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const Gap(6),
                            Container(
                              height: (byMonth[k]! / maxV * 62).clamp(4, 62),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppColors.primary, Color(0xFF15803D)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const Gap(7),
                            Text(k,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
