// lib/features/account/screens/account_screen.dart
import 'package:fatura_yeni/core/services/firebase_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _storageService = StorageService();
  final _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _isDarkMode = false; // Dark mode durumu

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Kullanıcı verilerini yükle
    setState(() {});
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _storageService.deleteToken();
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çıkış yapılamadı: ${e.toString()}')),
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

  // Profil düzenleme sayfasına yönlendir
  void _navigateToEditProfile() {
    // TODO: Profil düzenleme sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Profil düzenleme özelliği yakında eklenecek')),
    );
  }

  // Güvenlik ayarları sayfasına yönlendir
  void _navigateToSecurity() {
    // TODO: Güvenlik ayarları sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Güvenlik ayarları yakında eklenecek')),
    );
  }

  // Bildirim ayarları
  void _navigateToNotifications() {
    // TODO: Bildirim ayarları sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bildirim ayarları yakında eklenecek')),
    );
  }

  // Görünüm ayarları
  void _navigateToAppearance() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Görünüm Ayarları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildThemeOption('Açık Mod', Icons.light_mode, false),
                _buildThemeOption('Karanlık Mod', Icons.dark_mode, true),
                _buildThemeOption(
                    'Sistem Varsayılanı', Icons.settings_system_daydream, null),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(String title, IconData icon, bool? isDark) {
    final isSelected = (isDark == _isDarkMode);
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.black,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFF1E3A8A)) : null,
      onTap: () {
        setState(() {
          _isDarkMode = isDark ?? false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title seçildi')),
        );
      },
    );
  }

  // Dil ayarları
  void _navigateToLanguage() {
    // TODO: Dil ayarları sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dil ayarları yakında eklenecek')),
    );
  }

  // Yardım merkezi
  void _navigateToHelp() {
    // TODO: Yardım merkezi sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yardım merkezi yakında eklenecek')),
    );
  }

  // Geri bildirim
  void _navigateToFeedback() {
    // TODO: Geri bildirim sayfasına yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Geri bildirim özelliği yakında eklenecek')),
    );
  }

  // Profil kartı widget'ı
  Widget _buildProfileCard() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Jimmy Grammy';
    final email = user?.email ?? 'jimmy@example.com';
    final photoURL = user?.photoURL;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profil resmi
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
            ),
            child: photoURL != null
                ? ClipOval(
                    child: Image.network(
                      photoURL,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Kullanıcı adı
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 8),
          // E-posta
          Text(
            email,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF323232),
            ),
          ),
        ],
      ),
    );
  }

  // Ayar grubu widget'ı
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  // Ayar kartı widget'ı
  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showChevron = true,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: titleColor ?? const Color(0xFF1E3A8A),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: titleColor ?? const Color(0xFF000000),
          ),
        ),
        trailing: showChevron
            ? const Icon(
                Icons.chevron_right,
                color: Color(0xFF6B7280),
                size: 20,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Profil ve Ayarlar',
              style: TextStyle(
                color: Color(0xFF000000),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profil kartı
            _buildProfileCard(),

            // HESAP YÖNETİMİ
            _buildSettingsGroup(
              'HESAP YÖNETİMİ',
              [
                _buildSettingsCard(
                  icon: Icons.person,
                  title: 'Profili Düzenle',
                  onTap: _navigateToEditProfile,
                ),
                _buildSettingsCard(
                  icon: Icons.shield,
                  title: 'Güvenlik',
                  onTap: _navigateToSecurity,
                ),
              ],
            ),

            // UYGULAMA AYARLARI
            _buildSettingsGroup(
              'UYGULAMA AYARLARI',
              [
                _buildSettingsCard(
                  icon: Icons.notifications,
                  title: 'Bildirimler',
                  onTap: _navigateToNotifications,
                ),
                _buildSettingsCard(
                  icon: Icons.visibility,
                  title: 'Görünüm',
                  onTap: _navigateToAppearance,
                ),
                _buildSettingsCard(
                  icon: Icons.language,
                  title: 'Dil',
                  onTap: _navigateToLanguage,
                ),
              ],
            ),

            // DESTEK
            _buildSettingsGroup(
              'DESTEK',
              [
                _buildSettingsCard(
                  icon: Icons.help_outline,
                  title: 'Yardım Merkezi',
                  onTap: _navigateToHelp,
                ),
                _buildSettingsCard(
                  icon: Icons.feedback,
                  title: 'Geri Bildirimde Bulun',
                  onTap: _navigateToFeedback,
                ),
              ],
            ),

            // OTURUM
            _buildSettingsGroup(
              'OTURUM',
              [
                _buildSettingsCard(
                  icon: Icons.logout,
                  title: 'Çıkış Yap',
                  onTap: _logout,
                  showChevron: false,
                  titleColor: const Color(0xFFEF4444),
                ),
              ],
            ),

            // Alt boşluk
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
