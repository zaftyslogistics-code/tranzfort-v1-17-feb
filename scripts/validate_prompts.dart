// Task 10.7: Prompt File Validation Script
// Run: dart run scripts/validate_prompts.dart
// Validates all JSON prompt files in assets/prompts/

import 'dart:convert';
import 'dart:io';

void main() {
  final promptsDir = Directory('assets/prompts');
  if (!promptsDir.existsSync()) {
    stderr.writeln('ERROR: assets/prompts/ directory not found');
    exit(1);
  }

  int totalFiles = 0;
  int errors = 0;
  int warnings = 0;
  final enFiles = <String>{};
  final hiFiles = <String>{};

  // Collect all JSON files
  final jsonFiles = promptsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  stdout.writeln('Validating ${jsonFiles.length} prompt files...\n');

  for (final file in jsonFiles) {
    totalFiles++;
    final relativePath = file.path.replaceAll('\\', '/');
    final fileName = relativePath.split('/').last;

    // Track locale files
    if (fileName.endsWith('_en.json')) {
      enFiles.add(relativePath.replaceAll('_en.json', ''));
    } else if (fileName.endsWith('_hi.json')) {
      hiFiles.add(relativePath.replaceAll('_hi.json', ''));
    }

    // 1. Validate JSON parses
    try {
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) {
        stderr.writeln('ERROR: $relativePath — empty file');
        errors++;
        continue;
      }

      final parsed = json.decode(content);

      // 2. Validate no empty string values
      _checkEmptyValues(relativePath, parsed, (msg) {
        stderr.writeln('WARNING: $relativePath — $msg');
        warnings++;
      });

      // 3. Check voice prompts word count (if in voice/ directory)
      if (relativePath.contains('/voice/')) {
        _checkVoiceWordCount(relativePath, parsed, (msg) {
          stderr.writeln('WARNING: $relativePath — $msg');
          warnings++;
        });
      }

      stdout.writeln('  OK  $relativePath');
    } on FormatException catch (e) {
      stderr.writeln('ERROR: $relativePath — invalid JSON: ${e.message}');
      errors++;
    } catch (e) {
      stderr.writeln('ERROR: $relativePath — $e');
      errors++;
    }
  }

  // 4. Check locale parity (every _en.json should have _hi.json and vice versa)
  stdout.writeln('\n--- Locale Parity Check ---');
  final enOnly = enFiles.difference(hiFiles);
  final hiOnly = hiFiles.difference(enFiles);

  for (final f in enOnly) {
    stderr.writeln('WARNING: ${f}_en.json has no Hindi counterpart');
    warnings++;
  }
  for (final f in hiOnly) {
    stderr.writeln('WARNING: ${f}_hi.json has no English counterpart');
    warnings++;
  }

  if (enOnly.isEmpty && hiOnly.isEmpty) {
    stdout.writeln('  All locale pairs matched.');
  }

  // 5. Check key parity between en/hi pairs
  stdout.writeln('\n--- Key Parity Check ---');
  for (final base in enFiles.intersection(hiFiles)) {
    final enFile = File('${base}_en.json');
    final hiFile = File('${base}_hi.json');
    if (!enFile.existsSync() || !hiFile.existsSync()) continue;

    try {
      final enData = json.decode(enFile.readAsStringSync());
      final hiData = json.decode(hiFile.readAsStringSync());

      if (enData is Map && hiData is Map) {
        final enKeys = (enData as Map<String, dynamic>).keys.toSet();
        final hiKeys = (hiData as Map<String, dynamic>).keys.toSet();
        final missingInHi = enKeys.difference(hiKeys);
        final missingInEn = hiKeys.difference(enKeys);

        for (final k in missingInHi) {
          stderr.writeln('WARNING: Key "$k" in ${base}_en.json missing from ${base}_hi.json');
          warnings++;
        }
        for (final k in missingInEn) {
          stderr.writeln('WARNING: Key "$k" in ${base}_hi.json missing from ${base}_en.json');
          warnings++;
        }
      }
    } catch (_) {}
  }

  // Summary
  stdout.writeln('\n========================================');
  stdout.writeln('Files checked: $totalFiles');
  stdout.writeln('Errors: $errors');
  stdout.writeln('Warnings: $warnings');
  stdout.writeln('========================================');

  if (errors > 0) {
    stderr.writeln('\nFAILED — $errors error(s) found');
    exit(1);
  } else if (warnings > 0) {
    stdout.writeln('\nPASSED with $warnings warning(s)');
  } else {
    stdout.writeln('\nPASSED — all prompts valid');
  }
}

void _checkEmptyValues(String path, dynamic data, void Function(String) warn) {
  if (data is Map) {
    for (final entry in data.entries) {
      if (entry.value is String && (entry.value as String).isEmpty) {
        warn('empty value for key "${entry.key}"');
      }
      _checkEmptyValues(path, entry.value, warn);
    }
  } else if (data is List) {
    for (var i = 0; i < data.length; i++) {
      _checkEmptyValues(path, data[i], warn);
    }
  }
}

void _checkVoiceWordCount(String path, dynamic data, void Function(String) warn) {
  if (data is Map) {
    for (final entry in data.entries) {
      if (entry.value is String) {
        final wordCount = (entry.value as String).split(RegExp(r'\s+')).length;
        if (wordCount > 15) {
          warn('voice prompt "${entry.key}" has $wordCount words (max 15)');
        }
      }
      _checkVoiceWordCount(path, entry.value, warn);
    }
  } else if (data is List) {
    for (final item in data) {
      _checkVoiceWordCount(path, item, warn);
    }
  }
}
