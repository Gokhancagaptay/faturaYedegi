// lib/features/auth/screens/login_screen.dart

import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/features/main/main_screen.dart';
import 'package:fatura_yeni/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController(); // email or phone
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _apiService = ApiService();
  final _storageService = StorageService();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final rawIdentifier = _identifierController.text.trim();
    final identifier = _normalizeIdentifier(rawIdentifier);

    if (identifier.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen kullanıcı bilgilerinizi girin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await _apiService.loginWithPassword(
        identifier: identifier,
        password: _passwordController.text,
      );
      final token = resp['token'] as String?;
      if (token == null) throw Exception('Token alınamadı');
      print('🔐 Login - Token alındı: ${token.substring(0, 10)}...');
      await _storageService.saveToken(token);
      print('🔐 Login - Token kaydedildi');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Giriş başarısız: ${_humanizeError(e)}')),
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

  String _normalizeIdentifier(String value) {
    // Telefon ise boşluk, parantez, tireleri sil, baştaki + işaretini koru
    final digits = value.replaceAll(RegExp(r"[\s()-]"), "");
    return digits;
  }

  String _humanizeError(Object e) {
    final text = e.toString();
    if (text.contains('Invalid credentials'))
      return 'Geçersiz kullanıcı bilgileri';
    if (text.contains('401')) return 'Yetki hatası. Lütfen tekrar giriş yapın.';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 900;
    final horizontalPadding = isWide ? 24.0 : screenSize.width * 0.08;
    final topGapFactor = screenSize.height < 700 ? 0.03 : 0.06;
    final betweenGapFactor = screenSize.height < 700 ? 0.06 : 0.1;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: screenSize.height * topGapFactor),
                      _buildLogo(context),
                      SizedBox(height: screenSize.height * betweenGapFactor),
                      _buildLoginForm(context),
                      const SizedBox(height: 32),
                      _buildFooter(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // Arkaplan açık ise mavi logoyu, koyu/mavi arka planlı temalarda beyaz zeminli logoyu kullan
    // Kullanıcı iki görseli assets klasörüne ekledi: beyaz arkaplanlı ve mavi arkaplanlı
    final String logoPath = isDark
        ? 'assets/logo_light_bg.png' // beyaz zeminli logo (dark modda kontrast iyi)
        : 'assets/logo_dark_bg.png'; // mavi zeminli logo (açık arkaplanda daha doygun görünüm sağlar)

    // Sabit logo alanı - sayfa düzenini bozmaz
    final logoContainerWidth = screenSize.width < 400
        ? screenSize.width * 0.8 // Küçük ekranlarda sabit alan
        : screenSize.width < 600
            ? screenSize.width * 0.7 // Orta ekranlarda sabit alan
            : screenSize.width < 900
                ? screenSize.width * 0.5 // Büyük ekranlarda sabit alan
                : screenSize.width * 0.4; // Çok büyük ekranlarda sabit alan

    return Center(
      child: Container(
        width: logoContainerWidth,
        height: 120, // Sabit yükseklik - sayfa düzenini korur
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            logoPath,
            fit: BoxFit.cover, // Resmi alana sığdır ve zoom yap
            alignment: Alignment.center, // Merkeze hizala
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Giriş Yap",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _identifierController,
          label: "E-posta veya Telefon",
          hint: "ornek@email.com veya +905551234567",
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 24),
        _buildLoginButton(),
        const SizedBox(height: 16),
        _buildRegisterLink(context),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF323232), fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0A0A0)),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedBorder,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final theme = Theme.of(context);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Şifre",
            style: theme.textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF323232), fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: "Şifrenizi girin",
            hintStyle: const TextStyle(color: Color(0xFFA0A0A0)),
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            filled: true,
            fillColor: Colors.white,
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedBorder,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.15),
        ),
        onPressed: _isLoading ? null : _login,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('progress'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Giriş Yap', key: ValueKey('label')),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Hesabınız yok mu? ',
          style: TextStyle(color: Color(0xFF323232)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: Text(
            'Kayıt Ol',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.15),
            ),
            onPressed: _isLoading ? null : _login,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('progress'),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Giriş Yap', key: ValueKey('label')),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hesabınız yok mu? ',
              style: TextStyle(color: Color(0xFF323232)),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: Text(
                'Kayıt Ol',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Logo ve başlık
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Modern Fatura Yönetimi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Faturalarınızı dijital ortamda saklayın',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Login form
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.waving_hand,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hoş Geldiniz',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildLoginForm(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
