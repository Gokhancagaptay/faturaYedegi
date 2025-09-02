// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fatura_yeni/core/theme/app_theme.dart';
import 'package:fatura_yeni/core/providers/theme_provider.dart';

import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart';
import 'package:fatura_yeni/l10n/app_localizations.dart';
import 'package:fatura_yeni/firebase_options.dart';
import 'package:fatura_yeni/features/dashboard/providers/dashboard_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase only once
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Activate App Check in debug mode
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    } catch (e) {
      // App Check activation failures should not block app startup
      // ignore
    }

    print('✅ Firebase başarıyla başlatıldı');
  } catch (e) {
    print('❌ Firebase başlatma hatası: $e');
    // Continue without Firebase
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Scanner App',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const LoginRegisterScreen(),
          );
        },
      ),
    );
  }
}
