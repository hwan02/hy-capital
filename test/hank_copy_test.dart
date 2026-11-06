import 'package:flutter_test/flutter_test.dart';
import 'package:hy_capital/features/auction/sale_calendar_view.dart';

void main() {
  test('경매는 연도 빼고 번호만', () {
    expect(hankCopyOf('2025타경9749'), (text: '9749', year: '2025'));
    expect(hankCopyOf(' 2024 타경 102285 '), (text: '102285', year: '2024'));
    expect(hankCopyOf('2025타경9749(2)').text, '9749');
  });
  test('공매는 전부', () {
    expect(hankCopyOf('2026-10740-004'), (text: '2026-10740-004', year: null));
  });
}
