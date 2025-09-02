// lib/features/main/main_screen.dart

import 'package:fatura_yeni/features/dashboard/screens/dashboard_screen.dart';
import 'package:fatura_yeni/features/scanner/screens/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fatura_yeni/features/account/screens/account_screen.dart';
import 'package:fatura_yeni/features/packages/screens/packages_screen.dart';
import 'package:fatura_yeni/core/constants/dashboard_constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Bottom Navigasyon'da gösterilecek ekranlar
  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardScreen(),
    const ScannerScreen(),
    const PackagesScreen(), // Paketler ekranı
    const AccountScreen(), // TODO: Hesap ekranı buraya gelecek
  ];

  void _onItemTapped(int index) {
    // Kamera sekmesine basıldığında doğrudan ScannerScreen'e yönlendir
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    // Web ve desktop için responsive layout
    if (isWeb && (isDesktop || isTablet)) {
      return Scaffold(
        body: Row(
          children: [
            // Sol navigasyon menüsü (desktop web için)
            Container(
              width: isDesktop ? 280 : 240,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Logo ve başlık
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Fatura Scanner',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Navigasyon menüsü
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onItemTapped,
                      labelType: isDesktop
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.selected,
                      minWidth: isDesktop ? 280 : 240,
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Anasayfa'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.camera_alt_outlined),
                          selectedIcon: Icon(Icons.camera_alt),
                          label: Text('Tarama'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.folder_outlined),
                          selectedIcon: Icon(Icons.folder),
                          label: Text('Paketler'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outlined),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Hesap'),
                        ),
                      ],
                    ),
                  ),
                  // Alt bilgi
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Web Versiyonu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Ana içerik alanı
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.background,
                child: _widgetOptions.elementAt(_selectedIndex),
              ),
            ),
          ],
        ),
      );
    }

    // Mobil ve küçük ekranlar için bottom navigation
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Anasayfa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'Tarama'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Paketler'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hesap'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
      ),
    );
  }
}
