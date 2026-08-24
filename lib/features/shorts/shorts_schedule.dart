import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// 배우·영화 뒷이야기 쇼츠 8/21~9/30 편성표 (부자되는세상 특강 기반 계획).
/// Shorts 화면의 '편성표' 탭에서 본다. 카테고리 필터 + 주차별 그룹.

class ShortsSlot {
  final String date; // 8/21
  final String wd; // 금
  final String cat; // fire/film/mind/data/trophy/swap
  final String title;
  final String hook;
  final String src;
  final String url; // 빈 문자열이면 링크 없음
  final String prio; // "5" · "4.5" · "?"
  const ShortsSlot(this.date, this.wd, this.cat, this.title, this.hook, this.src,
      this.url, this.prio);
}

class ShortsCat {
  final String emoji;
  final String label;
  final Color color;
  const ShortsCat(this.emoji, this.label, this.color);
}

const shortsCats = <String, ShortsCat>{
  'fire': ShortsCat('🔥', '오디션·화제', AppColors.rose),
  'film': ShortsCat('🎬', '명장면', AppColors.sky),
  'mind': ShortsCat('🤯', '제작 비화', AppColors.violet),
  'data': ShortsCat('📈', '데이터 후속', AppColors.primary),
  'trophy': ShortsCat('🏆', '월말 베스트', AppColors.gold),
  'swap': ShortsCat('🔄', '교체 슬롯', AppColors.textFaint),
};

