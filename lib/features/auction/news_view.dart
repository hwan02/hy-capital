import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

Color _topicColor(String? t) => switch (t) {
      '신통' => AppColors.violet,
      '모아타운' => AppColors.primary,
      '민간도심복합' => AppColors.gold,
      '공시' => AppColors.rose,
      _ => AppColors.sky,
    };

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// ＋링크 — 다른 사람에게 받은 기사·공시 링크를 직접 추가한다.
Future<void> addNewsLink(BuildContext context, WidgetRef ref) async {
  final urlCtl = TextEditingController();
  final titleCtl = TextEditingController();
  var topic = '모아타운';
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('링크 추가', style: TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: urlCtl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: '링크(URL)', hintText: 'https://...'),
            ),
            const Gap(10),
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(
                  labelText: '제목', hintText: '기사·공시 제목'),
            ),
            const Gap(12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, children: [
                for (final t in ['모아타운', '신통', '민간도심복합', '공시', '기타'])
                  ChoiceChip(
                    label: Text(t),
                    selected: topic == t,
                    onSelected: (_) => setLocal(() => topic = t),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final url = urlCtl.text.trim();
  final title = titleCtl.text.trim();
  if (url.isEmpty || title.isEmpty) return;
  try {
    await ref.read(supabaseProvider).from('news_digest').insert({
      'url': url,
      'title': title,
      'source': '직접 추가',
      'topic': topic,
    });
    ref.invalidate(newsDigestProvider);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 있는 링크이거나 저장에 실패했어요.')));
    }
  }
}

class NewsView extends ConsumerWidget {
  const NewsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newsDigestProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.newspaper_rounded,
            message: '아직 모인 뉴스가 없어요.\n매일 아침 자동 수집되고, ＋링크로 직접 넣을 수도 있어요.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('정비 뉴스·공시',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.w800)),
            const Gap(2),
            Text('${items.length}건 · 매일 아침 자동 수집 + 직접 추가. 눌러서 원문 열기.',
                style: const TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
            const Gap(14),
            for (final n in items) ...[
              _NewsRow(n),
              const Gap(10),
            ],
          ],
        );
      },
    );
  }
}

class _NewsRow extends ConsumerWidget {
  final NewsItem n;
  const _NewsRow(this.n);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _topicColor(n.topic);
    final meta = [
      if ((n.source ?? '').isNotEmpty) n.source!,
      if (n.publishedOn != null) '발행 ${Dates.ymd(n.publishedOn!)}',
    ].join(' · ');
    return GlassCard(
      accent: c,
      padding: const EdgeInsets.all(13),
      child: InkWell(
        onTap: () => _open(n.url),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill(n.topic ?? '기타', color: c),
                    if (n.source == '직접 추가') ...[
                      const Gap(6),
                      const Pill('직접', color: AppColors.textFaint),
                    ],
                  ]),
                  const Gap(7),
                  Text(n.title,
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          height: 1.35)),
                  if (meta.isNotEmpty) ...[
                    const Gap(5),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
            const Gap(8),
            Column(children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 18, color: AppColors.textFaint),
              const Gap(10),
              InkWell(
                onTap: () async {
                  await ref
                      .read(supabaseProvider)
                      .from('news_digest')
                      .delete()
                      .eq('id', n.id);
                  ref.invalidate(newsDigestProvider);
                },
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textFaint),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
