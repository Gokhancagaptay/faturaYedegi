// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'
    as provider; // provider paketine ön ek ver
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // Locale data için
import 'package:fatura_yeni/core/theme/app_theme.dart';
import 'package:fatura_yeni/core/providers/theme_provider.dart';

import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart'; // Doğru başlangıç ekranı
import 'package:fatura_yeni/features/dashboard/providers/dashboard_provider.dart';
import 'package:fatura_yeni/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i güvenli şekilde başlat
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase başlatma hatası durumunda uygulamanın çökmesini önle
    print('Firebase başlatma hatası: $e');
  }

  // Türkçe locale verilerini başlat
  await initializeDateFormatting('tr_TR', null);

  // Firebase App Check'i güvenli şekilde başlat
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e) {
    // App Check hatası durumunda uygulamanın çökmesini önle
    print('Firebase App Check hatası: $e');
  }

  runApp(
    const ProviderScope(
      // Riverpod için
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.MultiProvider(
      // provider ön ekini kullan
      providers: [
        provider.ChangeNotifierProvider(create: (_) => ThemeProvider()),
        provider.ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: provider.Consumer<ThemeProvider>(
        // provider ön ekini kullan
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Fatura Yönetim Sistemi',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider?.isDarkMode == true
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const LoginRegisterScreen(), // AuthWrapper yerine
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
