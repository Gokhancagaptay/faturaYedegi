// lib/features/auth/screens/login_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fatura_yeni/features/auth/screens/login_screen.dart';
import 'package:fatura_yeni/features/auth/screens/register_screen.dart';

// import 'package:fatura_uygulamasi/features/auth/screens/register_screen.dart';

class LoginRegisterScreen extends StatelessWidget {
  const LoginRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Merkezi temadan renkleri ve stilleri alıyoruz.
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isWeb = kIsWeb;
    final isDesktop = screenSize.width > 1200;

    return Scaffold(
      // Arka plan rengi, temadaki birincil renkten (primaryColor) geliyor.
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: isWeb && isDesktop
            ? _buildWebLayout(context, theme, screenSize)
            : _buildMobileLayout(context, theme, screenSize),
      ),
    );
  }

  Widget _buildWebLayout(
      BuildContext context, ThemeData theme, Size screenSize) {
    return Row(
      children: [
        // Sol panel - Logo ve başlık
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.all(screenSize.width * 0.04),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoAndTitle(context),
                SizedBox(height: screenSize.height * 0.04),
                _buildWebDescription(context, theme),
              ],
            ),
          ),
        ),
        // Sağ panel - Giriş formları
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                bottomLeft: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Center(
              child: _buildWebButtons(context, theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, ThemeData theme, Size screenSize) {
    return Padding(
      // Responsive yan boşluklar
      padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DEĞİŞİKLİK: Boşlukları daha dengeli dağıtmak için Spacer flex değerleri güncellendi.
          const Spacer(flex: 3),
          _buildLogoAndTitle(
              context), // Metot ismi daha açıklayıcı hale getirildi.
          const Spacer(flex: 2),
          _buildAuthButtons(context, isWeb: false),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildWebDescription(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Modern Fatura Yönetimi",
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        Text(
          "Faturalarınızı dijital ortamda saklayın, analiz edin ve raporlayın. "
          "Kağıt israfını önleyin, zamandan tasarruf edin.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWebButtons(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Hoş Geldiniz",
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.primaryColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          _buildAuthButtons(context, isWeb: true),
        ],
      ),
    );
  }

  Widget _buildLogoAndTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // DEĞİŞİKLİK: Yeni tasarıma uygun, daha modern ve temiz bir ikon kullanıldı.
        const Icon(
          Icons.receipt_long_outlined,
          size: 65,
          color: Colors.white,
        ),
        const SizedBox(height: 24),
        Text(
          "Fatura Tarayıcı",
          style: theme.textTheme.displayLarge?.copyWith(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Kağıt fişlere veda edin!",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.85),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButtons(BuildContext context, {bool isWeb = false}) {
    final theme = Theme.of(context);
    final buttonShape = MaterialStateProperty.all<OutlinedBorder>(
      const StadiumBorder(),
    );

    // Web için butonlar
    final webButtons = [
      ElevatedButton(
        style: theme.elevatedButtonTheme.style?.copyWith(
          shape: buttonShape,
          backgroundColor: MaterialStateProperty.all(theme.primaryColor),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          ),
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: const Text('Giriş Yap'),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        style: theme.outlinedButtonTheme.style?.copyWith(
          shape: buttonShape,
          side: MaterialStateProperty.all(
            BorderSide(color: theme.primaryColor, width: 1.5),
          ),
          foregroundColor: MaterialStateProperty.all(theme.primaryColor),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          ),
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
        child: const Text('Kayıt Ol'),
      ),
    ];

    // Mobil için butonlar
    final mobileButtons = [
      OutlinedButton(
        style: theme.outlinedButtonTheme.style?.copyWith(
          shape: buttonShape,
          side: MaterialStateProperty.all(
            const BorderSide(color: Colors.white, width: 2),
          ),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: const Text('Giriş Yap'),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        style: theme.elevatedButtonTheme.style?.copyWith(
          shape: buttonShape,
          backgroundColor: MaterialStateProperty.all(Colors.white),
          foregroundColor: MaterialStateProperty.all(theme.primaryColor),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
        child: const Text('Kayıt Ol'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: isWeb ? webButtons : mobileButtons,
    );
  }
}