const shortsSlots = <ShortsSlot>[
  ShortsSlot('8/21', '금', 'fire', 'Chase Stokes — 탑건 오디션 대참사', '배역도 모르고 탑건 오디션을 본 배우', 'EW · Lie vs. Lie 인터뷰', 'https://ew.com/chase-stokes-botched-top-gun-maverick-audition-12064741', '5'),
  ShortsSlot('8/22', '토', 'fire', 'Adam Scott — 딸 연기학원의 실패 사례가 된 아빠', '딸 연기학원에서 최악의 예시로 나온 아빠', 'Jimmy Fallon (약 9:03–10:20)', 'https://podscan.fm/podcasts/the-tonight-show-starring-jimmy-fallon', '5'),
  ShortsSlot('8/23', '일', 'fire', 'Nick Jonas — 겨울왕국 Kristoff 오디션 탈락', '겨울왕국 남주가 될 뻔했던 가수', 'EW · Hey Jonas + 성우 인터뷰', 'https://ew.com/nick-jonas-almost-starred-in-frozen-but-he-bombed-the-audition-12063043', '5'),
  ShortsSlot('8/24', '월', 'film', 'Andrew Garfield — MJ를 구한 뒤 무너지는 표정', '널 이렇게 구했더라면', 'No Way Home 명장면', '', '5'),
  ShortsSlot('8/25', '화', 'fire', 'Matthew McConaughey — 타이타닉 잭 오디션', '타이타닉 잭이 디카프리오가 아닐 뻔했다', 'People · Happy Sad Confused', 'https://people.com/matthew-mcconaughey-reveals-the-truth-behind-rumors-he-turned-down-lead-in-titanic-12058897', '5'),
  ShortsSlot('8/26', '수', 'fire', "Elliot Page — 놀란의 '클래식 놀란' 촬영법", '이걸 진짜로 찍었다고?', 'Fallon / Odyssey 촬영 이야기', 'https://www.reutersconnect.com/item/uncaptioned-elliot-page-reveals-the-odyssey-script-left-him-breathless', '5'),
  ShortsSlot('8/27', '목', 'mind', 'Kyle Chandler — 그린랜턴 슈트가 원래 없었다', '그린랜턴인데 슈트가 없을 뻔했다', 'GamesRadar · Jimmy Kimmel', 'https://www.gamesradar.com/entertainment/dc-tv-shows/lanterns-didnt-originally-feature-a-green-lantern-suit-as-star-reveals-the-dc-show-creators-werent-sure-about-including-it/', '5'),
  ShortsSlot('8/28', '금', 'fire', 'Dave Franco — 교황을 웃긴 배우', '교황을 실제로 웃겨버린 배우', 'ABC · Jimmy Kimmel 8/13', 'https://abc.com/show/9bfe2f4f-41ad-4492-a6dd-0b67db180543/guest-schedule', '4'),
  ShortsSlot('8/29', '토', 'film', 'Good Will Hunting — Robin Williams 마지막 애드립', '영화의 마지막 대사가 사실 애드립이었다', 'People · Matt Damon 인터뷰', 'https://people.com/matt-damon-remembers-robin-williams-improvising-memorable-good-will-hunting-line-12013377', '5'),
  ShortsSlot('8/30', '일', 'data', '8/21–29 조회수 1위 인물 2탄', '데이터 보고 결정', '채널 데이터', '', '5'),
  ShortsSlot('8/31', '월', 'data', '유효조회수 1위 포맷 + 다른 배우', '데이터 보고 결정', '채널 데이터', '', '5'),
  ShortsSlot('9/1', '화', 'mind', 'Ryan Gosling — 헤일메리 외계인은 실제로 현장에 있었다', 'CG인 줄 알았는데 진짜였습니다', 'EW · Rocky 실제 퍼펫', 'https://ew.com/project-hail-mary-puppeteer-james-ortiz-interview-ryan-gosling-improv-11926276', '5'),
  ShortsSlot('9/2', '수', 'mind', 'Ryan Gosling — Rocky 엄지척 장면 탄생 비화', '이 장면은 대본에 없었습니다', 'EW · 즉흥 아이디어 채택', 'https://ew.com/project-hail-mary-puppeteer-james-ortiz-interview-ryan-gosling-improv-11926276', '5'),
  ShortsSlot('9/3', '목', 'fire', 'Sally Field — 감독이 오디션장에 온 것부터 싫어했던 배우', '감독이 오디션조차 보기 싫어했던 배우', 'EW · THR 인터뷰', 'https://ew.com/director-was-angry-sally-field-was-allowed-to-audition-for-breakout-film-role-12060196', '4.5'),
  ShortsSlot('9/4', '금', 'film', 'Robin Williams — 굿 윌 헌팅 애드립 2탄', '맷 데이먼이 바로 벤 애플렉에게 전화한 장면', 'People · Damon 회고', 'https://people.com/matt-damon-remembers-robin-williams-improvising-memorable-good-will-hunting-line-12013377', '5'),
  ShortsSlot('9/5', '토', 'mind', 'Adam Scott — The Office Jim이 될 뻔했던 배우', '짐 역할에서 떨어진 배우의 현재', 'EW · Fallon + 오디션 이야기', 'https://ew.com/adam-scott-daughter-acting-class-office-audition-tape-john-krasinski-12059891', '4.5'),
  ShortsSlot('9/6', '일', 'data', '9/1–5 1위 콘텐츠 즉시 2탄', '같은 인물/같은 사건', '채널 데이터', '', '5'),
  ShortsSlot('9/7', '월', 'fire', 'Anne Hathaway + Ewan McGregor 최신 Kimmel 인터뷰', '인터뷰 중 가장 강한 에피소드로 편집', 'Detpress · Kimmel 8/10 편성', 'https://www.detpress.com/abc/pressrelease/anne-hathaway-ewan-mcgregor-earvin-magic-johnson-kyle-chandler-dave-franco-with-guest-host-anthony-anderson-on-abcs-jimmy-kimmel-live-aug-10-14/', '4'),
  ShortsSlot('9/8', '화', 'mind', 'Kyle Chandler — 그린랜턴 슈트 입는데 45분', '히어로가 화장실 가기 힘든 이유', 'GamesRadar · Kimmel', 'https://www.gamesradar.com/entertainment/dc-tv-shows/lanterns-didnt-originally-feature-a-green-lantern-suit-as-star-reveals-the-dc-show-creators-werent-sure-about-including-it/', '4.5'),
  ShortsSlot('9/9', '수', 'film', 'Project Hail Mary — Ryan과 Rocky의 즉흥연기', '이 둘은 촬영 전에 매일 대사를 바꿨습니다', 'EW · 제작 인터뷰', 'https://ew.com/project-hail-mary-puppeteer-james-ortiz-interview-ryan-gosling-improv-11926276', '5'),
  ShortsSlot('9/10', '목', 'mind', 'Matthew McConaughey — 타이타닉 캐스팅설의 진실', "'타이타닉을 거절했다'는 소문, 본인이 직접 해명했다", 'People · Happy Sad Confused', 'https://people.com/matthew-mcconaughey-reveals-the-truth-behind-rumors-he-turned-down-lead-in-titanic-12058897', '4.5'),
  ShortsSlot('9/11', '금', 'fire', 'Aaron Pierre — 새로운 Green Lantern이 된 배우', '새 그린랜턴으로 뽑힌 배우', 'ABC · Jimmy Kimmel 8/11', 'https://abc.com/show/9bfe2f4f-41ad-4492-a6dd-0b67db180543/guest-schedule', '4'),
  ShortsSlot('9/12', '토', 'film', 'Andrew Garfield — MJ 장면 후속', '이 표정 하나 때문에 전작을 본 사람들은 울었다', 'No Way Home', '', '5'),
  ShortsSlot('9/13', '일', 'data', '9/7–12 조회수 1위 후속', '무조건 승자 복제', '채널 데이터', '', '5'),
  ShortsSlot('9/14', '월', 'mind', 'Karolina Wydra — 실제 오디션 vs 완성 장면 비교', '오디션과 실제 영화는 얼마나 달라질까?', 'EW · audition footage 공개', 'https://ew.com/watch-karolina-wydra-pluribus-audition-with-rhea-seehorn-exclusive-12057456', '4'),
  ShortsSlot('9/15', '화', 'film', 'Project Hail Mary — 얼굴 없는 Rocky를 연기한 방법', '표정 하나 없는 외계인이 감정을 보여준 방법', 'EW · 퍼펫 제작/연기', 'https://ew.com/project-hail-mary-puppeteer-james-ortiz-interview-ryan-gosling-improv-11926276', '4.5'),
  ShortsSlot('9/16', '수', 'mind', 'Sally Field — 아무도 원하지 않았는데 배역을 따낸 이야기', '감독이 싫어했던 배우가 결국 배역을 따냈다', 'EW · THR 인터뷰', 'https://ew.com/director-was-angry-sally-field-was-allowed-to-audition-for-breakout-film-role-12060196', '4'),
  ShortsSlot('9/17', '목', 'fire', 'Lanterns — 그린랜턴을 범죄드라마로 만든 이유', '그린랜턴을 왜 갑자기 True Detective처럼 만들었을까?', 'GQ · Tom King 인터뷰', 'https://www.gq.com/story/tom-king-lanterns-writer-interview', '4'),
  ShortsSlot('9/18', '금', 'swap', '9월 신규 인터뷰 교체 슬롯', '이날 최근 7일 다시 검색해서 확정', '미래 뉴스', '', '?'),
  ShortsSlot('9/19', '토', 'film', 'Good Will Hunting 명장면 + 애드립', '대본을 쓴 맷 데이먼조차 예상 못한 대사', 'People · Damon 인터뷰', 'https://people.com/matt-damon-remembers-robin-williams-improvising-memorable-good-will-hunting-line-12013377', '5'),
  ShortsSlot('9/20', '일', 'data', '9/14–19 조회수 1위 2탄', '승자 복제', '채널 데이터', '', '5'),
  ShortsSlot('9/21', '월', 'swap', '9월 신규 해외배우 이슈', '그날 검색해서 정확한 사건 지정', '미래 뉴스', '', '?'),
  ShortsSlot('9/22', '화', 'film', 'Project Hail Mary — Rocky가 CG가 아닌 증거/제작 과정', '관객 대부분이 CG라고 착각한 캐릭터', 'EW · 제작 인터뷰', 'https://ew.com/project-hail-mary-puppeteer-james-ortiz-interview-ryan-gosling-improv-11926276', '5'),
  ShortsSlot('9/23', '수', 'mind', 'Adam Scott 실패 오디션 vs John Krasinski 합격 오디션', '같은 역할, 한 명은 떨어지고 한 명은 붙었다', 'EW · 두 audition tape 비교', 'https://ew.com/adam-scott-daughter-acting-class-office-audition-tape-john-krasinski-12059891', '5'),
  ShortsSlot('9/24', '목', 'swap', '9월 신규 Jimmy/Fallon/Kimmel 인터뷰', '당일 원본 영상 + 에피소드 지정', '미래 인터뷰', '', '?'),
  ShortsSlot('9/25', '금', 'data', '9월 현재 TOP 인물의 3번째 이야기', '데이터 결정', '채널 데이터', '', '5'),
  ShortsSlot('9/26', '토', 'film', '9월 영화 명장면 SPECIAL', '앞선 명장면 성과 보고 작품 선정', '데이터 결정', '', '5'),
  ShortsSlot('9/27', '일', 'data', '주간 조회수 1위 2탄', '승자 복제', '채널 데이터', '', '5'),
  ShortsSlot('9/28', '월', 'trophy', '9월 조회수 1위 인물 + 아직 안 쓴 에피소드', '데이터 결정', '채널 데이터', '', '5'),
  ShortsSlot('9/29', '화', 'trophy', '9월 유효조회수율 1위 포맷 + 새로운 유명배우', '데이터 결정', '채널 데이터', '', '5'),
  ShortsSlot('9/30', '수', 'trophy', '9월 최고 영상 후속편', '1위 영상 2탄', '데이터 결정', '', '5'),
];

