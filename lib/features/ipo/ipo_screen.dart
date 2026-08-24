// 공모주 청약 기록.
//
// 대시보드·자금흐름과 연동하지 않는다 — 사용자가 "그냥 체크하는 정도"라고 했다.
// 총 수익금·승률만 이 화면 안에서 보여준다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

const _indigo = Color(0xFF6366F1);

Map<String, dynamic> _toMap(IpoSubscription e) => {
      'name': e.name,
      'broker': e.broker,
      'offer_price': e.offerPrice,
      'shares': e.shares,
      'sell_price': e.sellPrice,
      'listing_date': e.listingDate?.toIso8601String().substring(0, 10),
      'invested': e.invested,
      'competition_rate': e.competitionRate,
      'memo': e.memo,
    };

class IpoScreen extends ConsumerStatefulWidget {
  const IpoScreen({super.key});

  @override
  ConsumerState<IpoScreen> createState() => _IpoScreenState();
}

class _IpoScreenState extends ConsumerState<IpoScreen> {
  String _filter = 'all'; // all | win | loss | holding

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ipoProvider);
    void add() => editBuiltinRecord(context, ref, ipoSpec);
    return ModulePage(
      title: '공모주',
      subtitle: '청약 기록 · 손익 체크',
      icon: Icons.confirmation_number_rounded,
      color: _indigo,
      action: AddButton(color: _indigo, onTap: add),
      fab: FloatingActionButton(
        onPressed: add,
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        tooltip: '공모주 추가',
        child: const Icon(Icons.add_rounded),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                  icon: Icons.confirmation_number_rounded,
                  message: '청약 기록이 없어요.\n종목·공모가·매도가만 넣으면 손익이 계산됩니다.');
            }
            final sold = items.where((e) => e.sold).toList();
            final total = sold.fold(0.0, (s, e) => s + e.profit);
            final wins = sold.where((e) => e.isWin).length;
            final holding = items.length - sold.length;
            // 평균 수익률은 «주당» 기준 단순평균 (건수 비교가 목적).
            final avgRate = sold.isEmpty
                ? 0.0
                : sold.fold(0.0, (s, e) => s + e.profitRate) / sold.length;

            final list = switch (_filter) {
              'win' => items.where((e) => e.isWin).toList(),
              'loss' => items.where((e) => e.sold && e.profit < 0).toList(),
              'holding' => items.where((e) => !e.sold).toList(),
              _ => items,
            };

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.5,
                  children: [
                    StatTile(
                      label: '총 수익금',
                      value: '${Won.compact(total)}원',
                      icon: Icons.savings_rounded,
                      color: total >= 0 ? AppColors.primary : AppColors.rose,
                    ),
                    StatTile(
                      label: '청약 건수',
                      value: '${items.length}건',
                      icon: Icons.list_alt_rounded,
                      color: _indigo,
                    ),
                    StatTile(
                      label: '승률',
                      value: sold.isEmpty
                          ? '—'
                          : '${(wins / sold.length * 100).round()}%'
                              '  ($wins승 ${sold.length - wins}패)',
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: '평균 수익률',
                      value: Pct.of(avgRate),
                      icon: Icons.percent_rounded,
                      color: avgRate >= 0 ? AppColors.primary : AppColors.rose,
                    ),
                  ],
                ),
                const Gap(18),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip('all', '전체', items.length),
                  _chip('win', '수익', items.where((e) => e.isWin).length),
                  _chip('loss', '손실',
                      items.where((e) => e.sold && e.profit < 0).length),
                  if (holding > 0) _chip('holding', '미매도', holding),
                ]),
                const Gap(14),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('해당 조건의 기록이 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                for (final e in list) ...[
                  _IpoCard(
                    e: e,
                    onEdit: () => editBuiltinRecord(context, ref, ipoSpec,
                        initial: _toMap(e), id: e.id),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, ipoSpec, e.id,
                        name: e.name),
                  ),
                  const Gap(10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _chip(String key, String label, int n) {
    final on = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: on ? _indigo.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: on ? _indigo : AppColors.border, width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label $n',
            style: TextStyle(
                color: on ? _indigo : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _IpoCard extends StatelessWidget {
  final IpoSubscription e;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _IpoCard(
      {required this.e, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = !e.sold
        ? AppColors.textFaint
        : (e.profit >= 0 ? AppColors.primary : AppColors.rose);
    return GlassCard(
      accent: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w700)),
                  ),
                  if ((e.broker ?? '').isNotEmpty) ...[
                    const Gap(8),
                    Pill(e.broker!, color: _indigo),
                  ],
                ]),
              ),
              const Gap(8),
              if (!e.sold)
                const Pill('미매도', color: AppColors.gold)
              else
                Text(Pct.of(e.profitRate),
                    style: TextStyle(
                        fontSize: AppFont.section,
                        fontWeight: FontWeight.w900,
                        color: c)),
              RecordMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const Gap(12),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _m('공모가', '${Won.compact(e.offerPrice)}원'),
              _m('수량', '${e.shares}주'),
              if (e.sold) _m('매도가', '${Won.compact(e.sellPrice)}원'),
              if (e.sold)
                _m('수익금', '${Won.compact(e.profit)}원', color: c),
              if (e.invested > 0)
                _m('청약금', '${Won.compact(e.invested)}원'),
              if (e.competitionRate > 0)
                _m('경쟁률', '${_rate(e.competitionRate)}:1'),
              if (e.listingDate != null)
                _m('상장일',
                    '${e.listingDate!.year % 100}.${e.listingDate!.month.toString().padLeft(2, '0')}.${e.listingDate!.day.toString().padLeft(2, '0')}'),
            ],
          ),
          if ((e.memo ?? '').isNotEmpty) ...[
            const Gap(10),
            Text(e.memo!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
          ],
        ],
      ),
    );
  }

  /// 경쟁률은 소수점이 의미 있을 때만 보여준다 (168.29 / 1816).
  static String _rate(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(2);

  Widget _m(String label, String value, {Color? color}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(3),
          Text(value,
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      );
}
