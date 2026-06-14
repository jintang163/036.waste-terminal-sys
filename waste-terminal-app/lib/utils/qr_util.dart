import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'logger_util.dart';

class QrUtil {
  QrUtil._();

  static Widget generateQrImage(
    String data, {
    double size = 200,
    Color? foregroundColor,
    Color? backgroundColor,
    EdgeInsets? padding,
    String? embeddedImagePath,
    double embeddedImageSize = 40,
  }) {
    try {
      return QrImageView(
        data: data,
        size: size,
        foregroundColor: foregroundColor ?? Colors.black,
        backgroundColor: backgroundColor ?? Colors.white,
        padding: padding ?? const EdgeInsets.all(10),
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        embeddedImage:
            embeddedImagePath != null ? AssetImage(embeddedImagePath) : null,
        embeddedImageStyle: QrEmbeddedImageStyle(
          size: Size.square(embeddedImageSize),
        ),
      );
    } catch (e) {
      LoggerUtil.error('generateQrImage error', e);
      return Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: const Icon(Icons.error, color: Colors.red),
      );
    }
  }

  static Widget generateQrWithLogo(
    String data,
    String logoPath, {
    double size = 200,
    double logoSize = 48,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: data,
            size: size,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          ),
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(logoPath),
          ),
        ],
      ),
    );
  }

  static String? parseQrData(String? rawData) {
    if (rawData == null || rawData.isEmpty) return null;
    return rawData.trim();
  }

  static bool isValidQrData(String? data) {
    if (data == null || data.isEmpty) return false;
    return data.trim().isNotEmpty;
  }

  static String generateWasteContainerQr(
    String containerCode, {
    String? enterpriseId,
    String? extra,
  }) {
    final buffer = StringBuffer();
    buffer.write('WC:');
    buffer.write(containerCode);
    if (enterpriseId != null) {
      buffer.write(':E$enterpriseId');
    }
    if (extra != null) {
      buffer.write(':$extra');
    }
    return buffer.toString();
  }

  static String? parseWasteContainerQr(String? data) {
    if (data == null || !data.startsWith('WC:')) return null;
    final parts = data.split(':');
    if (parts.length >= 2) {
      return parts[1];
    }
    return null;
  }

  static String generateTransferOrderQr(String orderNo) {
    return 'TO:$orderNo';
  }

  static String? parseTransferOrderQr(String? data) {
    if (data == null || !data.startsWith('TO:')) return null;
    return data.substring(3);
  }

  static String generateWasteCatalogQr(String wasteCode) {
    return 'WL:$wasteCode';
  }

  static String? parseWasteCatalogQr(String? data) {
    if (data == null || !data.startsWith('WL:')) return null;
    return data.substring(3);
  }

  static String generateInventoryCheckQr(String checkNo) {
    return 'IC:$checkNo';
  }

  static String? parseInventoryCheckQr(String? data) {
    if (data == null || !data.startsWith('IC:')) return null;
    return data.substring(3);
  }

  static QrType? detectQrType(String? data) {
    if (data == null || data.isEmpty) return null;
    if (data.startsWith('WC:')) return QrType.container;
    if (data.startsWith('TO:')) return QrType.transferOrder;
    if (data.startsWith('WL:')) return QrType.wasteCatalog;
    if (data.startsWith('IC:')) return QrType.inventoryCheck;
    return QrType.unknown;
  }
}

enum QrType {
  container,
  transferOrder,
  wasteCatalog,
  inventoryCheck,
  unknown,
}
