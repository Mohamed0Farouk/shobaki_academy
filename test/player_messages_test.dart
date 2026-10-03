import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/services/player_messages.dart';

void main() {
  group('PlayerMessages', () {
    test('auto quality notice is Arabic and mentions pinning', () {
      expect(
        RegExp(r'[\u0600-\u06FF]').hasMatch(PlayerMessages.autoQualityBody),
        isTrue,
      );
      expect(
        RegExp(r'[\u0600-\u06FF]').hasMatch(PlayerMessages.autoQualityTitle),
        isTrue,
      );
      // The student needs to know they can override it, otherwise the notice
      // reads as "you do not have a choice".
      expect(PlayerMessages.autoQualityBody.contains('تثبيت'), isTrue);
    });

    test('a quality change is still visible on the chip', () {
      // The downgrade toast was removed as too noisy. The chip is now the only
      // surface that reveals a change, so it must carry both the mode and the
      // rendition the student actually landed on.
      expect(PlayerMessages.autoChipLabel('480'), contains('480'));
      expect(PlayerMessages.autoChipLabel('480'), contains('تلقائي'));
    });

    test('auto chip label shows the mode and the effective rendition', () {
      expect(PlayerMessages.autoChipLabel('720'), 'تلقائي · 720');
    });

    test('auto chip label exposes the effective resolution for tests', () {
      // Guards against a refactor that drops the effective label and leaves
      // the student unable to see a downgrade happen.
      expect(PlayerMessages.autoChipLabel('360'), contains('360'));
    });

    test('quality labels carry no trailing "p"', () {
      // Same RTL reason as the parser: a trailing Latin letter lands at the
      // line's start position and reads as detached from its digits.
      const labels = ['360', '480', '720', '1080'];
      for (final label in labels) {
        expect(PlayerMessages.autoChipLabel(label), isNot(contains('p')));
        expect(
          PlayerMessages.autoQualityOptionSubtitle(label),
          isNot(contains('p')),
        );
      }
    });

    test('auto quality label is the literal used in the quality menu', () {
      expect(PlayerMessages.autoQualityLabel, 'تلقائي');
    });

    test('quality menu title is Arabic', () {
      expect(
        RegExp(r'[\u0600-\u06FF]').hasMatch(PlayerMessages.qualityMenuTitle),
        isTrue,
      );
      expect(PlayerMessages.qualityMenuTitle.trim(), isNotEmpty);
    });

    group('auto quality option subtitle', () {
      test('names the rendition auto is actually playing', () {
        final subtitle = PlayerMessages.autoQualityOptionSubtitle('720');
        expect(subtitle, contains('720'));
        expect(
          RegExp(r'[\u0600-\u06FF]').hasMatch(subtitle),
          isTrue,
          reason: 'copy must stay Arabic',
        );
      });

      test('promises adaptation rather than a fixed choice', () {
        // The whole point of the new ladder is that it moves both ways, so the
        // row must read as adaptive and not as another selectable rendition.
        expect(
          PlayerMessages.autoQualityOptionSubtitle(null),
          contains('تلقائياً'),
        );
      });

      test('shows no resolution when auto is not the active mode', () {
        // Passes null whenever the student has pinned: printing a resolution
        // beside `تلقائي` in that state would describe a mode that is not
        // running.
        final subtitle = PlayerMessages.autoQualityOptionSubtitle(null);
        expect(subtitle, isNot(contains('الحالي')));
      });

      test('marks the current rendition only when supplied', () {
        expect(
          PlayerMessages.autoQualityOptionSubtitle('480'),
          contains('الحالي'),
        );
        expect(
          PlayerMessages.autoQualityOptionSubtitle(null),
          isNot(contains('الحالي')),
        );
      });
    });

    test('pin hint tells the student the choice is sticky', () {
      final hint = PlayerMessages.pinQualityHint;
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(hint), isTrue);
      expect(hint, contains('تلقائي'));
      expect(hint, contains('يثبّتها'));
    });

    test('pin hint and auto subtitle say different things', () {
      // The footer explains pinning, the row explains adaptation. If a
      // refactor collapsed them the student would see the same sentence twice
      // and learn neither rule.
      expect(
        PlayerMessages.pinQualityHint,
        isNot(PlayerMessages.autoQualityOptionSubtitle('720')),
      );
    });

    test('connection lost message asks the student to retry', () {
      expect(
        RegExp(r'[\u0600-\u06FF]').hasMatch(PlayerMessages.connectionLost),
        isTrue,
      );
    });

    test('every message is non-empty', () {
      expect(PlayerMessages.autoQualityTitle.trim(), isNotEmpty);
      expect(PlayerMessages.autoQualityBody.trim(), isNotEmpty);
      expect(PlayerMessages.stalledLabel.trim(), isNotEmpty);
      expect(PlayerMessages.connectionLost.trim(), isNotEmpty);
      expect(PlayerMessages.qualityMenuTitle.trim(), isNotEmpty);
      expect(PlayerMessages.autoQualityOptionSubtitle(null).trim(), isNotEmpty);
      expect(
        PlayerMessages.autoQualityOptionSubtitle('720').trim(),
        isNotEmpty,
      );
      expect(PlayerMessages.pinQualityHint.trim(), isNotEmpty);
    });
  });
}
