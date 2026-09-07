// 월급 — 들어온 돈을 매달 어디에 쓸지 미리 나눠두고, 실제로 얼마 썼는지 채운다.
//
//   월급(실수령)  −  배정 합계  =  안 나눈 돈
//   항목마다        쓴 돈 / 배정액        진행바
//
// 이 화면만 PIN 으로 잠근다. RLS 는 «남의 계정»을 막지만, 잠금은 다른 걸
// 막는다 — 로그인된 화면을 옆에서 보는 것. 그래서 잠금 해제는 «세션 한정»
// 이고(새로고침하면 다시 잠긴다), 금액은 기본으로 가려둔다.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/field_spec.dart';
import '../../core/edit/record_form.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';

const _salaryColor = AppColors.primary;

/// PIN 을 해시로만 저장한다. 원문은 어디에도 남기지 않는다.
String _hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt|$pin')).toString();

String _newSalt() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// 카드번호처럼 가린다. 자릿수는 흘리지 않는다 — 항상 같은 길이.
const _mask = '••••••';

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(salaryLockProvider);
    final unlocked = ref.watch(salaryUnlockedProvider);

    return lock.when(
      loading: () => const _Shell(children: [SizedBox.shrink()]),
      error: (_, _) => const _SalaryBody(),
      data: (l) {
        // 잠금이 없으면 바로 본문. 있으면 세션에서 한 번 풀어야 한다.
        if (l == null || unlocked) return const _SalaryBody();
        return _LockGate(hash: l.hash, salt: l.salt);
      },
    );
  }
}

/// 로딩 중에도 화면 틀은 유지한다 — 깜빡임 방지.
class _Shell extends StatelessWidget {
  final List<Widget> children;
  const _Shell({required this.children});

  @override
  Widget build(BuildContext context) => ModulePage(
        title: '월급',
        icon: Icons.lock_rounded,
        color: _salaryColor,
        children: children,
      );
}

// ══════════════════════════════════════════════════════════════
// 잠금 화면
// ══════════════════════════════════════════════════════════════

class _LockGate extends ConsumerStatefulWidget {
  final String hash;
  final String salt;
  const _LockGate({required this.hash, required this.salt});

