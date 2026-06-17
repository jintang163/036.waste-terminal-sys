import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'pages/liquid_level_sensor_page.dart';
import 'providers/app_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/warning_provider.dart';
import 'providers/waste_in_provider.dart';
import 'providers/waste_out_provider.dart';
import 'providers/waste_ledger_provider.dart';
import 'providers/dashboard_cockpit_provider.dart';
import 'providers/liquid_level_provider.dart';
import 'providers/carbon_footprint_provider.dart';
import 'services/device_self_check_service.dart';
import 'services/liquid_level_linkage_service.dart';
import 'services/operation_log_service.dart';
import 'services/heartbeat_service.dart';
import 'services/transfer_order_service.dart';
import 'utils/logger_util.dart';
import 'utils/toast_util.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const WasteTerminalApp());
}

class WasteTerminalApp extends StatefulWidget {
  const WasteTerminalApp({super.key});

  @override
  State<WasteTerminalApp> createState() => _WasteTerminalAppState();
}

class _WasteTerminalAppState extends State<WasteTerminalApp> {
  final AppProvider _appProvider = AppProvider();
  final SyncProvider _syncProvider = SyncProvider();
  final InventoryProvider _inventoryProvider = InventoryProvider();
  final WarningProvider _warningProvider = WarningProvider();
  final WasteInProvider _wasteInProvider = WasteInProvider();
  final WasteOutProvider _wasteOutProvider = WasteOutProvider();
  final WasteLedgerProvider _wasteLedgerProvider = WasteLedgerProvider();
  final DashboardCockpitProvider _dashboardCockpitProvider = DashboardCockpitProvider();
  final LiquidLevelProvider _liquidLevelProvider = LiquidLevelProvider();
  final CarbonFootprintProvider _carbonFootprintProvider = CarbonFootprintProvider();

  final LiquidLevelLinkageService _linkageService = LiquidLevelLinkageService();
  final TransferOrderService _transferOrderService = TransferOrderService();
  StreamSubscription<LiquidLevelAlertEvent>? _alertSubscription;

  bool _isInitialized = false;
  bool _alertDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _initProviders();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _alertSubscription = null;
    super.dispose();
  }

  Future<void> _initProviders() async {
    await _appProvider.init();
    await _syncProvider.init();
    await _inventoryProvider.init();
    await _warningProvider.init();
    await _wasteInProvider.init();
    await _wasteOutProvider.init();
    await _wasteLedgerProvider.init();
    await _dashboardCockpitProvider.init();
    await _liquidLevelProvider.init();
    await _carbonFootprintProvider.init();

    await _initDeviceServices();
    _setupAlertListener();

    setState(() {
      _isInitialized = true;
    });
  }

  void _setupAlertListener() {
    _alertSubscription?.cancel();
    _alertSubscription = _linkageService.alertStream.listen((event) {
      _showGlobalAlertDialog(event);
    });
  }

  Future<void> _showGlobalAlertDialog(LiquidLevelAlertEvent event) async {
    if (_alertDialogShowing) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final context = navigator.context;
    if (!mounted) return;

    _alertDialogShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => LiquidLevelAlertDialog(
          event: event,
          onDismiss: () {
            _alertDialogShowing = false;
          },
          onViewOrder: () async {
            _alertDialogShowing = false;
            Navigator.of(ctx).pop();
            if (event.transferOrderNo != null) {
              await _navigateToOrderDetail(event.transferOrderNo!);
            }
          },
        ),
      );
    } finally {
      _alertDialogShowing = false;
    }
  }

  Future<void> _navigateToOrderDetail(String orderNo) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    try {
      final order = await _transferOrderService.getTransferOrderByOrderNo(orderNo);
      if (order == null) {
        ToastUtil.show('未找到联单信息');
        return;
      }
      final orderId = (order['id'] as num?)?.toInt() ?? 0;
      if (orderId <= 0) {
        ToastUtil.show('联单ID无效');
        return;
      }
      navigator.pushNamed(
        AppRoutes.transferOrderDetail,
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      LoggerUtil.error('跳转联单详情失败: $e');
      ToastUtil.showError('跳转失败');
    }
  }

  Future<void> _initDeviceServices() async {
    try {
      await OperationLogService().init();
      LoggerUtil.info('运维日志服务初始化完成');
    } catch (e) {
      LoggerUtil.error('运维日志服务初始化失败: $e');
    }

    try {
      await DeviceSelfCheckService().performSelfCheck();
      LoggerUtil.info('启动时设备自检完成');
    } catch (e) {
      LoggerUtil.error('启动时设备自检失败: $e');
    }

    if (_appProvider.isLoggedIn) {
      try {
        await HeartbeatService().start();
        LoggerUtil.info('心跳服务已启动');
      } catch (e) {
        LoggerUtil.error('心跳服务启动失败: $e');
      }
    }
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.recycling,
                  size: 80.r,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(height: 24.h),
                Text(
                  AppConfig.appName,
                  style: AppTextStyle.h2,
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _appProvider),
        ChangeNotifierProvider<SyncProvider>.value(value: _syncProvider),
        ChangeNotifierProvider<InventoryProvider>.value(value: _inventoryProvider),
        ChangeNotifierProvider<WarningProvider>.value(value: _warningProvider),
        ChangeNotifierProvider<WasteInProvider>.value(value: _wasteInProvider),
        ChangeNotifierProvider<WasteOutProvider>.value(value: _wasteOutProvider),
        ChangeNotifierProvider<WasteLedgerProvider>.value(value: _wasteLedgerProvider),
        ChangeNotifierProvider<DashboardCockpitProvider>.value(value: _dashboardCockpitProvider),
        ChangeNotifierProvider<LiquidLevelProvider>.value(value: _liquidLevelProvider),
        ChangeNotifierProvider<CarbonFootprintProvider>.value(value: _carbonFootprintProvider),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                navigatorKey: appNavigatorKey,
                title: AppConfig.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: _getThemeMode(appProvider.themeMode),
                initialRoute: appProvider.isLoggedIn
                    ? AppRoutes.main
                    : AppRoutes.login,
                routes: AppRoutes.routes,
                onGenerateRoute: AppRoutes.onGenerateRoute,
                onUnknownRoute: AppRoutes.onUnknownRoute,
                builder: EasyLoading.init(
                  builder: (context, widget) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.noScaling,
                      ),
                      child: widget!,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
