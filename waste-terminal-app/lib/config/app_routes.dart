import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../pages/main_page.dart';
import '../pages/waste_in_page.dart';
import '../pages/scan_page.dart';
import '../pages/mine_page.dart';
import '../pages/waste_out_page.dart';
import '../pages/inventory_page.dart';
import '../pages/warning_page.dart';
import '../pages/inventory_check_page.dart';
import '../pages/scan_page.dart';
import '../pages/mine_page.dart';
import '../pages/platform_report_dashboard_page.dart';
import '../pages/transfer_order_detail_page.dart';
import '../pages/camera_list_page.dart';
import '../pages/camera_preview_page.dart';
import '../pages/capture_event_list_page.dart';
import '../pages/capture_event_detail_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String main = '/main';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String wasteIn = '/waste_in';
  static const String wasteOut = '/waste_out';
  static const String transferOrder = '/transfer_order';
  static const String transferOrderDetail = '/transfer_order_detail';
  static const String inventoryCheck = '/inventory_check';
  static const String inventoryCheckDetail = '/inventory_check_detail';
  static const String warning = '/warning';
  static const String warningDetail = '/warning_detail';
  static const String container = '/container';
  static const String containerDetail = '/container_detail';
  static const String wasteCatalog = '/waste_catalog';
  static const String wasteCatalogDetail = '/waste_catalog_detail';
  static const String scan = '/scan';
  static const String mine = '/mine';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String sync = '/sync';
  static const String about = '/about';
  static const String platformReport = '/platform_report';
  static const String cameraList = '/camera_list';
  static const String cameraPreview = '/camera_preview';
  static const String captureEventList = '/capture_event_list';
  static const String captureEventDetail = '/capture_event_detail';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const LoginPage(),
        login: (context) => const LoginPage(),
        main: (context) => const MainPage(),
        home: (context) => const HomePage(),
        inventory: (context) => const InventoryPage(),
        wasteIn: (context) => const WasteInPage(),
        wasteOut: (context) => const WasteOutPage(),
        transferOrder: (context) => const WarningPage(),
        inventoryCheck: (context) => const InventoryCheckPage(),
        inventoryCheckDetail: (context) =>
            const _PlaceholderPage(title: 'Inventory Check Detail'),
        warning: (context) => const WarningPage(),
        warningDetail: (context) => const _PlaceholderPage(title: 'Warning Detail'),
        container: (context) => const _PlaceholderPage(title: 'Container'),
        containerDetail: (context) => const _PlaceholderPage(title: 'Container Detail'),
        wasteCatalog: (context) => const _PlaceholderPage(title: 'Waste Catalog'),
        wasteCatalogDetail: (context) =>
            const _PlaceholderPage(title: 'Waste Catalog Detail'),
        scan: (context) => const ScanPage(),
        mine: (context) => const MinePage(),
        profile: (context) => const _PlaceholderPage(title: 'Profile'),
        settings: (context) => const _PlaceholderPage(title: 'Settings'),
        sync: (context) => const _PlaceholderPage(title: 'Sync'),
        about: (context) => const _PlaceholderPage(title: 'About'),
        platformReport: (context) => const PlatformReportDashboardPage(),
        cameraList: (context) => const CameraListPage(),
        captureEventList: (context) => const CaptureEventListPage(),
      };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case transferOrderDetail:
        final args = settings.arguments;
        int orderId = 0;
        if (args is Map) {
          orderId = args['orderId'] as int? ?? 0;
        } else if (args is int) {
          orderId = args;
        }
        return MaterialPageRoute(
          builder: (context) => TransferOrderDetailPage(orderId: orderId),
          settings: settings,
        );
      case cameraPreview:
        final args = settings.arguments;
        String cameraCode = '';
        if (args is String) {
          cameraCode = args;
        } else if (args is Map) {
          cameraCode = args['cameraCode'] as String? ?? '';
        }
        return MaterialPageRoute(
          builder: (context) => CameraPreviewPage(cameraCode: cameraCode),
          settings: settings,
        );
      case captureEventDetail:
        final args = settings.arguments;
        int eventId = 0;
        if (args is int) {
          eventId = args;
        } else if (args is Map) {
          eventId = args['eventId'] as int? ?? 0;
        }
        return MaterialPageRoute(
          builder: (context) => CaptureEventDetailPage(eventId: eventId),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (context) => const _PlaceholderPage(title: 'Unknown'),
          settings: settings,
        );
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => const _PlaceholderPage(title: '404 Not Found'),
      settings: settings,
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title),
      ),
    );
  }
}
