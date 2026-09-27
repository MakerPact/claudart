// handoff_expectation.dart — what a HandoffStatus tells the user to run next
//
// The "feature" axis for handoff_status_matrix.dart. Each HandoffStatusType
// variant declares which of these it participates in.

import 'package:dartrix/dartrix.dart';

enum HandoffExpectation implements FeatureType {
  suggest(description: 'Status expects /suggest to run next'),
  debug(description: 'Status expects /debug to run next');

  const HandoffExpectation({required this.description});

  @override
  final String description;
}
