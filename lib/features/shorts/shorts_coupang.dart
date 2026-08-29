import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// 쿠팡파트너스 how-to — 해외 반응/제품 영상을 소스로 쇼츠·인스타·스레드에 올리고
/// 댓글/DM에 쿠팡 링크를 걸어 수수료를 버는 방법 정리.
const _coupang = Color(0xFFE94F37);

class CoupangGuide extends StatelessWidget {
  const CoupangGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 개념
        GlassCard(
          accent: _coupang,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.shopping_bag_rounded, size: 20, color: _coupang),
                Gap(8),
                Text('쿠팡파트너스란',
                    style: TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              ]),
              const Gap(10),
              const Text(
                '쿠팡 상품을 내 링크로 소개 → 누군가 그 링크로 사면 수수료를 받는 구조. '
                '해외 반응·제품 리뷰 영상을 소스로 쇼츠·인스타·스레드에 올리고, '
                '영상 속 제품의 쿠팡 링크를 댓글·DM·프로필에 걸어 클릭·구매를 유도한다.',
                style: TextStyle(fontSize: AppFont.body, height: 1.55, color: AppColors.textSecondary),
              ),
              const Gap(10),
              _note('필수: 게시물에 "이 포스팅은 쿠팡파트너스 활동의 일환으로 일정액의 수수료를 받습니다" 고지 문구를 넣어야 함.'),
            ],
          ),
        ),
        const Gap(14),

        // 플랫폼 3갈래
        _card('플랫폼 3갈래', Icons.hub_rounded, [
          _bullet('유튜브 쇼츠', '해외 제품 리뷰 영상을 소스로. 대본·녹음·편집 있는 정석 루틴(아래 4단계).'),
          _bullet('인스타 (소형소스)', '영상 여러 개(예: 5개)를 하나로 편집한 릴스. 소스 여러 개를 이어 붙인다.'),
          _bullet('스레드(Threads)', '영상 1 + 사진 1로 가장 간단. 글은 2~5줄. 자동DM 설정 필요 없음 → 진입 제일 쉬움.'),
        ]),
        const Gap(14),

        // 공통 워크플로우
        _card('공통 워크플로우 (7단계)', Icons.list_alt_rounded, [
          _step(1, '영상(소스) 찾기'),
          _step(2, '다운받기'),
          _step(3, '대본 쓰기'),
          _step(4, '녹음 + 이미지 소스'),
          _step(5, '편집'),
          _step(6, '업로드'),
          _step(7, '쿠팡 링크 달기(댓글·DM·프로필)'),
        ]),
        const Gap(14),

        // ① 소재
        _card('① 소재는 평상시 틈틈이', Icons.search_rounded, [
          _bullet('출퇴근·자투리 시간', '해외 제품 리뷰 영상을 찾아 저장해 둔다.'),
          _bullet('알고리즘 세팅', '좋아요·저장·팔로우를 적절히 하면 해외 영상이 계속 뜬다. 팔로우는 하루 10개씩 나눠서(몰아하면 봇 인식).'),
          _bullet('선별', '그 중 조회수 터진 것들만 골라 저장.'),
        ]),
        const Gap(14),

        // ② 루틴
        _card('② 하루엔 한 가지 일만', Icons.event_repeat_rounded, [
          _bullet('몰아서 하기', '대본 쓰는 날엔 대본만, 녹음날엔 녹음만, 편집날엔 한 번에. 쇼츠 소스는 1주일치를 한 번에 만든다.'),
          _routine(),
        ]),
        const Gap(14),

        // ③ 제품 링크 찾기
        _card('③ 영상 속 제품 쿠팡 링크 바로 찾기', Icons.center_focus_strong_rounded, [
          _bullet('검색어 몰라도 됨', '영상 속 제품이 나오게 캡처 → 구글에서 카메라(렌즈) 아이콘 클릭 → 이미지로 검색 → 제품 특정.'),
          _bullet('쿠팡에서 링크 생성', '찾은 제품을 쿠팡에서 검색 → 파트너스 링크 생성 → 게시물에 사용.'),
          _bullet('소스 다운로드', '스레드/인스타 영상·이미지 저장기 앱 사용 (다운로드 코드 thread2026 입력 시 무제한).'),
        ]),
        const Gap(14),

        // ④ 링크 거는 법
        _card('④ 링크 거는 법', Icons.link_rounded, [
          _bullet('쇼츠·인스타', '댓글(고정댓글)·프로필에 쿠팡 링크. 인스타는 자동DM 세팅도 가능.'),
          _bullet('스레드', '댓글에 쿠팡 링크. 자동DM 설정 불필요.'),
        ]),
        const Gap(14),

        // 시작하기
        _card('시작하기', Icons.flag_rounded, [
          _bullet('가입', 'partners.coupang.com 에서 쿠팡파트너스 가입.'),
          _bullet('링크 생성', '판매할 상품 검색 → 링크 생성 → 위 워크플로우대로 콘텐츠에 붙이기.'),
          _bullet('수익 확인', '클릭·구매 실적에 따라 수수료 정산.'),
        ]),
        const Gap(10),
        const Text(
          '※ 부자되는세상 강의 자료 정리 (쇼츠 4강 루틴 · 인스타 소형소스 · 스레드편). 원데이클래스 안내·댓글 내용은 제외.',
          style: TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) => GlassCard(
        accent: _coupang,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: _coupang),
              const Gap(8),
              Text(title,
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            ]),
            const Gap(12),
            ...children,
          ],
        ),
      );

  Widget _bullet(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: _coupang),
          ),
          const Gap(9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: AppFont.body,
                    color: AppColors.textSecondary,
                    height: 1.5),
                children: [
                  TextSpan(
                      text: '$k  ',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  TextSpan(text: v),
                ],
              ),
            ),
          ),
        ]),
      );

  Widget _step(int n, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _coupang.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: AppFont.micro,
                    fontWeight: FontWeight.w800,
                    color: _coupang)),
          ),
          const Gap(10),
          Text(label,
              style: const TextStyle(
                  fontSize: AppFont.body, color: AppColors.textPrimary)),
        ]),
      );

  Widget _routine() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            '예시 주간 루틴\n월 대본 · 화 녹음+편집 · 수 자막편집 · 목 영상편집 · 금 다음주 예약',
            style: TextStyle(
                fontSize: AppFont.label,
                color: AppColors.textSecondary,
                height: 1.6,
                fontWeight: FontWeight.w600),
          ),
        ),
      );

  Widget _note(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: _coupang.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _coupang.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.gavel_rounded, size: 14, color: _coupang),
          const Gap(8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textSecondary,
                    height: 1.45)),
          ),
        ]),
      );
}
