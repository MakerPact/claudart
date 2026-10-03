import 'package:test/test.dart';
import 'package:claudart/pipeline/pipeline_slot.dart';

void main() {
  test('PipelineSlot properties and isControl logic', () {
    expect(PipelineSlot.categorize.key, 'categorize');
    expect(PipelineSlot.categorize.isControl, isFalse);

    expect(PipelineSlot.plan.key, 'plan');
    expect(PipelineSlot.plan.isControl, isFalse);

    expect(PipelineSlot.question.key, '__question__');
    expect(PipelineSlot.question.isControl, isTrue);

    expect(PipelineSlot.flowExit.key, '__flow_exit__');
    expect(PipelineSlot.flowExit.isControl, isTrue);
  });
}
