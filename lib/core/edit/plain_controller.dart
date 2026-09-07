// 한글 «조합 중» 밑줄을 안 그리는 텍스트 컨트롤러.
//
// Flutter 는 IME 로 아직 확정되지 않은 글자(조합 중)에 밑줄을 그린다.
// EditableText 가 controller.buildTextSpan() 을 부르고, 기본 구현이
// 조합 구간에만 TextDecoration.underline 을 얹기 때문이다
// (flutter/lib/src/widgets/editable_text.dart 의 buildTextSpan).
//
// 한글은 한 글자를 칠 때마다 초성·중성·종성이 «계속» 조합 상태를 지나므로,
// 영문과 달리 타이핑하는 내내 밑줄이 따라다녀 글자가 지저분해 보인다.
// 그 문서가 「Descendants can override this method」라고 열어둔 자리다.
//
// 앱의 모든 입력칸은 TextEditingController 대신 이걸 쓴다.
// 타입은 그대로 TextEditingController 로 받으면 된다(하위 타입).
import 'package:flutter/widgets.dart';

class PlainController extends TextEditingController {
  PlainController({super.text});
  PlainController.fromValue(super.value) : super.fromValue();

  /// 조합 구간을 특별히 꾸미지 않는다 — 밑줄 없음.
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => TextSpan(style: style, text: text);
}
