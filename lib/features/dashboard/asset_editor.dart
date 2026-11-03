// 자산 한 줄 편집 창 — 대시보드 «자산» 카드에서 줄을 누르면 바로 뜬다.
//
// 전엔 «수정/삭제 고르기 → 공용 입력 폼 → 삭제 확인» 세 겹이라 번거로웠고,
// 삭제가 안 된다는 말도 들었다(11/03). 한 창에서 끝낸다:
//   · 이름 · 잔액 · 분류(칩) · 메모 — 라벨 없이 자리만.
//   · 기존 줄은 잔액 칸에 커서가 바로 간다(대부분 잔액만 고친다). Enter = 저장.
//   · 삭제는 휴지통을 «두 번» 누른다 — 확인 창을 또 띄우지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/edit/crud.dart';
import '../../core/edit/plain_controller.dart';
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

Future<void> showAssetEditor(BuildContext context, {Asset? asset}) =>
    showDialog(context: context, builder: (_) => _AssetEditor(asset: asset));

class _AssetEditor extends ConsumerStatefulWidget {
  final Asset? asset;
  const _AssetEditor({this.asset});

  @override
  ConsumerState<_AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends ConsumerState<_AssetEditor> {
  late final _name = PlainController(text: widget.asset?.name ?? '');
  late final _memo = PlainController(text: widget.asset?.memo ?? '');
  late double _amount = widget.asset?.amount ?? 0;
  late String _cat = widget.asset?.category ?? '현금·예금';
  bool _armDelete = false;
  bool _busy = false;
  bool _nameMissing = false;

  bool get _isNew => widget.asset == null;

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
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
    final color = assetColors[_cat] ?? AppColors.gold;
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
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in kAssetCategories)
                  _CatChip(
                    label: c,
                    color: assetColors[c] ?? AppColors.gold,
                    selected: c == _cat,
                    onTap: () => setState(() => _cat = c),
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
