// classification_routing_test.dart — verifies SuggestSteps.reasoner and
// DebugSteps.implementer's modelSelectors actually wire the categorize
// output to the τ matrix, mirroring plan_step_routing_test.dart's
// coverage of FlowSteps.plan for the suggest/debug pipelines.
//
// Two paths per step:
//   gui × design categorize   → opus (the routing this feature exists for)
//   missing / empty categorize → fallback sonnet (pre-existing default,
//                                 so an older handoff with no
//                                 ## Classification section behaves
//                                 exactly as before this feature)

import 'package:claudart/pipeline/agent_model.dart';
import 'package:claudart/pipeline/agents/categorization.dart';
import 'package:claudart/pipeline/flows/debug_steps.dart';
import 'package:claudart/pipeline/flows/suggest_steps.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:test/test.dart';

const _projectRoot = '/tmp/test-project';
const _bug = 'a real task';
const _expected = 'should work';

PipelineContext _baseCtx() => const PipelineContext(
      projectRoot: _projectRoot,
      bug: _bug,
      expected: _expected,
      files: [],
    );

PipelineContext _ctxWithCategorize(String categorizeOutput) =>
    _baseCtx().withSlot(PipelineSlot.categorize, categorizeOutput);

String _categorize({
  required AgentCategory category,
  required IntentClass intent,
  required ComplexityTier complexity,
}) =>
    '<${CategorizeTag.category.wireTag}>${category.name}</${CategorizeTag.category.wireTag}>\n'
    '<${CategorizeTag.intent.wireTag}>${intent.name}</${CategorizeTag.intent.wireTag}>\n'
    '<${CategorizeTag.complexity.wireTag}>${complexity.name}</${CategorizeTag.complexity.wireTag}>\n';

final _guiDesign = _categorize(
  category: AgentCategory.gui,
  intent: IntentClass.design,
  complexity: ComplexityTier.systemic,
);

void main() {
  group('SuggestSteps.reasoner — modelSelector', () {
    test('gui × design categorize routes to opus', () {
      final ctx = _ctxWithCategorize(_guiDesign);
      expect(SuggestSteps.reasoner.effectiveModel(ctx), equals(AgentModel.opus));
    });

    test('degrades to sonnet when categorize slot is empty', () {
      expect(SuggestSteps.reasoner.effectiveModel(_baseCtx()),
          equals(AgentModel.sonnet));
    });

    test('degrades to sonnet on malformed categorize output', () {
      final ctx = _ctxWithCategorize('garbage with no xml tags');
      expect(SuggestSteps.reasoner.effectiveModel(ctx), equals(AgentModel.sonnet));
    });
  });

  group('DebugSteps.implementer — modelSelector', () {
    test('gui × design categorize (seeded from a persisted handoff) routes to opus', () {
      final ctx = _ctxWithCategorize(_guiDesign);
      expect(DebugSteps.implementer.effectiveModel(ctx), equals(AgentModel.opus));
    });

    test('degrades to sonnet when categorize slot is empty (no Classification section)', () {
      expect(DebugSteps.implementer.effectiveModel(_baseCtx()),
          equals(AgentModel.sonnet));
    });

    test('degrades to sonnet on the "_Not yet determined._" placeholder text', () {
      final ctx = _ctxWithCategorize('_Not yet determined._');
      expect(DebugSteps.implementer.effectiveModel(ctx), equals(AgentModel.sonnet));
    });
  });
}
