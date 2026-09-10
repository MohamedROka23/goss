import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'backend.dart';
import 'firestore_backend.dart';

/// Provides the active [GossBackend] based on the saved mode.
class BackendManager {
  static GossBackend? _active;
  static bool _firebaseAvailable = false;

  static const _customerIdKey = 'goss-customer-id';
  static final Uuid _uuid = const Uuid();

  static bool get firebaseAvailable => _firebaseAvailable;
  static GossBackend? get active => _active;

  /// Initialize Firebase once. Returns true if Firebase is ready.
  static Future<bool> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } catch (_) {
      _firebaseAvailable = false;
    }
    return _firebaseAvailable;
  }

  /// Persistent customer identity.
  ///
  /// Cloud mode: the Firebase anonymous account uid, so Firestore rules can
  /// scope requests to their owner. Local mode: a persistent random uuid.
  static Future<String> customerId() async {
    if (_firebaseAvailable) {
      try {
        final auth = FirebaseAuth.instance;
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
        }
        return auth.currentUser!.uid;
      } catch (_) {
        // Anonymous sign-in unavailable: fall through to a device id.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_customerIdKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_customerIdKey, id);
    }
    return id;
  }

  static Future<GossBackend> resolve() async {
    if (_active != null) return _active!;

    // The app always runs on cloud Firebase (Firestore + Auth). There is no
    // offline/local HTTP backend — every build must use Firebase.
    _active = FirestoreBackend();
    return _active!;
  }

  static Future<void> reset() async {
    _active = null;
  }
}
