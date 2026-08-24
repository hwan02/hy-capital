// 첨부 파일을 «앱 안에서» 띄우는 뷰어.
//
// 새 탭으로 보내면 앱을 떠나야 하고 브라우저 팝업 차단에도 걸린다.
// 그래서 팝업(다이얼로그)으로 띄운다:
//   · 이미지 — 확대/이동 가능
//   · PDF   — iframe (브라우저 내장 PDF 뷰어). 암호가 걸린 PDF 는 여기서 물어본다
//   · ESC 또는 닫기 버튼으로 닫는다
//   · 다운로드 버튼 제공
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'knowledge_files.dart' show isImageName;

const _bucket = 'knowledge';

/// iframe 은 뷰 타입을 «한 번만» 등록해야 한다. URL 별로 타입을 따로 만든다.
final _registered = <String>{};

String _registerIframe(String url) {
  final type = 'pdf-${url.hashCode}';
  if (_registered.add(type)) {
    ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
      final e = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return e;
    });
  }
  return type;
}

/// 브라우저가 파일을 내려받게 한다. 서명 URL 에 붙는 리다이렉트를 타므로
/// AnchorElement 로 클릭을 흉내낸다.
void _download(String url, String filename) {
  html.AnchorElement(href: url)
    ..target = '_blank'
    ..download = filename
    ..click();
}

/// 첨부 파일을 팝업으로 띄운다.
Future<void> showFileViewer(
  BuildContext context,
  WidgetRef ref,
  KnowledgeFile file, {
  /// 이미 발급한 서명 URL 이 있으면 재사용한다(앨범 썸네일).
  String? signedUrl,
}) async {
  var url = signedUrl;
  if (url == null) {
    try {
      url = await ref
          .read(supabaseProvider)
          .storage
          .from(_bucket)
          .createSignedUrl(file.path, 3600);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('열지 못했습니다: $e'),
          backgroundColor: AppColors.rose));
      return;
    }
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (_) => _FileViewerDialog(file: file, url: url!),
  );
}

class _FileViewerDialog extends StatelessWidget {
  final KnowledgeFile file;
  final String url;
  const _FileViewerDialog({required this.file, required this.url});

  @override
  Widget build(BuildContext context) {
    final isImg = isImageName(file.name);
    final size = MediaQuery.of(context).size;
    return CallbackShortcuts(
      // showDialog 는 기본적으로 ESC 를 받지만, 안쪽 iframe 이 포커스를
      // 가져가는 경우가 있어 명시적으로 걸어둔다.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.92,
            child: Column(
              children: [
                // 헤더 — 파일명 + 다운로드 + 닫기
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                  child: Row(
                    children: [
                      Icon(
                          isImg
                              ? Icons.image_rounded
                              : Icons.picture_as_pdf_rounded,
                          size: 18,
                          color: isImg ? AppColors.sky : AppColors.rose),
                      const Gap(9),
                      Expanded(
                        child: Text(file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFont.body,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (file.sizeLabel.isNotEmpty) ...[
                        const Gap(8),
                        Text(file.sizeLabel,
                            style: const TextStyle(
                                color: AppColors.textFaint,
                                fontSize: AppFont.caption)),
                      ],
                      const Gap(12),
                      TextButton.icon(
                        onPressed: () => _download(url, file.name),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('다운로드',
                            style: TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Gap(4),
                      IconButton(
                        tooltip: '닫기 (ESC)',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.bg,
                    child: isImg
                        ? InteractiveViewer(
                            maxScale: 5,
                            child: Center(
                              child: Image.network(url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                        child: Text('이미지를 불러오지 못했습니다',
                                            style: TextStyle(
                                                color: AppColors.textFaint)),
                                      )),
                            ),
                          )
                        : HtmlElementView(viewType: _registerIframe(url)),
                  ),
                ),
                // 이미지는 두 손가락/휠로 확대된다는 걸 알려준다.
                if (isImg)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Text('휠 또는 두 손가락으로 확대 · ESC 로 닫기',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
