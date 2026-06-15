import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/app_provider.dart';
import '../widgets/common_button.dart';
import '../utils/toast_util.dart';
import 'face_verify_page.dart';
import '../services/face_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final appProvider = context.read<AppProvider>();
      final authService = appProvider.authService;
      
      String? savedUsername = await authService.getRememberedUsername();
      bool savedRememberMe = await authService.getRememberMe();

      if (savedUsername != null && savedRememberMe) {
        _usernameController.text = savedUsername;
        _rememberMe = savedRememberMe;
        setState(() {});
      }
    } catch (e) {
      // 静默失败
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      EasyLoading.show(status: '登录中...');

      final appProvider = context.read<AppProvider>();
      
      try {
        await appProvider.login(
          username: username,
          password: password,
          rememberMe: _rememberMe,
        );

        ToastUtil.showSuccess('登录成功');
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } catch (e) {
        final isOnline = appProvider.isOnline;
        if (!isOnline) {
          bool canOfflineLogin = await _tryOfflineLogin(username, password);
          if (canOfflineLogin) {
            ToastUtil.showSuccess('离线登录成功');
            if (mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.main);
            }
            return;
          }
        }
        rethrow;
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('SocketException') || errorMsg.contains('网络')) {
        errorMsg = '网络连接失败，请检查网络或使用离线登录';
      }
      ToastUtil.showError(errorMsg);
    } finally {
      EasyLoading.dismiss();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _tryOfflineLogin(String username, String password) async {
    try {
      final appProvider = context.read<AppProvider>();
      final authService = appProvider.authService;

      if (!authService.isLoggedIn) {
        return false;
      }

      final savedUserInfo = authService.userInfo;
      if (savedUserInfo == null) {
        return false;
      }

      final savedUsername = savedUserInfo['username'];
      if (savedUsername != username) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 60.h),
                          _buildLogo(),
                          SizedBox(height: 40.h),
                          _buildLoginCard(),
                          const Spacer(),
                          _buildFooter(),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80.r,
          height: 80.r,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            Icons.recycling,
            size: 48.r,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          AppConfig.appName,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          AppConfig.appDescription,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '用户登录',
              style: AppTextStyle.h2,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            _buildUsernameField(),
            SizedBox(height: 16.h),
            _buildPasswordField(),
            SizedBox(height: 12.h),
            _buildRememberMe(),
            SizedBox(height: 24.h),
            _buildLoginButton(),
            SizedBox(height: 16.h),
            _buildFaceLoginEntry(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: '用户名',
        hintText: '请输入用户名',
        prefixIcon: Icon(
          Icons.person_outline,
          color: AppTheme.textSecondary,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入用户名';
        }
        return null;
      },
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(50),
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: Icon(
          Icons.lock_outline,
          color: AppTheme.textSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        if (value.length < 6) {
          return '密码长度不能少于6位';
        }
        return null;
      },
      onFieldSubmitted: (_) => _handleLogin(),
      inputFormatters: [
        LengthLimitingTextInputFormatter(50),
      ],
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        SizedBox(
          width: 24.w,
          height: 24.h,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Text(
            '记住用户名',
            style: AppTextStyle.bodySecondary,
          ),
        ),
        const Spacer(),
        Consumer<AppProvider>(
          builder: (context, provider, child) {
            if (!provider.isOnline) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 16.r,
                    color: AppTheme.warningColor,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '离线模式',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return CommonButton(
      text: '登 录',
      type: ButtonType.primary,
      size: ButtonSize.large,
      block: true,
      loading: _isLoading,
      onPressed: _isLoading ? null : _handleLogin,
    );
  }

  Widget _buildFaceLoginEntry() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text('或使用', style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        SizedBox(height: 16.h),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleFaceLogin,
          icon: Icon(Icons.face, color: AppTheme.primaryColor, size: 22.sp),
          label: Text(
            '人脸识别登录',
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            minimumSize: Size(double.infinity, 48.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }

  Future<void> _handleFaceLogin() async {
    final faceAuthService = FaceAuthService();
    final appProvider = context.read<AppProvider>();

    int faceCount = (await faceAuthService.userFaceService.getEnabledFaceList()).length;
    if (faceCount == 0) {
      ToastUtil.showWarning('本地暂无录入的人脸数据，请先使用账号密码登录后录入人脸');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const FaceVerifyPage(
          authType: 'login',
          autoNavigateOnSuccess: false,
        ),
      ),
    );

    if (result != null && result is FaceAuthResult && result.success && result.userFace != null) {
      setState(() {
        _isLoading = true;
      });
      EasyLoading.show(status: '正在登录...');

      try {
        final userInfo = {
          'userId': result.userFace!.userId,
          'username': result.userFace!.username,
          'faceId': result.userFace!.faceId,
          'faceAuthId': result.authId,
          'loginType': 'face',
        };

        await appProvider.loginWithFace(
          userId: result.userFace!.userId!,
          username: result.userFace!.username!,
          faceAuthId: result.authId,
        );

        ToastUtil.showSuccess('人脸登录成功，欢迎 ${result.userFace!.username}');

        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } catch (e) {
        ToastUtil.showError(e.toString().replaceAll('Exception: ', ''));
      } finally {
        EasyLoading.dismiss();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '版本 ${AppConfig.version}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          AppConfig.copyright,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
