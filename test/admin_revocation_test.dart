import 'package:flutter_test/flutter_test.dart';
import 'package:goss/models/models.dart';

void main() {
  group('AdminRole membership', () {
    test('revoked is a tombstone, not a live team role', () {
      expect(AdminRole.revoked, 'revoked');
      expect(AdminRole.active, isNot(contains(AdminRole.revoked)));
      expect(AdminRole.active, contains(AdminRole.super_));
      expect(AdminRole.active, contains(AdminRole.admin));
      expect(AdminRole.active, contains(AdminRole.delegate));
    });
  });

  group('defaultPermissionsFor fails closed', () {
    test('super and admin get the full set', () {
      expect(defaultPermissionsFor(AdminRole.super_).toSet(),
          allPermissionKeys.toSet());
      expect(defaultPermissionsFor(AdminRole.admin).toSet(),
          allPermissionKeys.toSet());
    });

    test('delegate is limited to the field panels', () {
      expect(
        defaultPermissionsFor(AdminRole.delegate).toSet(),
        {
          AdminPerms.requests,
          AdminPerms.customers,
          AdminPerms.tracking,
          AdminPerms.chat,
        },
      );
    });

    test('a revoked or unknown role inherits nothing', () {
      // The regression this guards: a removed member must not be handed the
      // full panel just because its role string is not "delegate".
      expect(defaultPermissionsFor(AdminRole.revoked), isEmpty);
      expect(defaultPermissionsFor('something-else'), isEmpty);
      expect(defaultPermissionsFor(''), isEmpty);
    });
  });

  group('a revoked account carries no panel', () {
    test('every permission key is denied', () {
      expect(AdminRole.active.contains(AdminRole.revoked), isFalse);
      for (final key in allPermissionKeys) {
        final granted = defaultPermissionsFor(AdminRole.revoked);
        expect(granted.contains(key), isFalse, reason: '$key must be denied');
      }
    });
  });
}
