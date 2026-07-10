import 'package:flutter_test/flutter_test.dart';
import 'package:uleam_med/utils/form_inputs.dart';

void main() {
  group('FormInputs validators', () {
    test('positiveDecimal accepts numbers only', () {
      expect(FormInputs.positiveDecimal('150'), isNull);
      expect(FormInputs.positiveDecimal('12.5'), isNull);
      expect(FormInputs.positiveDecimal('12,5'), isNull);
      expect(FormInputs.positiveDecimal('abc'), isNotNull);
      expect(FormInputs.positiveDecimal('0'), isNotNull);
    });

    test('phoneValidator checks digit length', () {
      expect(FormInputs.phoneValidator('0991234567'), isNull);
      expect(FormInputs.phoneValidator('12'), isNotNull);
    });

    test('caregiverCodeValidator requires 8 alphanumeric chars', () {
      expect(FormInputs.caregiverCodeValidator('ABCD-2345'), isNull);
      expect(FormInputs.caregiverCodeValidator('ABCD'), isNotNull);
    });
  });
}
