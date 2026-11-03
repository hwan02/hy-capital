// 자산 한 줄 편집 창 — 대시보드 «자산» 카드에서 줄을 누르면 바로 뜬다.
//
// 전엔 «수정/삭제 고르기 → 공용 입력 폼 → 삭제 확인» 세 겹이라 번거로웠고,
// 삭제가 안 된다는 말도 들었다(11/03). 한 창에서 끝낸다:
//   · 이름 · 잔액 · 분류(칩) · 메모 — 라벨 없이 자리만.
//   · 기존 줄은 잔액 칸에 커서가 바로 간다(대부분 잔액만 고친다). Enter = 저장.
//   · 삭제는 휴지통을 «두 번» 누른다 — 확인 창을 또 띄우지 않는다.
//
// 분류는 따로 저장하지 않는다 — 항목에 달린 «이름»일 뿐이다.
//   · 편집 창의 「+ 분류」로 새 이름을 만들면 그 항목이 첫 줄이 된다.
//   · 카드에서 분류 제목을 누르면 이름 바꾸기(그 분류 항목 전부) · 삭제(항목까지).
//   · 「부채」만 특별하다 — 순자산에서 뺀다. 그래서 이름은 못 바꾼다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/edit/crud.dart';
import '../../core/edit/plain_controller.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';

const assetColors = <String, Color>{
  '사업': AppColors.sky,
  '투자': AppColors.violet,
  '현금·예금': AppColors.primary,
  '연금': AppColors.gold,
  '부동산': Color(0xFF14B8A6),
  '부채': AppColors.rose,
};

const _extraColors = [
  Color(0xFFF472B6), Color(0xFFFB923C), Color(0xFFA3E635),
  Color(0xFF60A5FA), Color(0xFFE879F9), Color(0xFF2DD4BF),
];

/// 분류 색 — 기본 분류는 고정색, 새로 만든 분류는 이름으로 골라 늘 같은 색.
Color assetColor(String c) =>
    assetColors[c] ??
    _extraColors[c.codeUnits.fold(0, (a, b) => a + b) % _extraColors.length];

/// 쓰고 있는 분류 — 기본 순서 먼저, 새 분류는 뒤에. 하나도 없으면 기본 목록.
List<String> assetCategoriesOf(List<Asset> assets) {
  final used = assets.map((a) => a.category).toSet();
  if (used.isEmpty) return List.of(kAssetCategories);
  return [
    ...kAssetCategories.where(used.contains),
    ...assets.map((a) => a.category).where((c) => !kAssetCategories.contains(c)).toSet(),
  ];
}

/// [category] — 새 항목을 그 분류로 시작한다(분류 칸의 「+」).
Future<void> showAssetEditor(BuildContext context, {Asset? asset, String? category}) =>
    showDialog(
        context: context,
        builder: (_) => _AssetEditor(asset: asset, category: category));

Future<void> showCategoryEditor(BuildContext context, String category, int count) =>
    showDialog(
        context: context,
        builder: (_) => _CategoryEditor(category: category, count: count));

class _AssetEditor extends ConsumerStatefulWidget {
  final Asset? asset;
  final String? category;
  const _AssetEditor({this.asset, this.category});

  @override
  ConsumerState<_AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends ConsumerState<_AssetEditor> {
  late final _name = PlainController(text: widget.asset?.name ?? '');
  late final _memo = PlainController(text: widget.asset?.memo ?? '');
  late double _amount = widget.asset?.amount ?? 0;
  late String _cat = widget.asset?.category ?? widget.category ?? '현금·예금';
  bool _armDelete = false;
  bool _busy = false;
  bool _nameMissing = false;
  bool _adding = false; // 「+ 분류」 입력 중
  final _newCat = PlainController();
  late final List<String> _cats = () {
    final list = assetCategoriesOf(ref.read(assetsProvider).asData?.value ?? const []);
    if (!list.contains(_cat)) list.add(_cat);
    return list;
  }();

  bool get _isNew => widget.asset == null;

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    _newCat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.saveRow('assets', {
        'name': name,
        'category': _cat,
        'amount': _amount,
        'memo': _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      }, id: widget.asset?.id);
      invalidateAll(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 안 됨: $e')));
    }
  }

