// Web stub for FlutterSecureStorage.
//
// flutter_secure_storage_web uses dart:html and dart:js_util which are
// unsupported by dart2js in --release mode. On web, we provide this no-op
// stub so the SecurityService class compiles. All storage operations return
// null/false (no persistence) — which is fine because SecurityService is
// not used on web (no biometric/PIN lock on web).

class FlutterSecureStorage {
  const FlutterSecureStorage();

  Future<String?> read({required String key}) async => null;
  Future<void> write({required String key, required String? value}) async {}
  Future<void> delete({required String key}) async {}
  Future<bool> containsKey({required String key}) async => false;
  Future<void> deleteAll() async {}
}