class _Week {
  final String label;
  final String range;
  final List<String> dates;
  const _Week(this.label, this.range, this.dates);
}

const _weeks = <_Week>[
  _Week('1주차 · 오프닝 3연발', '8/21–8/23', ['8/21', '8/22', '8/23']),
  _Week('2주차 · 첫 데이터 회수', '8/24–8/30', ['8/24', '8/25', '8/26', '8/27', '8/28', '8/29', '8/30']),
  _Week('3주차 · 헤일메리 시리즈', '8/31–9/6', ['8/31', '9/1', '9/2', '9/3', '9/4', '9/5', '9/6']),
  _Week('4주차 · 그린랜턴 라인', '9/7–9/13', ['9/7', '9/8', '9/9', '9/10', '9/11', '9/12', '9/13']),
  _Week('5주차 · 비교/후속 강화', '9/14–9/20', ['9/14', '9/15', '9/16', '9/17', '9/18', '9/19', '9/20']),
  _Week('6주차 · 후반 스퍼트', '9/21–9/27', ['9/21', '9/22', '9/23', '9/24', '9/25', '9/26', '9/27']),
  _Week('마무리 · 월간 베스트', '9/28–9/30', ['9/28', '9/29', '9/30']),
];

class ShortsScheduleTab extends StatefulWidget {
  const ShortsScheduleTab({super.key});

