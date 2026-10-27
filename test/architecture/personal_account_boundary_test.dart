import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Personal account domain stays independent of outer frameworks', () {
    final domain = Directory('lib/modules/personal/domain');
    final violations = <String>[];
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
          violations.add('${file.path}: $forbidden');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
