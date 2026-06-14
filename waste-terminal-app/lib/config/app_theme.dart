import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);

  static const Color secondaryColor = Color(0xFF26A69A);
  static const Color accentColor = Color(0xFFFF7043);

  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color dangerColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color bgPrimary = Color(0xFFF5F5F5);
  static const Color bgSecondary = Color(0xFFFFFFFF);
  static const Color bgCard = Color(0xFFFFFFFF);

  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color borderColor = Color(0xFFE0E0E0);

  static const Color shadowColor = Color(0x1A000000);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: bgSecondary,
          error: dangerColor,
          onPrimary: textInverse,
          onSecondary: textInverse,
          onSurface: textPrimary,
          onError: textInverse,
        ),
        scaffoldBackgroundColor: bgPrimary,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: textInverse,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
            color: textInverse,
          ),
        ),
        cardTheme: CardTheme(
          color: bgCard,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          shadowColor: shadowColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: textInverse,
            minimumSize: Size(double.infinity, 44.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            textStyle: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            minimumSize: Size(double.infinity, 44.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            side: const BorderSide(color: primaryColor),
            textStyle: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgSecondary,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.w12,
            vertical: AppSpacing.h12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: dangerColor),
          ),
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: textHint,
          ),
          labelStyle: TextStyle(
            fontSize: 14.sp,
            color: textSecondary,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: dividerColor,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bgSecondary,
          selectedItemColor: primaryColor,
          unselectedItemColor: textHint,
          selectedLabelStyle: TextStyle(fontSize: 12.sp),
          unselectedLabelStyle: TextStyle(fontSize: 12.sp),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}

class AppTextStyle {
  AppTextStyle._();

  static TextStyle get h1 => TextStyle(
        fontSize: 28.sp,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      );

  static TextStyle get h3 => TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      );

  static TextStyle get title => TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      );

  static TextStyle get subtitle => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      );

  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.normal,
        color: AppTheme.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.normal,
        color: AppTheme.textPrimary,
      );

  static TextStyle get bodySecondary => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.normal,
        color: AppTheme.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.normal,
        color: AppTheme.textSecondary,
      );

  static TextStyle get small => TextStyle(
        fontSize: 10.sp,
        fontWeight: FontWeight.normal,
        color: AppTheme.textHint,
      );
}

class AppRadius {
  AppRadius._();

  static double get r4 => 4.r;
  static double get r8 => 8.r;
  static double get r12 => 12.r;
  static double get r16 => 16.r;
  static double get r20 => 20.r;
  static double get r24 => 24.r;
  static double get rCircle => 999.r;
}

class AppSpacing {
  AppSpacing._();

  static double get w4 => 4.w;
  static double get w8 => 8.w;
  static double get w12 => 12.w;
  static double get w16 => 16.w;
  static double get w20 => 20.w;
  static double get w24 => 24.w;
  static double get w32 => 32.w;

  static double get h4 => 4.h;
  static double get h8 => 8.h;
  static double get h12 => 12.h;
  static double get h16 => 16.h;
  static double get h20 => 20.h;
  static double get h24 => 24.h;
  static double get h32 => 32.h;
}

class AppSize {
  AppSize._();

  static double get iconSmall => 16.r;
  static double get iconMedium => 24.r;
  static double get iconLarge => 32.r;
  static double get iconXLarge => 48.r;

  static double get buttonHeight => 44.h;
  static double get inputHeight => 44.h;
  static double get appBarHeight => 56.h;
  static double get bottomNavHeight => 56.h;

  static double get cardElevation => 2.r;
}

class AppPadding {
  AppPadding._();

  static EdgeInsets get page => EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 16.h,
      );

  static EdgeInsets get pageHorizontal => EdgeInsets.symmetric(
        horizontal: 16.w,
      );

  static EdgeInsets get cardContent => EdgeInsets.all(12.r);

  static EdgeInsets get inputContent => EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 12.h,
      );

  static EdgeInsets get buttonHorizontal => EdgeInsets.symmetric(
        horizontal: 24.w,
      );
}
