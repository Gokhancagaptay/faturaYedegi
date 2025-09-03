// lib/features/auth/screens/otp_screen.dart

import 'dart:async';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:fatura_yeni/features/auth/screens/login_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _pinController = TextEditingController();
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;

  late Timer _timer;
  int _start = 120; // 2 dakika

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_pinController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 6 haneli OTP kodunu girin.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1) Firebase'de giriş yap ve ID token al
      final idToken = await FirebaseAuth.instance
          .signInWithCredential(
            PhoneAuthProvider.credential(
              verificationId: widget.verificationId,
              smsCode: _pinController.text,
            ),
          )
          .then((_) => FirebaseAuth.instance.currentUser?.getIdToken(true));

      if (idToken == null) throw Exception('Firebase ID token alınamadı');

      // 2) Backend'e ID token'ı gönder, uygulama JWT'si al
      final response = await _apiService.loginWithFirebaseToken(
        firebaseIdToken: idToken,
        phoneNumber: widget.phoneNumber,
      );

      final token = response['token'];
      if (token != null) {
        await _storageService.saveToken(token);
        if (mounted) {
          // Başarı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Lütfen giriş yapın.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Login ekranına yönlendir
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        throw Exception('Token alınamadı');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP doğrulama hatası: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get timerString {
    int minutes = _start ~/ 60;
    int seconds = _start % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          "OTP Verification",
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              _buildHeaderTexts(context),
              const SizedBox(height: 32),
              _buildOtpInput(context),
              const SizedBox(height: 24),
              _buildResendCode(context),
              const Spacer(flex: 2),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('OTP Doğrula'),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTexts(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Please Enter\nOTP Verification",
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            children: [
              TextSpan(text: "Code was sent to ${widget.phoneNumber}\n"),
              const TextSpan(text: "This code will expire in "),
              TextSpan(
                text: timerString,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Pinput(
      length: 6, // Backend 6 haneli OTP gönderir
      controller: _pinController,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration!.copyWith(
          border: Border.all(color: Theme.of(context).primaryColor),
        ),
      ),
      onCompleted: (pin) {
        _verifyOtp();
      },
    );
  }

  Widget _buildResendCode(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive an OTP?",
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: _start == 0
              ? () async {
                  // Resend OTP logic
                  try {
                    await _apiService.registerWithOtp(
                      phoneNumber: widget.phoneNumber,
                    );
                    setState(() {
                      _start = 120;
                    });
                    startTimer();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('OTP yeniden gönderme hatası: $e')),
                    );
                  }
                }
              : null, // Disable button if timer is running
          child: Text(
            "Resend",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _start == 0 ? theme.primaryColor : Colors.grey,
            ),
          ),
        )
      ],
    );
  }
}
