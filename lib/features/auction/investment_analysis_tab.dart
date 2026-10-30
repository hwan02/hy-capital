import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/edit/field_spec.dart';
import '../../core/edit/record_form.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'investment_analysis.dart';
import 'investment_specs.dart';
import 'calc_fields.dart';

class InvestmentAnalysisTab extends ConsumerStatefulWidget {
  final AuctionProperty property;
  const InvestmentAnalysisTab({super.key, required this.property});
  @override
  ConsumerState<InvestmentAnalysisTab> createState() =>
      _InvestmentAnalysisTabState();
}

class _InvestmentAnalysisTabState extends ConsumerState<InvestmentAnalysisTab>
    with AutomaticKeepAliveClientMixin {
  InvestmentInputs? _draft;
  bool _saving = false, _dirty = false, _analyzing = false;
  String? _loadedId;
  String? _analysisError, _insight;
  @override
  bool get wantKeepAlive => true;

  InvestmentInputs get _initial {
    final p = widget.property;
    return InvestmentInputs({
      'bid': p.bidPrice > 0 ? p.bidPrice : p.minPrice,
      'deposit': p.deposit,
      'legal': 0.0,
      'takeover': 0.0,
      'capitalized': 0.0,
      'expenses': p.repairCost + p.evictionCost + p.otherCost,
      'reserve': 0.0,
      'sale_fee_pct': 0.0,
      'acq_pct': 0.0,
      'ordinary_pct': 0.0,
      'additional_pct': 0.0,
      'local_pct': 0.0,
      'cash': ref.read(profileProvider).asData?.value?.auctionBudget ?? 0.0,
      'credit': 0.0,
      'credit_confirmed': false,
      'credit_rate': 0.0,
      'mortgage': p.loanAmount,
      'mortgage_confirmed': false,
      'mortgage_rate': 0.0,
      'joint': 0.0,
      'joint_confirmed': false,
      'joint_rate': 0.0,
      'share': 100.0,
      'distribution_cost': 0.0,
      'target': p.targetProfit > 0 ? p.targetProfit : 30000000.0,
      'target_scope': 'own',
      'base_sale': p.expectedSalePrice,
      'low_sale': 0.0,
      'high_sale': 0.0,
      'low_months': 12.0,
      'base_months': 6.0,
      'high_months': 3.0,
      'tax_note': '',
      'market_note': '',
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(BuiltinSpec spec) async {
    if (_saving || _analyzing) return;
    final current = _draft ?? _initial;
    final values = await showRecordForm(
      context,
      title: spec.title,
      fields: spec.fields,
      initial: current.values,
      accent: spec.accent,
    );
    if (values == null || !mounted) return;
    setState(() {
      final evidence = Map<String, InvestmentEvidence>.from(current.evidence);
      final changed = values.entries.any(
        (e) => current.values[e.key] != e.value,
      );
      if (changed) {
        final keys = spec == investmentMarketSpec
            ? ['market', 'funding']
            : spec == investmentFundingSpec
            ? ['funding', 'tax']
            : ['tax', 'funding'];
        for (final key in keys) {
          final e = evidence[key];
          if (e?.status == 'pass') {
            evidence[key] = InvestmentEvidence(
              status: 'unknown',
              kind: e!.kind,
              source: e.source,
              checkedOn: e.checkedOn,
              detail: '가정 변경 후 재확인 필요. ${e.detail}',
            );
          }
        }
      }
      _draft = InvestmentInputs({...current.values, ...values}, evidence);
      _dirty = true;
    });
  }

  Future<void> _editEvidence(String key) async {
    if (_saving || _analyzing) return;
    final current = _draft ?? _initial;
    final values = await showRecordForm(
      context,
      title: investmentGates[key]!,
      fields: investmentEvidenceSpec.fields,
      initial: (current.evidence[key] ?? const InvestmentEvidence()).toMap(),
      accent: AppColors.violet,
    );
    if (values == null || !mounted) return;
    // 공통 날짜 폼은 DateTime을 반환할 수 있으므로 저장 표현을 정규화한다.
    if (values['checked_on'] is DateTime) {
      values['checked_on'] = (values['checked_on'] as DateTime)
          .toIso8601String();
    }
    setState(() {
      _draft = InvestmentInputs(current.values, {
        ...current.evidence,
        key: InvestmentEvidence.fromMap(values),
      });
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final input = _draft ?? _initial;
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      _notice('로그인 후 저장할 수 있어요');
      return;
    }
    setState(() => _saving = true);
    try {
      final row = await sb
          .from('calc_records')
          .insert({
            'user_id': uid,
            'label': '${widget.property.title} 종합분석',
            'inputs': {
              '_kind': 'investment',
              'property_id': widget.property.id,
              'analysis': input.toMap(),
              'report': _report(input),
            },
          })
          .select('id')
          .single();
      invalidateAll(ref);
      ref.invalidate(calcRecordsProvider);
      if (mounted) {
        setState(() {
          _dirty = false;
          _loadedId = row['id'] as String;
        });
      }
      _notice('새 분석 버전이 저장됐어요. 이전 분석은 보존됩니다');
    } catch (_) {
      _notice('분석 저장에 실패했어요. 입력은 유지됩니다. 다시 시도하세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _report(InvestmentInputs i) {
    final p = widget.property, now = DateTime.now();
    final d = analyzeInvestment(i, now);
    final out = StringBuffer(
      '# ${p.title} 종합분석\n'
      '${p.court ?? "법원 미확인"} / ${p.caseNo ?? "사건 미확인"} / ${p.address ?? "주소 미확인"}\n'
      '작성 ${now.toIso8601String()} · 계산 버전 $investmentVersion\n'
      '판정: ${d.verdict}\n입찰가: ${Won.compact(i.bid)}원\n'
      '목표: ${i.values["target_scope"] == "project" ? "물건 전체" : "본인 배분 후"} ${Won.compact(i.target)}원\n\n',
    );
    if (i.errors.isEmpty) {
      for (final s in {'low': '보수적', 'base': '기준', 'high': '공격적'}.entries) {
        final r = calculateInvestment(i, s.key);
        out.writeln(
          '${s.value}: 매도 ${Won.compact(r.sale)}원 / ${r.months}개월 / '
          '물건 순익 ${Won.compact(r.projectProfit)}원 / 본인 여유 ${Won.compact(r.ownProfit)}원 / '
          '최대현금 ${Won.compact(r.peakCash)}원 / 부족 ${Won.compact(r.fundingGap)}원',
        );
      }
      if (d.limit != null) {
        out.writeln('가정상 기준 상한 ${Won.compact(d.limit!)}원 (미확인 해결 전 실행 불가)');
      }
    }
    if (_insight != null) out.writeln('\n## 자료 분석 의견\n$_insight');
    out.writeln('\n## 다음 행동');
    for (final a in d.actions) {
      out.writeln('- $a');
    }
    out.writeln('\n## 근거');
    for (final g in investmentGates.entries) {
      final e = i.evidence[g.key] ?? const InvestmentEvidence();
      out.writeln(
        '- ${g.value}: ${e.status} / ${e.kind} / ${e.source} / '
        '${e.checkedOn?.toIso8601String() ?? "날짜 없음"}\n  ${e.detail}',
      );
    }
    out.writeln(
      '\n세금 가정: ${i.values["tax_note"] ?? ""}\n'
      '시세 가정: ${i.values["market_note"] ?? ""}\n'
      '자금 승인·매도 시점·장부 처리에 따라 달라지는 비교 모형. '
      '본인 여유는 배분 후 개인이자·개인출금 추정비·예비잔고를 차감한 값. '
      '전세금은 잔금 재원에 포함하지 않음. 자동 법원 조회·현장 확인 완료를 뜻하지 않음.',
    );
    return out.toString();
  }

  Future<void> _copy(bool request) async {
    final i = _draft ?? _initial, p = widget.property;
    final contextData = request ? await _researchContext() : const {};
    final content = request
        ? '다음 경매 물건을 기존 투자전략에 따라 원문 조사하고 종합분석해주세요.\n'
              '물건ID: ${p.id}\n법원: ${p.court ?? "미확인"}\n사건: ${p.caseNo ?? "미확인"}\n'
              '주소/호수: ${p.address ?? "미확인"} / ${p.title}\n'
              '최저가 ${p.minPrice}원, 감정가 ${p.appraisalPrice}원, 기일 ${p.bidDate ?? "미확인"}\n'
              '기존 메모: ${p.memo ?? ""}\n등록 사진: ${p.images.length}장 (원본은 앱 물건 사진 참조)\n'
              '공식 권리·필지/사업블록·승계·동일면적 실거래·세금·승인자금·본인몫을 대조하세요. '
              '미확인과 가정을 사실로 바꾸지 말고 출처·확인일·조건을 남기세요. '
              '아래 JSON의 property_id/version을 유지하고 analysis의 values/evidence를 보완해 반환하세요. '
              '근거 gate key는 ${investmentGates.keys.join(", ")}, '
              '상태는 unknown/pass/fail, 근거는 status/kind/source/checked_on/detail입니다.\n\n'
              '${const JsonEncoder.withIndent("  ").convert({"property_id": p.id, "analysis": i.toMap(), "existing_context": contextData})}'
        : _report(i);
    await Clipboard.setData(ClipboardData(text: content));
    _notice(request ? '조사 요청문을 복사했어요. Buzz 대화에 붙여넣으세요' : '분석 결과를 복사했어요');
  }

  /// 자료실과 단지에 쌓인 조사를 다시 입력시키지 않는다. 매칭은 참고이며
  /// 블록 편입·가격 확인으로 승격하지 않고 원래 출처/조사일을 함께 넘긴다.
  Future<Map<String, dynamic>> _researchContext() async {
    final result = <String, dynamic>{};
    try {
      final surveys = await ref.read(latestSurveysProvider.future);
      final survey = surveys[widget.property.complexId];
      result['price_survey'] = survey == null
          ? null
          : {
              'surveyed_on': survey.surveyedOn.toIso8601String(),
              'sources': survey.sources.map((s) => s.toMap()).toList(),
              'memo': survey.memo,
            };
    } catch (_) {
      result['price_survey_error'] = '기존 시세조사 조회 실패';
    }
    try {
      final zones = await ref.read(zonesProvider.future);
      final complexes = await ref.read(complexesProvider.future);
      final complex = complexes
          .where((c) => c.id == widget.property.complexId)
          .firstOrNull;
      final zone = zones.where((z) => z.id == complex?.zoneId).firstOrNull;
      result['zone_hint_not_parcel_confirmation'] = zone == null
          ? null
          : {
              'name': zone.name,
              'kind': zone.kind,
              'stage': zone.stage,
              'stage_source': zone.stageSource,
              'checked_at': zone.stageCheckedAt?.toIso8601String(),
              'rights_date': zone.rightsDate?.toIso8601String(),
              'subs': zone.subs,
              'docs': zone.docs,
              'memo': zone.memo,
            };
    } catch (_) {
      result['zone_error'] = '기존 구역 자료 조회 실패';
    }
    try {
      final notes = await ref.read(knowledgeProvider.future);
      final relevant = notes
          .where(
            (n) => RegExp('투자전략|패스기준|복제.*판정|법인.*단기|권리산정|취득세').hasMatch(n.title),
          )
          .take(10);
      result['strategy_notes_not_current_law'] = [
        for (final n in relevant)
          {
            'title': n.title,
            'body': (n.body ?? '').length > 8000
                ? n.body!.substring(0, 8000)
                : n.body,
            'source': n.source,
            'url': n.url,
            'source_date': n.sourceDate?.toIso8601String(),
          },
      ];
    } catch (_) {
      result['knowledge_error'] = '자료실 조회 실패';
    }
    result['property_checks'] = widget.property.checks;
    result['property_checklist'] = widget.property.checklist;
    result['current_funding_note'] =
        '이 분석의 자금 입력이 과거 전략 메모보다 우선합니다. 가능 금액을 승인 금액으로 취급하지 마세요.';
    return result;
  }

  Future<void> _import() async {
    if (_saving || _analyzing) return;
    final result = await showRecordForm(
      context,
      title: 'Buzz 조사 결과 가져오기',
      fields: const [
        FieldSpec(
          key: 'json',
          label: '조사 결과 JSON',
          type: FieldType.longtext,
          required: true,
          minLines: 10,
        ),
      ],
    );
    if (result == null || !mounted) return;
    try {
      final data = jsonDecode(result['json'] as String) as Map<String, dynamic>;
      if (data['property_id'] != widget.property.id) {
        throw const FormatException('다른 물건 결과예요. 물건ID를 확인하세요');
      }
      final input = InvestmentInputs.fromMap(
        Map<String, dynamic>.from(data['analysis'] as Map),
      );
      // 결과를 곧바로 저장/추천하지 않는다. 불러온 가정과 근거를 화면에서 검토한다.
      for (final e in input.values.entries) {
        if (e.value is num && !(e.value as num).isFinite) {
          throw const FormatException('금액 형식 오류');
        }
      }
      setState(() {
        _draft = input;
        _dirty = true;
      });
      _notice('조사 결과를 불러왔어요. 가정과 출처를 확인하고 새 버전으로 저장하세요');
    } on FormatException catch (e) {
      _notice('가져오기 실패: ${e.message}');
    } catch (_) {
      _notice('결과 형식이 맞지 않아요. 조사 요청문의 JSON 형식을 사용하세요');
    }
  }

  Future<void> _requestAnalysis() async {
    final current = _draft ?? _initial;
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });
    try {
      final response = await ref
          .read(supabaseProvider)
          .functions
          .invoke(
            'auction-analysis',
            body: {
              'property_id': widget.property.id,
              'analysis': current.toMap(),
            },
          )
          .timeout(const Duration(seconds: 100));
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['property_id'] != widget.property.id ||
          data['analysis'] is! Map) {
        throw const FormatException('다른 물건 또는 지원하지 않는 분석 응답');
      }
      final llmStatus = data['llm_status'] as String?;
      final insight = data['insight'] as String?;
      final candidate = InvestmentInputs.fromMap(
        Map<String, dynamic>.from(data['analysis'] as Map),
      );
      // AI는 자금 승인을 내릴 수 없다. 실행 조건/본인 약정은 사용자 확인값 유지.
      final values = Map<String, dynamic>.from(candidate.values);
      for (final key in [
        'cash',
        'credit',
        'credit_confirmed',
        'credit_rate',
        'mortgage',
        'mortgage_confirmed',
        'mortgage_rate',
        'joint',
        'joint_confirmed',
        'joint_rate',
        'share',
        'target',
        'target_scope',
        'distribution_cost',
      ]) {
        values[key] = current.values[key];
      }
      final evidence = <String, InvestmentEvidence>{};
      for (final key in investmentGates.keys) {
        final e = candidate.evidence[key] ?? const InvestmentEvidence();
        // 서버 모델의 출처 주장만으로 확인 완료/입찰 추천이 되지 않는다.
        // 기존에 확인한 근거는 보존하고 새로 제안된 통과는 검토 대기로 받는다.
        evidence[key] = e.status == 'pass'
            ? current.evidence[key] ??
                  InvestmentEvidence(
                    status: 'unknown',
                    kind: e.kind,
                    source: e.source,
                    detail: e.detail,
                    checkedOn: e.checkedOn,
                  )
            : e;
      }
      if (!mounted) return;
      setState(() {
        _draft = InvestmentInputs(values, evidence);
        _dirty = true;
        _insight = insight;
        if (llmStatus == 'not_configured') {
          _analysisError = '서버 AI 설정이 없어 자료 정리만 수행했습니다. Buzz 원문 조사를 이용할 수 있어요.';
        }
        if (llmStatus == 'failed') {
          _analysisError = '서버 AI 응답에 실패해 자료 정리 결과만 표시합니다. 기존 자금 승인값은 보존했어요.';
        }
      });
      _notice('자료 분석을 불러왔어요. 새 근거는 확인 대기이며 자금 승인값은 유지했어요');
    } catch (_) {
      if (mounted) {
        setState(
          () => _analysisError =
              '서버 자료 분석을 완료하지 못했어요. 함수 배포·서버 설정·로그인 상태를 확인하거나 Buzz 조사 요청을 사용하세요. 기존 초안은 유지됩니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final history = ref.watch(calcRecordsProvider);
    final records = (history.asData?.value ?? <CalcRecord>[])
        .where(
          (r) =>
              r.kind == 'investment' &&
              r.inputs['property_id'] == widget.property.id,
        )
        .toList();
    // 최초 로드 한 번만. 새로고침/저장 응답이 편집 중 초안을 덮지 않는다.
    if (_draft == null && history.hasValue) {
      if (records.isNotEmpty) {
        try {
          _draft = InvestmentInputs.fromMap(
            Map<String, dynamic>.from(records.first.inputs['analysis'] as Map),
          );
          _loadedId = records.first.id;
          _insight = records.first.inputs['insight'] as String?;
        } catch (_) {
          _draft = _initial;
        }
      } else {
        _draft = _initial;
      }
    }
    final i = _draft ?? _initial,
        decision = analyzeInvestment(_draft ?? _initial, DateTime.now());
    final color = decision.verdict == '제외'
        ? AppColors.rose
        : decision.verdict == '입찰 검토'
        ? AppColors.primary
        : AppColors.gold;
    return ModulePage(
      title: '종합분석',
      icon: Icons.analytics_rounded,
      color: AppColors.violet,
      subtitle: '물건별 근거 → 수익·자금 시나리오 → 다음 행동',
      children: [
        if (history.isLoading) const LinearProgressIndicator(),
        if (history.hasError) const Text('분석 이력을 불러오지 못했어요. 새로고침 후 다시 확인하세요.'),
        const Text(
          '외부 원문 조사는 Buzz와 연결해 진행합니다. '
          '확인되지 않은 매도가·세율·대출은 가정이며, 앱이 자동 조회한 사실이 아닙니다.',
          style: TextStyle(
            fontSize: AppFont.label,
            color: AppColors.textSecondary,
          ),
        ),
        const Gap(12),
        if (_insight != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _insight!,
              style: const TextStyle(fontSize: AppFont.body),
            ),
          ),
        if (_analysisError != null)
          Text(
            _analysisError!,
            style: const TextStyle(
              fontSize: AppFont.label,
              color: AppColors.rose,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _analyzing || _saving ? null : _requestAnalysis,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_analyzing ? '자료 분석 중…' : '사진·원문 자료 분석'),
            ),
            FilledButton.icon(
              onPressed:
                  history.isLoading || history.hasError || _saving || _analyzing
                  ? null
                  : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? '저장 중' : '새 분석 버전 저장'),
            ),
            OutlinedButton(
              onPressed: () => _copy(true),
              child: const Text('Buzz 조사 요청 복사'),
            ),
            OutlinedButton(
              onPressed: _saving || _analyzing ? null : _import,
              child: const Text('조사 결과 가져오기'),
            ),
            OutlinedButton(
              onPressed: () => _copy(false),
              child: const Text('결과 복사'),
            ),
          ],
        ),
        Text(
          _dirty
              ? '저장하지 않은 변경이 있어요'
              : _loadedId == null
              ? '새 분석 초안'
              : '저장된 분석을 불러왔어요',
          style: const TextStyle(
            fontSize: AppFont.caption,
            color: AppColors.textSecondary,
          ),
        ),
        const Gap(16),
        GlassCard(
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Pill(decision.verdict, color: color),
              const Gap(8),
              for (final action in decision.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $action',
                    style: const TextStyle(fontSize: AppFont.label),
                  ),
                ),
              if (decision.actions.isEmpty)
                const Text('입찰 전 최신 원문과 현장을 다시 확인하세요.'),
            ],
          ),
        ),
        const Gap(16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final spec in [
              investmentCostSpec,
              investmentFundingSpec,
              investmentMarketSpec,
            ])
              OutlinedButton(
                onPressed: _saving || _analyzing ? null : () => _edit(spec),
                child: Text(spec.title),
              ),
          ],
        ),
        const Gap(12),
        Text(
          '확정 자기현금 ${Won.compact(i.n("cash"))}원 · '
          '승인 포함 총재원 ${Won.compact(i.funds)}원\n'
          '대출·공투는 확정 스위치를 켠 금액만 반영합니다. 세금 미입력0%는 면제가 아닙니다.',
          style: const TextStyle(fontSize: AppFont.label),
        ),
        const Gap(16),
        if (i.errors.isEmpty) ...[
          for (final scenario in {
            'low': '보수적',
            'base': '기준',
            'high': '공격적',
          }.entries)
            _scenarioCard(scenario.value, calculateInvestment(i, scenario.key)),
          if (decision.limit != null)
            GlassCard(
              child: Column(
                children: [
                  calcRow('가정상 수익 상한', decision.profitLimit!),
                  calcRow('가정상 자금 상한', decision.cashLimit!),
                  calcRow('둘 중 낮은 기준 상한', decision.limit!, strong: true),
                  const Text(
                    '기준 시나리오의 비교값. 보류·미확인 해결 전 실행 상한이 아닙니다.',
                    style: TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const Gap(20),
        const SectionHeader('조사 근거와 남은 확인'),
        const Text(
          '통과는 출처·내용·30일 이내 확인일이 있어야 반영됩니다. 부적합은 자동 해제되지 않습니다.',
          style: TextStyle(
            fontSize: AppFont.caption,
            color: AppColors.textSecondary,
          ),
        ),
        for (final g in investmentGates.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              g.value,
              style: const TextStyle(fontSize: AppFont.body),
            ),
            subtitle: Text(
              _evidenceLabel(i.evidence[g.key]),
              style: const TextStyle(fontSize: AppFont.caption),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _saving || _analyzing ? null : () => _editEvidence(g.key),
          ),
        const Gap(16),
        const SectionHeader('물건별 분석 이력'),
        for (final r in records)
          ListTile(
            title: Text(
              r.createdAt.toLocal().toString().substring(0, 16),
              style: const TextStyle(fontSize: AppFont.label),
            ),
            subtitle: Text(
              r.id == _loadedId ? '불러온 버전' : '이전 가정·근거를 불러오기',
              style: const TextStyle(fontSize: AppFont.caption),
            ),
            onTap: _dirty || _saving || _analyzing
                ? null
                : () {
                    try {
                      final v = InvestmentInputs.fromMap(
                        Map<String, dynamic>.from(r.inputs['analysis'] as Map),
                      );
                      setState(() {
                        _draft = v;
                        _loadedId = r.id;
                        _insight = r.inputs['insight'] as String?;
                      });
                    } catch (_) {
                      _notice('이력 형식을 읽을 수 없어요');
                    }
                  },
          ),
        if (records.isEmpty) const Text('저장하면 가정과 근거를 함께 보존합니다.'),
      ],
    );
  }

  String _evidenceLabel(InvestmentEvidence? e) {
    if (e == null) return '미확인';
    final state = e.status == 'fail'
        ? '부적합'
        : e.verified(DateTime.now())
        ? '확인·통과'
        : '재확인 필요';
    return '$state · ${e.kind}\n${e.source}\n${e.detail}';
  }

  Widget _scenarioCard(String label, InvestmentScenario r) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$label · ${r.months.toStringAsFixed(0)}개월',
            style: const TextStyle(
              fontSize: AppFont.section,
              fontWeight: FontWeight.w700,
            ),
          ),
          calcRow('매도가 가정', r.sale),
          calcRow('취득원가·인수비용', r.costBasis),
          calcRow('일반 법인세·지방세 비교', r.ordinaryTax),
          calcRow('주택 추가과세·지방세 비교', r.additionalTax),
          calcRow('법인 금융비용', r.corporateInterest),
          calcRow('물건 전체 순익', r.projectProfit),
          calcRow('공투자 세후 우선배분 (이익 한도)', r.jointPreferredProfit),
          calcRow('본인 신용이자', r.personalInterest),
          calcRow(
            '본인 배분·비용·예비 차감 후',
            r.ownProfit,
            strong: true,
            color: r.ownProfit < 0 ? AppColors.rose : AppColors.primary,
          ),
          calcRow('매도 전 최대 필요현금', r.peakCash),
          calcRow(
            '승인재원 대비 부족',
            r.fundingGap,
            color: r.fundingGap > 0 ? AppColors.rose : null,
          ),
          calcRow('입찰일 보증금 현금 부족', r.depositGap),
        ],
      ),
    ),
  );
}
