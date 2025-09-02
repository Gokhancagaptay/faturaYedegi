import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onFailed,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            final idToken = await _auth.currentUser?.getIdToken(true);
            if (idToken != null) onCodeSent('AUTO_VERIFIED');
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      return 'OK';
    } catch (e) {
      onFailed(e.toString());
      rethrow;
    }
  }

  Future<String?> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
    return _auth.currentUser?.getIdToken(true);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