  @override
  State<ShortsScheduleTab> createState() => _ShortsScheduleTabState();
}

class _ShortsScheduleTabState extends State<ShortsScheduleTab> {
  String _filter = 'all';
  final Set<String> _done = {}; // 세션 내 완료 표시(저장 안 됨)

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in shortsSlots) {
      counts[s.cat] = (counts[s.cat] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 필터 칩
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: '전체',
              count: shortsSlots.length,
              color: AppColors.gold,
              selected: _filter == 'all',
              onTap: () => setState(() => _filter = 'all'),
            ),
            for (final e in shortsCats.entries)
              _FilterChip(
                label: '${e.value.emoji} ${e.value.label}',
                count: counts[e.key] ?? 0,
                color: e.value.color,
                selected: _filter == e.key,
                onTap: () => setState(() => _filter = e.key),
              ),
          ],
        ),
        const Gap(18),
        for (final w in _weeks) ..._week(w),
        const Gap(8),
        Text(
          '총 ${shortsSlots.length}편 · ★ 우선순위 · 📈🏆 데이터 결정 · 🔄 당일 검색 · 날짜 2026년 기준',
          style: const TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint),
        ),
      ],
    );
  }

  List<Widget> _week(_Week w) {
    final slots = shortsSlots
        .where((s) => w.dates.contains(s.date))
        .where((s) => _filter == 'all' || s.cat == _filter)
        .toList();
    if (slots.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(w.label,
                style: const TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            const Gap(10),
            Text(w.range,
                style: const TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ],
        ),
      ),
      for (final s in slots) ShortsSlotCard(
        slot: s,
        done: _done.contains(s.date),
        onToggleDone: () => setState(() {
          if (!_done.remove(s.date)) _done.add(s.date);
        }),
        onOpen: s.url.isEmpty ? null : () => _open(s.url),
      ),
    ];
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(color: selected ? color : AppColors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
          const Gap(6),
          Text('$count',
              style: TextStyle(
                  fontSize: AppFont.micro,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textFaint)),
        ]),
      ),
    );
  }
}