  Future<void> _delete() async {
    if (!_armDelete) {
      setState(() => _armDelete = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.deleteRow('assets', widget.asset!.id);
      invalidateAll(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 안 됨: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = assetColor(_cat);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 이름 + 닫기
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: _isNew,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_nameMissing) setState(() => _nameMissing = false);
                    },
                    style: const TextStyle(
                        fontSize: AppFont.title, fontWeight: FontWeight.w800),
                    decoration: InputDecoration.collapsed(
                      hintText: _nameMissing ? '이름을 적어 주세요' : '이름',
                      hintStyle: TextStyle(
                          color: _nameMissing ? AppColors.rose : AppColors.textFaint,
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textFaint),
                  tooltip: '닫기',
                ),
              ]),
              const Gap(14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: MoneyField(
                  label: '잔액',
                  initial: _amount,
                  accent: color,
                  autofocus: !_isNew,
                  onChanged: (v) => _amount = v,
                  onSubmitted: (_) => _save(),
                ),
              ),
              const Gap(16),
              // 분류 — 칩 하나 누르면 끝
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final c in _cats)
                  _CatChip(
                    label: c,
                    color: assetColor(c),
                    selected: c == _cat,
                    onTap: () => setState(() => _cat = c),
                  ),
                if (_adding)
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _newCat,
                      autofocus: true,
                      onSubmitted: (v) {
                        final c = v.trim();
                        setState(() {
                          _adding = false;
                          _newCat.clear();
                          if (c.isEmpty) return;
                          if (!_cats.contains(c)) _cats.add(c);
                          _cat = c;
                        });
                      },
                      style: const TextStyle(fontSize: AppFont.label),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '새 분류',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  )
                else
                  _CatChip(
                    label: '+ 분류',
                    color: AppColors.textSecondary,
                    selected: false,
                    onTap: () => setState(() => _adding = true),
                  ),
              ]),
              const Gap(14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _memo,
                  onSubmitted: (_) => _save(),
                  style: const TextStyle(
                      fontSize: AppFont.body, color: AppColors.textSecondary),
                  decoration: const InputDecoration.collapsed(
                    hintText: '메모',
                    hintStyle: TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.body),
                  ),
                ),
              ),
              const Gap(18),
              Row(children: [
                if (!_isNew)
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: _armDelete ? Colors.white : AppColors.rose,
                      backgroundColor: _armDelete ? AppColors.rose : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(_armDelete ? '한 번 더 누르면 삭제' : '삭제'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const Gap(8),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppFont.label,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.black : color)),
      ),
    );
  }
}


/// 분류 이름 바꾸기 / 분류 삭제(그 분류 항목까지).
class _CategoryEditor extends ConsumerStatefulWidget {
  final String category;
  final int count;
  const _CategoryEditor({required this.category, required this.count});

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  late final _name = PlainController(text: widget.category);
  bool _armDelete = false;
  bool _busy = false;

  bool get _debt => widget.category == '부채';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
      invalidateAll(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('안 됨: $e')));
    }
  }

  Future<void> _rename() async {
    final to = _name.text.trim();
    if (to.isEmpty || to == widget.category) {
      Navigator.pop(context);
      return;
    }
    await _run(() => ref
        .read(supabaseProvider)
        .from('assets')
        .update({'category': to}).eq('category', widget.category));
  }

  Future<void> _delete() async {
    if (!_armDelete) {
      setState(() => _armDelete = true);
      return;
    }
    await _run(() =>
        ref.read(supabaseProvider).from('assets').delete().eq('category', widget.category));
  }

  @override
  Widget build(BuildContext context) {
    final color = assetColor(widget.category);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(3))),
                const Gap(10),
                Expanded(
                  child: TextField(
                    controller: _name,
                    enabled: !_debt,
                    autofocus: !_debt,
                    onSubmitted: (_) => _rename(),
                    style: const TextStyle(
                        fontSize: AppFont.title, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration.collapsed(hintText: '분류 이름'),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textFaint),
                  tooltip: '닫기',
                ),
              ]),
              const Gap(18),
              Row(children: [
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: _armDelete ? Colors.white : AppColors.rose,
                    backgroundColor: _armDelete ? AppColors.rose : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_armDelete
                      ? '항목 ${widget.count}개까지 삭제'
                      : '분류 삭제'),
                ),
                const Spacer(),
                if (!_debt)
                  FilledButton(
                    onPressed: _busy ? null : _rename,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                const Gap(8),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
