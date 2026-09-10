import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_better/screens/study/study_widgets.dart';

void main() {
  group('screenStudyRatio', () {
    test('shows strict ratio when study exists', () {
      expect(screenStudyRatio(6, 2), '3.0 : 1');
      expect(screenStudyRatio(3, 2), '1.5 : 1');
    });

    test('rounds to whole number for large ratios', () {
      expect(screenStudyRatio(24, 2), '12 : 1');
    });

    test('returns em dash when there is no study time', () {
      expect(screenStudyRatio(4, 0), '—');
      expect(screenStudyRatio(4, -1), '—');
    });

    test('screen time of zero still computes', () {
      expect(screenStudyRatio(0, 2), '0.0 : 1');
    });
  });
}