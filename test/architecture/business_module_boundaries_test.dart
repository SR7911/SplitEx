import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = ['personal', 'group', 'room', 'project'];

  test('business domains stay independent of Flutter and persistence', () {
    final violations = <String>[];
    for (final module in modules) {
      final domain = Directory('lib/modules/$module/domain');
      for (final file in domain.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final forbidden in [
          'package:flutter/',
          'package:flutter_riverpod/',
          'package:cloud_firestore/',
          'package:firebase_',
          '/data/',
          '/presentation/',
        ]) {
          if (source.contains(forbidden)) {
            violations.add('${file.path} imports $forbidden');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('business presentations use contracts rather than data implementations', () {
    final violations = <String>[];
    for (final module in modules) {
      final presentation = Directory('lib/modules/$module/presentation');
      for (final file in presentation.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains('package:split_ex/modules/$module/data/') ||
            source.contains('../data/')) {
          violations.add(file.path);
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
