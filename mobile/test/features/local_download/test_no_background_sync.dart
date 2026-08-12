import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Local Download — no background sync', () {
    test('feature code contains zero background-scheduling primitives', () {
      // Local Download is a pull-on-demand mechanism only (blueprint §6.5):
      // nothing in the feature may ever automatically trigger itself in the
      // background. This is a structural property, so a grep-style static
      // assertion over the feature source is the right check.
      const featureDir = 'lib/features/local_download';
      final dir = Directory(featureDir);
      expect(dir.existsSync(), isTrue,
          reason: 'feature directory must exist');

      final dartFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(dartFiles, isNotEmpty,
          reason: 'feature must contain Dart source files to check');

      const forbiddenPatterns = [
        'Timer(',
        'Timer.periodic',
        'WorkManager',
        'BackgroundFetch',
        'scheduleTask',
        'setInterval',
      ];

      final offenders = <String>[];
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          if (content.contains(pattern)) {
            offenders.add('${file.path}: contains "$pattern"');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Local Download must be pull-on-demand only; '
            'no background scheduling may exist in the feature:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
