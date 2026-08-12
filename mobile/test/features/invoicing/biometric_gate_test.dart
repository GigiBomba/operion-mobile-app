import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/security/biometric_gate.dart';

void main() {
  group('BiometricGate', () {
    test('returns false when the authenticator fails', () async {
      final gate = BiometricGate(authenticate: (_) async => false);
      expect(await gate.requireBiometricConfirmation(), isFalse);
    });

    test('returns true when the authenticator succeeds', () async {
      final gate = BiometricGate(authenticate: (_) async => true);
      expect(await gate.requireBiometricConfirmation(), isTrue);
    });

    test('grace window: second action within 5 minutes skips the re-prompt',
        () async {
      var prompts = 0;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return true;
      });

      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1, reason: 'Second prompt must be skipped (grace window)');
    });

    test('grace window expires after 5 minutes → re-prompt', () async {
      var now = DateTime(2026, 8, 2, 12, 0, 0);
      var prompts = 0;
      final gate = BiometricGate(
        authenticate: (_) async {
          prompts++;
          return true;
        },
        now: () => now,
      );

      await gate.requireBiometricConfirmation();
      expect(prompts, 1);

      now = now.add(const Duration(minutes: 6));
      await gate.requireBiometricConfirmation();
      expect(prompts, 2, reason: 'Grace window expired → must re-prompt');
    });

    test('resetGraceWindow forces a re-prompt on the next action', () async {
      var prompts = 0;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return true;
      });

      await gate.requireBiometricConfirmation();
      gate.resetGraceWindow();
      await gate.requireBiometricConfirmation();
      expect(prompts, 2);
    });

    test('failed attempt does not grant a grace window', () async {
      var prompts = 0;
      var succeed = false;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return succeed;
      });

      expect(await gate.requireBiometricConfirmation(), isFalse);
      succeed = true;
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 2,
          reason: 'A failed attempt must not satisfy the grace window');
    });

    test('kBiometricGraceWindow is exactly 5 minutes', () {
      expect(kBiometricGraceWindow, const Duration(minutes: 5));
    });
  });
}