class ShortsSlotCard extends StatelessWidget {
  final ShortsSlot slot;
  final bool done;
  final VoidCallback onToggleDone;
  final VoidCallback? onOpen;
  const ShortsSlotCard({
    required this.slot,
    required this.done,
    required this.onToggleDone,
    required this.onOpen,
  });

  String _stars(String p) {
    if (p == '?') return '🔄';
    final v = double.tryParse(p) ?? 0;
    final full = v.floor();
    final half = v - full >= 0.5;
    return '★' * full + (half ? '½' : '');
  }

  @override
  Widget build(BuildContext context) {
    final meta = shortsCats[slot.cat]!;
    final parts = slot.date.split('/');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        accent: meta.color,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Text(parts.length > 1 ? parts[1] : slot.date,
                      style: const TextStyle(
                          fontSize: AppFont.display,
                          fontWeight: FontWeight.w800,
                          height: 1)),
                  const Gap(2),
                  Text('${parts[0]}월 ${slot.wd}',
                      style: const TextStyle(
                          fontSize: AppFont.micro, color: AppColors.textFaint)),
                ],
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill('${meta.emoji} ${meta.label}', color: meta.color),
                    const Gap(8),
                    Text(_stars(slot.prio),
                        style: const TextStyle(
                            fontSize: AppFont.label,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    InkWell(
                      onTap: onToggleDone,
                      borderRadius: BorderRadius.circular(6),
                      child: Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: done ? AppColors.primary : AppColors.textFaint,
                      ),
                    ),
                  ]),
                  const Gap(8),
                  Text(
                    slot.title,
                    style: TextStyle(
                      fontSize: AppFont.section,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: done ? AppColors.textFaint : AppColors.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (slot.hook.isNotEmpty) ...[
                    const Gap(4),
                    Text('“${slot.hook}”',
                        style: TextStyle(
                            fontSize: AppFont.body,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ],
                  const Gap(8),
                  Row(children: [
                    Icon(
                      onOpen != null
                          ? Icons.link_rounded
                          : Icons.insights_rounded,
                      size: 13,
                      color: AppColors.textFaint,
                    ),
                    const Gap(6),
                    Expanded(
                      child: onOpen != null
                          ? InkWell(
                              onTap: onOpen,
                              child: Text(
                                '${slot.src}  ↗',
                                style: const TextStyle(
                                    fontSize: AppFont.caption,
                                    color: AppColors.sky,
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                          : Text(slot.src,
                              style: const TextStyle(
                                  fontSize: AppFont.caption,
                                  color: AppColors.textFaint)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