  @override
  ConsumerState<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<_LockGate> {
  final _c = TextEditingController();
  String? _err;
  int _tries = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _try() {
    if (_hashPin(_c.text.trim(), widget.salt) == widget.hash) {
      ref.read(salaryUnlockedProvider.notifier).set(true);
      return;
    }
    setState(() {
      _tries++;
      _err = '비밀번호가 다릅니다 ($_tries번째)';
      _c.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(children: [
      const Gap(40),
      Center(
        child: SizedBox(
          width: 360,
          child: GlassCard(
            child: Column(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: _salaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: _salaryColor, size: 28),
                ),
                const Gap(16),
                const Text('잠긴 화면입니다',
                    style: TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w900)),
                const Gap(6),
                const Text('비밀번호를 넣어주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFont.body)),
                const Gap(20),
                TextField(
                  controller: _c,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _try(),
                  style: const TextStyle(
                      fontSize: AppFont.display,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(hintText: '••••'),
                ),
                if (_err != null) ...[
                  const Gap(10),
                  Text(_err!,
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700)),
                ],
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _salaryColor,
                        foregroundColor: const Color(0xFF04240F),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _try,
                    child: const Text('열기',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const Gap(12),
                const Text(
                    '잊었으면 Supabase 의 salary_lock 행을 지우세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.body)),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// 본문
// ══════════════════════════════════════════════════════════════

class _SalaryBody extends ConsumerStatefulWidget {
  const _SalaryBody();

  @override
  ConsumerState<_SalaryBody> createState() => _SalaryBodyState();
}

class _SalaryBodyState extends ConsumerState<_SalaryBody> {
  /// 보고 있는 달. 기본은 이번 달.
  late DateTime _month = _thisMonth();

  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  String get _mkey => _month.toIso8601String().substring(0, 10);

  // ── 저장 ──────────────────────────────────────────────────
  Future<void> _err(Object e) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 실패 — $e'), backgroundColor: AppColors.rose),
    );
  }

  /// 이번 달 월급. 없으면 만들고, 있으면 고친다.
  Future<void> _editSalary(SalaryMonth? cur) async {
    final values = await showRecordForm(
      context,
      title: '${Dates.ym(_month)} 월급',
      accent: _salaryColor,
      fields: const [
        FieldSpec(
            key: 'net', label: '실수령액', type: FieldType.money,
            required: true),
        FieldSpec(key: 'gross', label: '세전', type: FieldType.money),
        FieldSpec(key: 'paid_on', label: '들어온 날', type: FieldType.date),
        FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
      ],
      initial: cur == null
          ? {'paid_on': DateTime.now().toIso8601String().substring(0, 10)}
          : {
              'net': cur.net,
              'gross': cur.gross,
              'paid_on': cur.paidOn?.toIso8601String().substring(0, 10),
              'memo': cur.memo,
            },
    );
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    final body = Map<String, dynamic>.from(values)
      ..removeWhere((k, v) => v == null)
      ..['user_id'] = sb.auth.currentUser!.id
      ..['month'] = _mkey;
    try {
      // 월당 한 행이므로 upsert. unique(user_id, month) 가 받아준다.
      await sb.from('salary_months').upsert(body, onConflict: 'user_id,month');
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(salaryMonthsProvider);
  }

  Future<void> _editItem({BudgetItem? item}) async {
    final values = await showRecordForm(
      context,
      title: item == null ? '고정비 추가' : '고정비 수정',
      accent: _salaryColor,
      fields: const [
        FieldSpec(key: 'name', label: '항목', type: FieldType.text,
            required: true),
        FieldSpec(key: 'category', label: '묶음', type: FieldType.select,
            required: true, options: BudgetItem.categories),
        FieldSpec(key: 'amount', label: '배정액', type: FieldType.money,
            required: true),
        FieldSpec(key: 'pay_day', label: '나가는 날', type: FieldType.number),
        // 할부 — 이 둘을 채우면 끝나는 달·남은 회차가 자동으로 나온다.
        FieldSpec(
            key: 'start_month',
            label: '할부 시작월',
            type: FieldType.date),
        FieldSpec(key: 'months', label: '할부 개월 수', type: FieldType.number),
        FieldSpec(key: 'total', label: '할부 총액', type: FieldType.money),
        FieldSpec(key: 'sort_order', label: '표시 순서', type: FieldType.number),
        FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
      ],
      initial: item == null
          ? {'category': '고정비', 'sort_order': 0}
          : {
              'name': item.name,
              'category': item.category,
              'amount': item.amount,
              'pay_day': item.payDay,
              'start_month':
                  item.startMonth?.toIso8601String().substring(0, 10),
              'months': item.months,
              'total': item.total,
              'sort_order': item.sortOrder,
              'memo': item.memo,
            },
    );
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    final body = Map<String, dynamic>.from(values)
      ..removeWhere((k, v) => v == null);
    // 할부 시작월은 «그 달 1일»로 못박는다. 15일을 넣어도 회차 계산이
    // 달 단위라 같은 달이어야 한다.
    final sm = body['start_month'];
    if (sm is String && sm.length >= 7) {
      body['start_month'] = '${sm.substring(0, 7)}-01';
    }
    try {
      if (item == null) {
        body['user_id'] = sb.auth.currentUser!.id;
        await sb.from('budget_items').insert(body);
      } else {
        await sb.from('budget_items').update(body).eq('id', item.id);
      }
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(budgetItemsProvider);
  }

  Future<void> _deleteItem(BudgetItem item) async {
    if (!await confirmDelete(context, name: item.name)) return;
    try {
      await ref.read(supabaseProvider).from('budget_items').delete().eq('id', item.id);
    } catch (e) {
      return _err(e);
    }
    invalidateSalary(ref);
  }

  Future<void> _toggleActive(BudgetItem item) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('budget_items')
          .update({'active': !item.active}).eq('id', item.id);
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(budgetItemsProvider);
  }

  /// 「이 항목에서 이번 달에 얼마 썼나」를 넣는다.
  Future<void> _editSpend(BudgetItem item, double now) async {
    var v = now;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${item.name} — ${Dates.ym(_month)} 쓴 돈',
            style: const TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('배정액 ${Won.plain(item.amount)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: AppFont.body)),
              const Gap(14),
              MoneyField(
                label: '쓴 돈',
                initial: now,
                autofocus: true,
                accent: _salaryColor,
                onChanged: (x) => v = x,
                onSubmitted: (x) {
                  v = x;
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _salaryColor,
                foregroundColor: const Color(0xFF04240F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sb = ref.read(supabaseProvider);
    try {
      await sb.from('budget_spends').upsert({
        'user_id': sb.auth.currentUser!.id,
        'item_id': item.id,
        'month': _mkey,
        'spent': v,
      }, onConflict: 'user_id,item_id,month');
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(budgetSpendsProvider);
  }

  // ── 잠금 설정 ─────────────────────────────────────────────
  Future<void> _setPin() async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('비밀번호 설정',
            style: TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('숫자 4자리 이상',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.body,
                    height: 1.5)),
            const Gap(14),
            TextField(
                controller: c1,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '새 비밀번호')),
            const Gap(10),
            TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '한 번 더')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _salaryColor,
                foregroundColor: const Color(0xFF04240F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('설정'),
          ),
        ],
      ),
    );
    final pin = c1.text.trim();
    c1.dispose();
    final same = pin == c2.text.trim();
    c2.dispose();
    if (ok != true) return;
    if (pin.length < 4) {
      return _err('4자리 이상 넣어주세요');
    }
    if (!same) return _err('두 번 넣은 값이 다릅니다');

    final sb = ref.read(supabaseProvider);
    final salt = _newSalt();
    try {
      await sb.from('salary_lock').upsert({
        'user_id': sb.auth.currentUser!.id,
        'salt': salt,
        'pin_hash': _hashPin(pin, salt),
      }, onConflict: 'user_id');
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(salaryLockProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('잠갔습니다. 새로고침하면 비밀번호를 묻습니다.')),
    );
  }

  Future<void> _clearPin() async {
    final sb = ref.read(supabaseProvider);
    try {
      await sb
          .from('salary_lock')
          .delete()
          .eq('user_id', sb.auth.currentUser!.id);
    } catch (e) {
      return _err(e);
    }
    ref.invalidate(salaryLockProvider);
  }

  // ── 화면 ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final salaries = ref.watch(salaryMonthsProvider);
    final items = ref.watch(budgetItemsProvider);
    final spends = ref.watch(budgetSpendsProvider);
    final masked = ref.watch(salaryMaskedProvider);
    final hasLock = ref.watch(salaryLockProvider).value != null;

    String won(double v) => masked ? _mask : '${Won.compact(v)}원';

    return ModulePage(
      title: '월급',
      icon: Icons.payments_rounded,
      color: _salaryColor,
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: masked ? '금액 보기' : '금액 가리기',
          onPressed: () => ref.read(salaryMaskedProvider.notifier).toggle(),
          icon: Icon(
              masked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: masked ? AppColors.textFaint : _salaryColor),
        ),
        // 아이콘만 두니 어디서 비밀번호를 거는지 못 찾았다 — 글자를 붙인다.
        // (PopupMenuButton 은 icon 과 child 를 동시에 못 준다)
        PopupMenuButton<String>(
          tooltip: '잠금',
          color: AppColors.surfaceAlt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (hasLock ? _salaryColor : AppColors.gold)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(hasLock ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 15, color: hasLock ? _salaryColor : AppColors.gold),
              const Gap(6),
              Text(hasLock ? '잠금 켜짐' : '잠금 설정',
                  style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w800,
                      color: hasLock ? _salaryColor : AppColors.gold)),
            ]),
          ),
          onSelected: (v) {
            switch (v) {
              case 'set':
                _setPin();
              case 'clear':
                _clearPin();
              case 'lock':
                ref.read(salaryUnlockedProvider.notifier).set(false);
                ref.read(salaryMaskedProvider.notifier).set(true);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'set',
                child: Text(hasLock ? '비밀번호 바꾸기' : '비밀번호 걸기')),
            if (hasLock) ...[
              const PopupMenuItem(value: 'lock', child: Text('지금 잠그기')),
              const PopupMenuItem(value: 'clear', child: Text('잠금 풀기(해제)')),
            ],
          ],
        ),
      ]),
      children: [
        if (items.hasError || salaries.hasError)
          const _MigrationNotice()
        else
          _build(salaries, items, spends, won, masked, hasLock),
      ],
    );
  }

  Widget _build(
    AsyncValue<List<SalaryMonth>> salaries,
    AsyncValue<List<BudgetItem>> items,
    AsyncValue<List<BudgetSpend>> spends,
    String Function(double) won,
    bool masked,
    bool hasLock,
  ) {
    if (salaries.isLoading || items.isLoading || spends.isLoading) {
      return AsyncStatus.loading();
    }
    final all = salaries.value ?? const <SalaryMonth>[];
    final every = items.value ?? const <BudgetItem>[];
    // «이 달에 실제로 돈이 나가는» 것만 배정에 넣는다. 끝난 할부가 계속
    // 합계에 남으면 남는 돈이 매달 틀린다.
    final list = every.where((i) => i.runsIn(_month)).toList();
    final off = every.where((i) => !i.active).toList();
    // 아직 시작 안 한 / 이미 끝난 할부 — 합계엔 안 들어가지만 보여준다.
    final upcoming = every
        .where((i) =>
            i.active && i.isInstallment && !i.runsIn(_month) &&
            i.startMonth!.isAfter(_month))
        .toList();
    final finished = every
        .where((i) =>
            i.active && i.isInstallment && !i.runsIn(_month) &&
            !i.startMonth!.isAfter(_month))
        .toList();
    final sp = spends.value ?? const <BudgetSpend>[];

    SalaryMonth? cur;
    for (final s in all) {
      if (s.month.year == _month.year && s.month.month == _month.month) {
        cur = s;
        break;
      }
    }

    // 이 달 항목별 사용액
    final spentBy = <String, double>{};
    for (final s in sp) {
      if (s.month.year == _month.year && s.month.month == _month.month) {
        spentBy[s.itemId] = s.spent;
      }
    }

    final net = cur?.net ?? 0;
    final planned = list.fold(0.0, (a, i) => a + i.amount);
    final spent = list.fold(0.0, (a, i) => a + (spentBy[i.id] ?? 0));
    final left = net - spent; // 통장에 남아 있어야 할 돈
    final unallocated = net - planned; // 아직 안 나눈 돈

    // 월 목록 — 기록이 있는 달 + 이번 달.
    final monthSet = <String>{
      for (final s in all) s.month.toIso8601String().substring(0, 10),
      _thisMonth().toIso8601String().substring(0, 10),
      _mkey,
    };
    final months = monthSet.map(DateTime.parse).toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 잠금이 없으면 «화면 안에서» 걸 수 있게 ───────────
        // 헤더 아이콘만으로는 못 찾는다. 안 걸었을 때만 뜬다.
        if (!hasLock)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              accent: AppColors.gold,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                const Icon(Icons.lock_open_rounded,
                    size: 20, color: AppColors.gold),
                const Gap(12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('이 화면은 아직 안 잠겨 있습니다',
                          style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1B1400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)),
                  onPressed: _setPin,
                  icon: const Icon(Icons.lock_rounded, size: 17),
                  label: const Text('비밀번호 걸기',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),

        // ── 월 선택 ─────────────────────────────────────────
        // 화살표로 «어느 달이든» 간다. 칩만 두면 기록이 있는 달에만
        // 갈 수 있어 지난 달을 새로 넣을 수가 없다.
        Row(children: [
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: '지난 달',
            onTap: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
          ),
          const Gap(8),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in months.take(14))
                _Chip(
                  label: Dates.ym(m),
                  selected: m.year == _month.year && m.month == _month.month,
                  onTap: () => setState(() => _month = m),
                ),
              // 이번 달에서 멀어졌으면 돌아올 길을 준다.
              if (_month != _thisMonth())
                _Chip(
                  label: '이번 달',
                  selected: false,
                  onTap: () => setState(() => _month = _thisMonth()),
                ),
            ]),
          ),
          const Gap(8),
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            tooltip: '다음 달',
            onTap: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ]),
        const Gap(16),

        // ── 이번 달 월급 ─────────────────────────────────────
        _SalaryCard(
          month: _month,
          salary: cur,
          masked: masked,
          onEdit: () => _editSalary(cur),
          onReveal: () => ref.read(salaryMaskedProvider.notifier).toggle(),
        ),
        const Gap(16),

        // ── 세 칸 요약 ───────────────────────────────────────
        ResponsiveGrid(
          minTileWidth: 210,
          children: [
            _Stat('배정한 돈', won(planned), AppColors.sky,
                sub: net > 0 ? '월급의 ${(planned / net * 100).round()}%' : null),
            _Stat('실제 쓴 돈', won(spent), AppColors.rose,
                sub: planned > 0
                    ? '배정의 ${(spent / planned * 100).round()}%'
                    : null),
            _Stat('통장에 남을 돈', won(left),
                left >= 0 ? AppColors.primary : AppColors.rose),
          ],
        ),
        const Gap(16),

        // ── 할부 ─────────────────────────────────────────────
        // 할부는 «언제 끝나나»가 제일 궁금하다. 이 달 나가는 액수보다
        // 앞으로 더 낼 돈과 끝나는 달을 먼저 보여준다.
        Builder(builder: (context) {
          final inst = list.where((i) => i.isInstallment).toList()
            ..sort((a, b) => a.endMonth!.compareTo(b.endMonth!));
          if (inst.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();
          final monthly = inst.fold(0.0, (a, i) => a + i.amount);
          final rest = inst.fold(0.0, (a, i) => a + i.remainingAmount(_month));
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              accent: AppColors.violet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.credit_card_rounded,
                        size: 18, color: AppColors.violet),
                    const Gap(9),
                    Text('할부 ${inst.length}건',
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(won(monthly),
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w900,
                            color: AppColors.violet)),
                  ]),
                  if (inst.isNotEmpty) ...[
                    const Gap(6),
                    Text('남은 ${won(rest)} · 마지막 ${Dates.ym(inst.last.endMonth!)}',
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            color: AppColors.textSecondary)),
                    const Gap(12),
                    // 가장 먼저 끝나는 순서. 「이거 끝나면 얼마 빈다」가 보인다.
                    for (final i in inst)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          SizedBox(
                            width: 132,
                            child: Text(i.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: AppFont.body,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Gap(8),
                          Expanded(
                            child: ProgressBar(
                                value: i.roundIn(_month)! / i.months!,
                                color: AppColors.violet,
                                height: 6),
                          ),
                          const Gap(10),
                          Text('${i.roundIn(_month)}/${i.months}회 · '
                              '~${Dates.ym(i.endMonth!)}',
                              style: const TextStyle(
                                  fontSize: AppFont.body,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ]),
                      ),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    const Gap(10),
                    Text(
                        '시작 전 ${upcoming.length}건 — '
                        '${upcoming.map((i) => '${i.name} ${Dates.ym(i.startMonth!)}부터').join(' · ')}',
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
          );
        }),

        // ── 안 나눈 돈 경고 ──────────────────────────────────
        if (net > 0 && unallocated.abs() >= 10000)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              accent: unallocated > 0 ? AppColors.gold : AppColors.rose,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Icon(
                    unallocated > 0
                        ? Icons.savings_rounded
                        : Icons.warning_amber_rounded,
                    size: 20,
                    color: unallocated > 0 ? AppColors.gold : AppColors.rose),
                const Gap(11),
                Expanded(
                  child: Text(
                      unallocated > 0
                          ? '안 나눈 돈 ${won(unallocated)}'
                          : '배정액이 월급보다 ${won(-unallocated)} 많습니다',
                      style: TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w800,
                          color: unallocated > 0
                              ? AppColors.gold
                              : AppColors.rose)),
                ),
              ]),
            ),
          ),

        // ── 고정비 ───────────────────────────────────────────
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('고정비',
                  subtitle: '${list.length}개',
                  trailing: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _salaryColor,
                        foregroundColor: const Color(0xFF04240F),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10)),
                    onPressed: () => _editItem(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('항목 추가'),
                  )),
              const Gap(14),
              if (list.isEmpty)
                const EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    message: '고정비를 넣으세요')
              else ...[
                // 전체 진행
                _TotalBar(spent: spent, planned: planned, masked: masked),
                const Gap(18),
                for (final cat in BudgetItem.categories)
                  Builder(builder: (context) {
                    // 개월 수를 넣었으면 그게 할부다 — 묶음을 따로 고를
                    // 필요가 없다. 고르게 두면 안 골라서 엉뚱한 데 붙는다.
                    final mine =
                        list.where((i) => i.groupOf == cat).toList();
                    if (mine.isEmpty) return const SizedBox.shrink();
                    final cs = mine.fold(0.0, (a, i) => a + (spentBy[i.id] ?? 0));
                    final cp = mine.fold(0.0, (a, i) => a + i.amount);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(children: [
                            Text(cat,
                                style: const TextStyle(
                                    fontSize: AppFont.body,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary)),
                            const Gap(10),
                            Text('${won(cs)} / ${won(cp)}',
                                style: const TextStyle(
                                    fontSize: AppFont.body,
                                    color: AppColors.textFaint)),
                          ]),
                        ),
                        for (final i in mine)
                          _ItemRow(
                            item: i,
                            month: _month,
                            spent: spentBy[i.id] ?? 0,
                            masked: masked,
                            onSpend: () => _editSpend(i, spentBy[i.id] ?? 0),
                            onEdit: () => _editItem(item: i),
                            onDelete: () => _deleteItem(i),
                            onToggle: () => _toggleActive(i),
                          ),
                        const Gap(10),
                      ],
                    );
                  }),
              ],
              // 끝난 할부 — 합계엔 없지만 「끝났다」가 보여야 한다.
              if (finished.isNotEmpty) ...[
                const Divider(color: AppColors.border, height: 28),
                Text('끝난 할부 ${finished.length}건',
                    style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.violet)),
                const Gap(8),
                for (final i in finished)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 15, color: AppColors.violet),
                      const Gap(8),
                      Expanded(
                        child: Text(
                            '${i.name} · ${Dates.ym(i.endMonth!)} ${i.months}회 완납',
                            style: const TextStyle(
                                fontSize: AppFont.body,
                                color: AppColors.textSecondary)),
                      ),
                      RecordMenu(
                          onEdit: () => _editItem(item: i),
                          onDelete: () => _deleteItem(i)),
                    ]),
                  ),
              ],
              // 꺼둔 항목
              if (off.isNotEmpty) ...[
                const Divider(color: AppColors.border, height: 28),
                Text('쉬는 항목 ${off.length}개',
                    style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textFaint)),
                const Gap(8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final i in off)
                    ActionChip(
                      label: Text('${i.name}  ${Won.compact(i.amount)}',
                          style: const TextStyle(fontSize: AppFont.body)),
                      backgroundColor: AppColors.surfaceAlt,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _toggleActive(i),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 조각들
// ══════════════════════════════════════════════════════════════

/// 이번 달 월급. 카드번호처럼 기본은 가려두고 눈을 눌러야 보인다.
class _SalaryCard extends StatelessWidget {
  final DateTime month;
  final SalaryMonth? salary;
  final bool masked;
  final VoidCallback onEdit;
  final VoidCallback onReveal;

  const _SalaryCard({
    required this.month,
    required this.salary,
    required this.masked,
    required this.onEdit,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final net = salary?.net ?? 0;
    return GlassCard(
      accent: _salaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${Dates.ym(month)} 실수령액',
                style: const TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const Gap(10),
            if (salary != null)
              Pill(salary!.received ? '입금 완료' : '입금 전',
                  color:
                      salary!.received ? AppColors.primary : AppColors.gold),
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                  foregroundColor: _salaryColor,
                  visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text(salary == null ? '월급 넣기' : '수정',
                  style: const TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.w700)),
            ),
          ]),
          const Gap(10),
          // 금액 — 가려진 상태에서 눌러도 보이게 (카드번호와 같은 동작).
          InkWell(
            onTap: onReveal,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text(
                    salary == null
                        ? '—'
                        : (masked ? _mask : '${Won.compact(net)}원'),
                    style: const TextStyle(
                        fontSize: AppFont.hero,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const Gap(14),
                Icon(
                    masked
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textFaint),
              ]),
            ),
          ),
          if (!masked && salary?.gross != null) ...[
            const Gap(4),
            Text('세전 ${Won.compact(salary!.gross!)}원',
                style: const TextStyle(
                    fontSize: AppFont.body, color: AppColors.textFaint)),
          ],
          if (salary?.memo?.isNotEmpty == true) ...[
            const Gap(6),
            Text(salary!.memo!,
                style: const TextStyle(
                    fontSize: AppFont.body, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? sub;
  const _Stat(this.label, this.value, this.color, {this.sub});

  /// 높이를 «고정»한다. 빈 Text('')는 높이가 0 이라 자리를 안 잡아서,
  /// 밑줄이 있는 칸과 없는 칸의 높이가 그대로 어긋났다.
  /// ResponsiveGrid 는 Wrap 이라 타일 높이를 맞춰주지 않는다.
  static const height = 112.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: height,
        child: GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const Gap(8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: AppFont.display,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const Gap(4),
          Text(sub ?? '',
              style: const TextStyle(
                  fontSize: AppFont.body, color: AppColors.textFaint)),
        ],
      ),
    ));
  }
}

