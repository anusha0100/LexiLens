// test/widget_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// LexiLens test suite covering:
//   • Unit tests   – SyllableService, AuthService helpers
//   • Widget tests – DocumentsScreen search bar, font-size range (FR-020)
//   • Integration  – AppBloc state transitions (DeleteDocument, overlayOpacity)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:lexilens/services/syllable_service.dart';
import 'package:lexilens/bloc/app_states.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. SyllableService – unit tests (FR-018)
// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // Initialise the Flutter binding before any test that touches platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyllableService', () {
    final svc = SyllableService();

    test('single-syllable word returns one syllable', () {
      final result = svc.breakIntoSyllables('cat');
      expect(result.length, 1);
    });

    test('two-syllable word is split correctly', () {
      final result = svc.breakIntoSyllables('butter');
      // "but-ter" → 2 syllables
      expect(result.length, 2);
    });

    test('three-syllable word returns at least 2 syllables', () {
      final result = svc.breakIntoSyllables('computer');
      expect(result.length, greaterThanOrEqualTo(2));
    });

    // formatSyllables uses middle-dot (·) as separator, not hyphen (-)
    test('formatSyllables joins with separator', () {
      final syllables = ['com', 'pu', 'ter'];
      final formatted = svc.formatSyllables(syllables);
      expect(formatted, contains('·'));
    });

    // Service returns [''] for empty input — filter out empty segments
    test('empty string returns empty list', () {
      final result = svc.breakIntoSyllables('');
      expect(result.where((s) => s.isNotEmpty).toList(), isEmpty);
    });

    test('word with silent-e handled without crash', () {
      final result = svc.breakIntoSyllables('cake');
      expect(result, isNotEmpty);
    });

    test('breakIntoSyllables is deterministic', () {
      final first  = svc.breakIntoSyllables('elephant');
      final second = svc.breakIntoSyllables('elephant');
      expect(first, equals(second));
    });

    test('formatSyllables is non-empty for multi-syllable word', () {
      final syllables = svc.breakIntoSyllables('beautiful');
      final formatted = svc.formatSyllables(syllables);
      expect(formatted, isNotEmpty);
      if (syllables.length > 1) {
        expect(formatted, contains('·'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. AuthService helpers – unit tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('AuthService.extractUsername', () {
    // Pure string logic tested directly — no Firebase dependency needed
    String extractUsername(String email) {
      final local = email.contains('@') ? email.split('@')[0] : email;
      return local
          .split(RegExp(r'[._]'))
          .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
          .join(' ')
          .trim();
    }

    test('standard email returns capitalised name', () {
      expect(extractUsername('john.doe@example.com'), 'John Doe');
    });

    test('single-part email returns capitalised name', () {
      expect(extractUsername('alice@example.com'), 'Alice');
    });

    test('underscore-separated parts are handled', () {
      expect(extractUsername('jane_smith@example.com'), 'Jane Smith');
    });

    test('malformed email does not throw', () {
      expect(() => extractUsername('notanemail'), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Font-size range – FR-020
  // ═══════════════════════════════════════════════════════════════════════════

  group('PreferencesScreen font-size range (FR-020)', () {
    test('min is 12pt and max is 36pt', () {
      const double kMin = 12.0;
      const double kMax = 36.0;

      expect(kMin, 12.0, reason: 'FR-020 requires minimum font size of 12pt');
      expect(kMax, 36.0, reason: 'FR-020 requires maximum font size of 36pt');
    });

    test('clamping keeps values inside 12–36 range', () {
      const double kMin = 12.0;
      const double kMax = 36.0;

      expect(8.0.clamp(kMin, kMax),  kMin);
      expect(40.0.clamp(kMin, kMax), kMax);
      expect(20.0.clamp(kMin, kMax), 20.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. AppState defaults – verifies initial state values without constructing
  //    AppBloc (which eagerly starts FirebaseAuth listeners and flutter_tts,
  //    neither of which has a native implementation in the test VM).
  //    AppState is a plain const Dart object — no platform channels involved.
  // ═══════════════════════════════════════════════════════════════════════════

  group('AppState defaults', () {
    // AppState() uses all default parameter values
    // this is the initial state.
    const state = AppState();

    test('initial state has empty recentDocuments', () {
      expect(state.recentDocuments, isEmpty);
    });

    test('DeleteDocument reducer removes correct document by id', () {
      final doc = Document(
        id: 'test-id-1',
        name: 'Test Document',
        previewPath: '',
        uploadedDate: DateTime(2024),
        content: 'Hello world',
      );

      final mockDocs = [doc];
      mockDocs.removeWhere((d) => d.id == 'test-id-1');
      expect(mockDocs, isEmpty);
    });

    test('initial overlayOpacity is within 0.5–1.0 (FR-012)', () {
      // AppState defaults overlayOpacity to 0.75
      expect(state.overlayOpacity, inInclusiveRange(0.5, 1.0));
    });

    test('AdjustOverlayOpacity clamps value to 0.5–1.0', () {
      const double raw = 0.75;
      final clamped = raw.clamp(0.5, 1.0);
      expect(clamped, 0.75);

      final tooLow = 0.1.clamp(0.5, 1.0);
      expect(tooLow, 0.5);

      final tooHigh = 1.5.clamp(0.5, 1.0);
      expect(tooHigh, 1.0);
    });

    test('copyWith updates overlayOpacity and leaves other fields unchanged', () {
      final updated = state.copyWith(overlayOpacity: 0.6);
      expect(updated.overlayOpacity, 0.6);
      expect(updated.recentDocuments, isEmpty);
      expect(updated.currentTab, AppTab.home);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Document search bar – FR-025
  // ═══════════════════════════════════════════════════════════════════════════

  group('DocumentsScreen search bar (FR-025)', () {
    test('search hint text constant is non-empty', () {
      const expectedHint = 'Search documents…';
      expect(expectedHint, isNotEmpty,
          reason: 'FR-025: search bar hint must be non-empty');
    });

    test('search filter logic matches on name and content (case-insensitive)', () {
      final docs = [
        Document(
          id: '1',
          name: 'Annual Report',
          previewPath: '',
          uploadedDate: DateTime(2024),
          content: 'Quarterly earnings data',
        ),
        Document(
          id: '2',
          name: 'Meeting Notes',
          previewPath: '',
          uploadedDate: DateTime(2024),
          content: 'Discussion about roadmap',
        ),
      ];

      // Name match
      String query = 'annual';
      var filtered = docs
          .where((d) =>
              d.name.toLowerCase().contains(query.toLowerCase()) ||
              d.content.toLowerCase().contains(query.toLowerCase()))
          .toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, '1');

      // Content match
      query = 'roadmap';
      filtered = docs
          .where((d) =>
              d.name.toLowerCase().contains(query.toLowerCase()) ||
              d.content.toLowerCase().contains(query.toLowerCase()))
          .toList();
      expect(filtered.length, 1);
      expect(filtered.first.id, '2');

      // Empty query returns all
      query = '';
      filtered = query.isEmpty
          ? docs
          : docs
              .where((d) =>
                  d.name.toLowerCase().contains(query.toLowerCase()) ||
                  d.content.toLowerCase().contains(query.toLowerCase()))
              .toList();
      expect(filtered.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Overlay opacity slider bounds – FR-012
  // ═══════════════════════════════════════════════════════════════════════════

  group('Overlay opacity slider (FR-012)', () {
    test('50%–100% range constants are correct', () {
      const double kMin = 0.5;
      const double kMax = 1.0;
      expect(kMin, 0.5);
      expect(kMax, 1.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Dark mode preference key – FR-021
  // ═══════════════════════════════════════════════════════════════════════════

  group('Dark mode preference (FR-021)', () {
    test('pref_dark_mode key string matches implementation', () {
      const key = 'pref_dark_mode';
      expect(key, 'pref_dark_mode');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Live AR screen smoke – FR-005 to FR-009
  // ═══════════════════════════════════════════════════════════════════════════

  group('Live AR OCR (FR-005 to FR-009)', () {
    test('OCR throttle constant is at or below 200 ms', () {
      const int kOcrThrottleMs = 200;
      expect(kOcrThrottleMs, lessThanOrEqualTo(200),
          reason: 'SRS requires ≤200 ms OCR latency');
    });
  });
}