import 'package:test/test.dart';
import 'package:claudart/pipeline/agent_model.dart';

void main() {
  test('AgentModel properties and tier', () {
    expect(AgentModel.haiku.alias, 'haiku');
    expect(AgentModel.haiku.tier, ModelTier.fast);

    expect(AgentModel.sonnet.alias, 'sonnet');
    expect(AgentModel.sonnet.tier, ModelTier.balanced);

    expect(AgentModel.opus.alias, 'opus');
    expect(AgentModel.opus.tier, ModelTier.capable);

    expect(AgentModel.fable.alias, 'fable');
    expect(AgentModel.fable.tier, ModelTier.capable);
  });

  test('AgentModel fromAlias parses correctly', () {
    expect(AgentModel.fromAlias('haiku'), AgentModel.haiku);
    expect(AgentModel.fromAlias('sonnet'), AgentModel.sonnet);
    expect(AgentModel.fromAlias('opus'), AgentModel.opus);
    expect(AgentModel.fromAlias('fable'), AgentModel.fable);
    expect(AgentModel.fromAlias('unknown'), isNull);
  });

  test('AgentModel fromSlug parses correctly', () {
    expect(AgentModel.fromSlug('claude-haiku-4-5-20251001'), AgentModel.haiku);
    expect(AgentModel.fromSlug('claude-sonnet-5'), AgentModel.sonnet);
    expect(AgentModel.fromSlug('claude-opus-5-5'), AgentModel.opus);
    expect(AgentModel.fromSlug('claude-fable-5-1'), AgentModel.fable);
    expect(AgentModel.fromSlug('unknown-slug'), isNull);
  });

  test('AgentModel bestFor properties', () {
    expect(AgentModel.haiku.bestForLookup, isTrue);
    expect(AgentModel.sonnet.bestForLookup, isFalse);

    expect(AgentModel.sonnet.bestForAnalysis, isTrue);
    expect(AgentModel.haiku.bestForAnalysis, isFalse);

    expect(AgentModel.opus.bestForExplore, isTrue);
    expect(AgentModel.fable.bestForExplore, isFalse);
  });

  test('ModelTier label', () {
    expect(ModelTier.fast.label, 'fast');
    expect(ModelTier.balanced.label, 'balanced');
    expect(ModelTier.capable.label, 'capable');
  });
}
