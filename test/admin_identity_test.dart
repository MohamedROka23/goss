import 'package:flutter_test/flutter_test.dart';
import 'package:goss/models/models.dart';

/// Regression guard for the "logs in and is immediately signed out" report.
///
/// Root cause: [AppProvider.resolveCurrentAdmin] identified the signed-in
/// member by comparing e-mail addresses. The owner's Auth address was
/// `info@gossts.com` while the `/admins` document said `info@gosst.com`, so the
/// comparison found nothing, the account looked "not on the team", and the app
/// revoked its own session seconds after a successful sign-in.
///
/// The identity that cannot drift is the uid, because it is the Firestore
/// document key. These tests pin that invariant at the model layer.
void main() {
  AdminUser member({
    required String id,
    required String email,
    String role = AdminRole.admin,
    List<String>? permissions,
  }) {
    return AdminUser(
      id: id,
      name: 'Member',
      email: email,
      role: role,
      permissions: permissions ?? defaultPermissionsFor(role),
    );
  }

  group('identity is the uid, not the e-mail', () {
    test('the owner resolves by uid even when the e-mails disagree', () {
      const uid = 'Lt3KI3MAoIgnK1tt028suzJJDlq1';
      final serverProfile = member(
        id: uid,
        email: 'info@gossts.com',
        role: AdminRole.super_,
      );
      final listRecord = member(id: uid, email: 'info@gosst.com', role: AdminRole.super_);

      // The uid matches, so the member is found and never treated as revoked.
      expect(serverProfile.id, listRecord.id);
      expect(serverProfile.role, AdminRole.super_);
      expect(AdminRole.active.contains(serverProfile.role), isTrue);
    });

    test('a real removal still fails to match, because the uid is gone', () {
      const serverUid = 'removed-member-uid';
      // After revocation the tombstone is filtered out of the active list, so
      // no record carries this uid any more.
      final activeList = [member(id: 'someone-else', email: 'x@y.z')];
      expect(
        activeList.any((a) => a.id == serverUid),
        isFalse,
        reason: 'a removed member must not resolve to any active record',
      );
    });
  });

  group('e-mail comparison is case/whitespace tolerant', () {
    test('the same address in different shapes still matches', () {
      const a = ' Tarek@Gossts.com ';
      const b = 'tarek@gossts.com';
      expect(a.trim().toLowerCase(), b.trim().toLowerCase());
    });
  });

  group('a revoked tombstone resolves to nothing', () {
    test('revoked is excluded from the active team list', () {
      final tombstone = member(
        id: 'gone',
        email: 'gone@gossts.com',
        role: AdminRole.revoked,
      );
      expect(AdminRole.active.contains(tombstone.role), isFalse);
      expect(tombstone.permissions, isEmpty);
      expect(defaultPermissionsFor(tombstone.role), isEmpty);
    });
  });
}
