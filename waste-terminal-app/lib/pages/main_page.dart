import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/app_provider.dart';
import 'home_page.dart';
import 'inventory_page.dart';
import 'warning_page.dart';
import 'mine_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    InventoryPage(),
    WarningPage(),
    MinePage(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined, size: 24.r),
      activeIcon: Icon(Icons.home, size: 24.r),
      label: '首页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined, size: 24.r),
      activeIcon: Icon(Icons.inventory_2, size: 24.r),
      label: '库存',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined, size: 24.r),
      activeIcon: Icon(Icons.receipt_long, size: 24.r),
      label: '预警',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline, size: 24.r),
      activeIcon: Icon(Icons.person, size: 24.r),
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          items: _navItems,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.bgSecondary,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textHint,
          selectedLabelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 12.sp),
          elevation: 0,
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? _buildScanFab() : null,
    );
  }

  Widget _buildScanFab() {
    return Container(
      margin: EdgeInsets.only(bottom: 40.h),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.scan);
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(Icons.qr_code_scanner, size: 28.r),
      ),
    );
  }
}