/// 「쓴 돈 / 배정액」 전체 진행.
class _TotalBar extends StatelessWidget {
  final double spent;
  final double planned;
  final bool masked;
  const _TotalBar(
      {required this.spent, required this.planned, required this.masked});

  @override
  Widget build(BuildContext context) {
    final r = planned <= 0 ? 0.0 : spent / planned;
    final over = spent > planned;
    String w(double v) => masked ? _mask : '${Won.compact(v)}원';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('배정한 돈 중 쓴 것',
              style: TextStyle(
                  fontSize: AppFont.body, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${w(spent)} / ${w(planned)}',
              style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w900,
                  color: over ? AppColors.rose : AppColors.textPrimary)),
        ]),
        const Gap(8),
        ProgressBar(
            value: r, color: over ? AppColors.rose : _salaryColor, height: 10),
      ],
    );
  }
}

/// 고정비 한 줄 — 「쓴 돈 / 배정액」과 진행바. 누르면 쓴 돈을 넣는다.
class _ItemRow extends StatelessWidget {
  final BudgetItem item;
  final DateTime month;
  final double spent;
  final bool masked;
  final VoidCallback onSpend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ItemRow({
    required this.item,
    required this.month,
    required this.spent,
    required this.masked,
    required this.onSpend,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final r = item.amount <= 0 ? 0.0 : spent / item.amount;
    final over = spent > item.amount;
    final done = spent > 0 && !over;
    final round = item.roundIn(month);
    String w(double v) => masked ? _mask : '${Won.compact(v)}원';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: onSpend,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w700)),
                    if (item.payDay != null) ...[
                      const Gap(8),
                      Text('${item.payDay}일',
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              color: AppColors.textFaint)),
                    ],
                    // 할부 — 몇 회차인지가 제일 궁금하다.
                    if (round != null) ...[
                      const Gap(8),
                      Pill('$round/${item.months}회', color: AppColors.violet),
                    ],
                    const Spacer(),
                    Text('${w(spent)} / ${w(item.amount)}',
                        style: TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w800,
                            color: over
                                ? AppColors.rose
                                : (done
                                    ? _salaryColor
                                    : AppColors.textSecondary))),
                  ]),
                  const Gap(6),
                  ProgressBar(
                      value: r,
                      color: over ? AppColors.rose : _salaryColor,
                      height: 6),
                  // 할부 — 언제 끝나고 얼마 남았나.
                  if (round != null) ...[
                    const Gap(5),
                    Text(
                        '${Dates.ym(item.endMonth!)}까지 · '
                        '${item.remainingRounds(month)}회 · '
                        '${w(item.remainingAmount(month))}',
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.violet)),
                  ],
                  if (over) ...[
                    const Gap(4),
                    Text('배정보다 ${w(spent - item.amount)} 초과',
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w700,
                            color: AppColors.rose)),
                  ],
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '이번 달 쉬기',
          onPressed: onToggle,
          icon: const Icon(Icons.pause_circle_outline_rounded,
              size: 18, color: AppColors.textFaint),
        ),
        RecordMenu(onEdit: onEdit, onDelete: onDelete),
      ]),
    );
  }
}

/// 월을 앞뒤로 넘기는 버튼.
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _NavBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Icon(icon, size: 22, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _salaryColor : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(label,
              style: TextStyle(
                  color: selected
                      ? const Color(0xFF04240F)
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFont.body)),
        ),
      ),
    );
  }
}

/// 테이블이 아직 없을 때 — 조용히 빈 화면을 주면 원인을 알 길이 없다.
class _MigrationNotice extends StatelessWidget {
  const _MigrationNotice();

  @override
  Widget build(BuildContext context) => GlassCard(
        accent: AppColors.gold,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('테이블이 아직 없습니다',
              style: TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          Gap(8),
          Text(
              'Supabase SQL Editor 에서 supabase/migrations/0047_salary.sql 을 실행하세요.',
              style: TextStyle(
                  fontSize: AppFont.body,
                  color: AppColors.textSecondary,
                  height: 1.5)),
        ]),
      );
}
