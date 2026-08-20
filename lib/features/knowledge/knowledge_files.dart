// 자료실 항목에 PDF 등을 첨부/열기/삭제한다.
//
// 파일 본체는 Supabase Storage 의 비공개 버킷 'knowledge' 에 두고
// knowledge_notes.files 에는 경로만 저장한다. 열 때마다 서명 URL 을 만든다.
// 버킷이 비공개이므로 로그인한 본인만 접근할 수 있다.
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

const _bucket = 'knowledge';

/// 25MB. Storage 기본 한도(50MB) 안쪽으로 잡되, 웹에서 base64 없이
/// 바이너리로 올리므로 이 정도면 강의 자료 PDF 는 충분하다.
const _maxBytes = 25 * 1024 * 1024;

void _toast(BuildContext context, String msg, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.rose : null,
  ));
}

Uint8List? _bytesOf(Object? result) {
  if (result is Uint8List) return result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}

/// 파일 선택 → Storage 업로드 → files 컬럼 갱신.
Future<void> attachKnowledgeFiles(
  BuildContext context,
  WidgetRef ref,
  KnowledgeNote note,
) async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,application/pdf'
    ..multiple = true;
  input.click();
  await input.onChange.first;
  final picked = input.files;
  if (picked == null || picked.isEmpty) return;

  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) {
    _toast(context, '로그인이 필요합니다', error: true);
    return;
  }

  final added = <KnowledgeFile>[];
  for (final f in picked) {
    if (f.size > _maxBytes) {
      _toast(context, '${f.name} 은(는) 너무 큽니다 (25MB 초과)', error: true);
      continue;
    }
    final reader = html.FileReader()..readAsArrayBuffer(f);
    await reader.onLoad.first;
    final bytes = _bytesOf(reader.result);
    if (bytes == null) {
      _toast(context, '${f.name} 을(를) 읽지 못했습니다', error: true);
      continue;
    }

    // 경로 첫 칸이 user_id 여야 Storage 정책을 통과한다 (0021 마이그레이션).
    final safe = f.name.replaceAll(RegExp(r'[^\w.\-가-힣]'), '_');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
    try {
      await sb.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
      added.add(KnowledgeFile(name: f.name, path: path, size: f.size));
    } catch (e) {
      _toast(context, '업로드 실패: $e', error: true);
    }
  }
  if (added.isEmpty) return;

  try {
    await sb.from('knowledge_notes').update({
      'files': [...note.files, ...added].map((e) => e.toMap()).toList(),
    }).eq('id', note.id);
    invalidateAll(ref);
    _toast(context, '${added.length}개 첨부했습니다');
  } catch (e) {
    _toast(context, '저장 실패: $e', error: true);
  }
}

/// 서명 URL(1시간)을 만들어 새 탭으로 연다.
Future<void> openKnowledgeFile(
  BuildContext context,
  WidgetRef ref,
  KnowledgeFile file,
) async {
  try {
    final url = await ref
        .read(supabaseProvider)
        .storage
        .from(_bucket)
        .createSignedUrl(file.path, 3600);
    // 웹에서는 webOnlyWindowName 없이는 새 탭이 열리지 않는다.
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  } catch (e) {
    _toast(context, '열지 못했습니다: $e', error: true);
  }
}

/// Storage 에서 지우고 files 컬럼에서도 제거한다.
Future<void> deleteKnowledgeFile(
  BuildContext context,
  WidgetRef ref,
  KnowledgeNote note,
  KnowledgeFile file,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('첨부 삭제', style: TextStyle(fontSize: AppFont.section)),
      content: Text('${file.name} 을(를) 삭제할까요?\n되돌릴 수 없습니다.',
          style: const TextStyle(fontSize: AppFont.body)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  final sb = ref.read(supabaseProvider);
  try {
    await sb.storage.from(_bucket).remove([file.path]);
    await sb.from('knowledge_notes').update({
      'files': note.files
          .where((f) => f.path != file.path)
          .map((e) => e.toMap())
          .toList(),
    }).eq('id', note.id);
    invalidateAll(ref);
    _toast(context, '삭제했습니다');
  } catch (e) {
    _toast(context, '삭제 실패: $e', error: true);
  }
}

/// 카드 안에 붙는 첨부 목록. 누르면 새 탭, 길게 누르면 삭제.
class KnowledgeFileChips extends ConsumerWidget {
  final KnowledgeNote note;
  const KnowledgeFileChips({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (note.files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in note.files)
            InkWell(
              onTap: () => openKnowledgeFile(context, ref, f),
              onLongPress: () => deleteKnowledgeFile(context, ref, note, f),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppColors.rose.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.isPdf ? Icons.picture_as_pdf_rounded : Icons.attach_file_rounded,
                      size: 14, color: AppColors.rose),
                  const Gap6(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (f.sizeLabel.isNotEmpty) ...[
                    const Gap6(),
                    Text(f.sizeLabel,
                        style: const TextStyle(
                            fontSize: AppFont.micro,
                            color: AppColors.textFaint)),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// 6px 가로 간격 (gap 패키지를 이 파일에서만 안 쓰기 위한 소품).
class Gap6 extends StatelessWidget {
  const Gap6({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: 6);
}
