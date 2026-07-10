import 'package:flutter_test/flutter_test.dart';
import 'package:uleam_med/utils/phone_launch_utils.dart';

void main() {
  group('normalizeEcuadorPhoneForDialer', () {
    test('convierte numeros ecuatorianos comunes a +593', () {
      expect(normalizeEcuadorPhoneForDialer('0991234567'), '+593991234567');
      expect(normalizeEcuadorPhoneForDialer('991234567'), '+593991234567');
      expect(normalizeEcuadorPhoneForDialer('593991234567'), '+593991234567');
      expect(
        normalizeEcuadorPhoneForDialer('+593 99 123 4567'),
        '+593991234567',
      );
    });

    test('rechaza numeros vacios o incompletos', () {
      expect(normalizeEcuadorPhoneForDialer(''), isNull);
      expect(normalizeEcuadorPhoneForDialer('911'), isNull);
      expect(normalizeEcuadorPhoneForDialer('12345'), isNull);
    });

    test('permite codigos cortos solo cuando se solicita', () {
      expect(normalizeEcuadorPhoneForDialer('911'), isNull);
      expect(
        normalizeEcuadorPhoneForDialer('911', allowShortCode: true),
        '911',
      );
    });
  });
}
