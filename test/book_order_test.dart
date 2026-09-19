// 책 순서 — 새 책이 «그 줄기의 마지막 다음» 번호를 받아야 한다.
// 전에는 전부 1 로 들어가 「1이 여러 개」가 됐다.
import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/models/models.dart';

Book book(String title, String branch, int order, {bool done = false}) => Book(
      id: title,
      category: '부동산',
      branch: branch,
      sortOrder: order,
      title: title,
      status: done ? 'done' : 'todo',
    );

/// books_screen 의 _BookDialog.nextOrder 와 같은 규칙.
int nextOrder(List<Book> siblings, String branch) =>
    siblings
        .where((b) => b.branch == branch)
        .fold<int>(0, (m, b) => b.sortOrder > m ? b.sortOrder : m) +
    1;

/// _renumber 가 매기는 번호 — 보이는 순서대로 1..N.
List<int> renumber(List<Book> branchBooks) =>
    [for (var i = 0; i < branchBooks.length; i++) i + 1];

/// 화면 정렬 — 번호가 같으면 제목으로 갈라 순서가 튀지 않게 한다.
List<Book> sorted(List<Book> bs) => [...bs]..sort((a, b) =>
    a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.title.compareTo(b.title));

void main() {
  group('새 책 번호', () {
    final have = [
      book('엑시트 EXIT', '입문', 1),
      book('부동산 계약 이렇게 쉬웠어?', '입문', 2),
      book('부동산 투자 이렇게 쉬웠어?', '입문', 3),
      book('경매 첫걸음', '경매', 1),
    ];

    test('빈 줄기는 1 부터', () {
      expect(nextOrder(have, '토지'), 1);
    });

    test('★ 책이 있는 줄기는 마지막 다음 — 1 이 아니다', () {
      expect(nextOrder(have, '입문'), 4);
    });

    test('줄기를 바꾸면 그 줄기 기준으로 다시 매긴다', () {
      expect(nextOrder(have, '경매'), 2);
    });

    test('연달아 넣어도 안 겹친다', () {
      final l = [...have];
      for (var i = 0; i < 3; i++) {
        final n = nextOrder(l, '입문');
        l.add(book('새 책 $i', '입문', n));
      }
      final ins = l.where((b) => b.branch == '입문').map((b) => b.sortOrder);
      expect(ins.toList(), [1, 2, 3, 4, 5, 6]);
      expect(ins.toSet().length, ins.length, reason: '겹치면 안 된다');
    });

    test('번호에 구멍이 있어도 최대값 다음 — 재사용하지 않는다', () {
      final l = [book('a', '입문', 1), book('b', '입문', 5)];
      expect(nextOrder(l, '입문'), 6);
    });
  });

  group('번호 정리', () {
    test('1 이 네 개여도 보이는 순서대로 1..N', () {
      final dup = sorted([
        book('데일카네기 자기관리론', '입문', 1),
        book('데일카네기 인간관계론', '입문', 1),
        book('엑시트 EXIT', '입문', 1, done: true),
        book('데일카네기 성공대화론', '입문', 1),
        book('부동산 계약 이렇게 쉬웠어?', '입문', 2),
        book('부동산 투자 이렇게 쉬웠어?', '입문', 3),
      ]);
      expect(renumber(dup), [1, 2, 3, 4, 5, 6]);
      expect(renumber(dup).toSet().length, 6);
    });

    test('정렬은 번호 → 제목 순 — 같은 번호끼리 순서가 튀지 않는다', () {
      final a = sorted([
        book('나', '입문', 1),
        book('가', '입문', 1),
        book('다', '입문', 1),
      ]);
      expect(a.map((b) => b.title).toList(), ['가', '나', '다']);
    });

    test('다 읽은 책도 번호에 포함된다 — 필터로 빼면 안 된다', () {
      final all = sorted([
        book('A', '입문', 1, done: true),
        book('B', '입문', 1),
        book('C', '입문', 1),
      ]);
      // 「읽을 것만」 이 켜져 있어도 정리는 전체(3권) 기준이어야 한다.
      expect(all.length, 3);
      expect(renumber(all), [1, 2, 3]);
    });
  });
}
