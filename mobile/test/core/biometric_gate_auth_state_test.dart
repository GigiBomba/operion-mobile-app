import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _userA = User(
  id: 'u-a',
  email: 'a@operion.ro',
  fullName: 'User A',
  role: 'admin',
  companyId: 'c1',
);

const _userB = User(
  id: 'u-b',
  email: 'b@operion.ro',
  fullName: 'User B',
  role: 'dispatcher',
  companyId: 'c1',
);

// =============================================================================
// B1: the §12 biometric grace window must NOT survive a logout.
//
// The reset is bound to the auth state transitions in `AuthStateNotifier`
// (setUnauthenticated / setSessionExpired), so every logout path — More Hub,
// Settings, Driver profile, session-expiry, and force-logout — drops the
// window before the next session can reuse it.
// =============================================================================

void main() {
  group('biometric grace window vs auth state (B1)', () {
    test(
        'logout clears the grace window: after A logs out, B\'s first '
        'sensitive action still requires biometrics', () async {
      var now = DateTime(2026, 8, 2, 12, 0, 0);
      var prompts = 0;
      final gate = BiometricGate(
        authenticate: (_) async {
          prompts++;
          return true;
        },
        now: () => now,
      );

      final container = ProviderContainer(
        overrides: [
          biometricGateProvider.overrideWithValue(gate),
          currentUserProvider.overrideWith((ref) => _userA),
        ],
      );
      addTearDown(container.dispose);

      final auth = container.read(authStateProvider.notifier);

      // User A signs in and confirms a sensitive action.
      auth.setAuthenticated();
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1);

      // Grace window is active: A's next sensitive action (still < 5 min
      // later) skips the re-prompt.
      now = now.add(const Duration(minutes: 2));
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1, reason: 'Within the grace window → no re-prompt');

      // User A logs out (More/Settings/Driver logout → setUnauthenticated).
      auth.setUnauthenticated();

      // User B signs in on the same device.
      container.read(currentUserProvider.notifier).state = _userB;
      auth.setAuthenticated();

      // B's FIRST sensitive action must STILL prompt — the grace window must
      // not survive the logout (B1).
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 2,
          reason: 'Cross-user grace skip is a security hole — logout must '
              'reset the window');
    });

    test(
        'force logout (setSessionExpired) also clears the grace window',
        () async {
      var now = DateTime(2026, 8, 2, 12, 0, 0);
      var prompts = 0;
      final gate = BiometricGate(
        authenticate: (_) async {
          prompts++;
          return true;
        },
        now: () => now,
      );

      final container = ProviderContainer(
        overrides: [biometricGateProvider.overrideWithValue(gate)],
      );
      addTearDown(container.dispose);

      final auth = container.read(authStateProvider.notifier);
      auth.setAuthenticated();

      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1);

      // Session terminated by the server (auth interceptor → ForceLogoutEvent).
      auth.setSessionExpired();

      // Next confirmation must re-prompt even though < 5 min elapsed.
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 2,
          reason: 'setSessionExpired must reset the grace window too');
    });

    test(
        'within-session repeated actions still skip after 4 minutes '
        '(grace window untouched without logout)', () async {
      var now = DateTime(2026, 8, 2, 12, 0, 0);
      var prompts = 0;
      final gate = BiometricGate(
        authenticate: (_) async {
          prompts++;
          return true;
        },
        now: () => now,
      );

      final container = ProviderContainer(
        overrides: [biometricGateProvider.overrideWithValue(gate)],
      );
      addTearDown(container.dispose);

      final auth = container.read(authStateProvider.notifier);
      auth.setAuthenticated();
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1);

      // Sanity: without any auth transition the window is still honored.
      now = now.add(const Duration(minutes: 4));
      expect(await gate.requireBiometricConfirmation(), isTrue);
      expect(prompts, 1,
          reason: 'No logout happened → grace window still applies');
    });
  });
}
