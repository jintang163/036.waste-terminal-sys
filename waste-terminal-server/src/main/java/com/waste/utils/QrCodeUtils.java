package com.waste.utils;

import cn.hutool.core.util.StrUtil;
import com.google.zxing.*;
import com.google.zxing.client.j2se.BufferedImageLuminanceSource;
import com.google.zxing.client.j2se.MatrixToImageConfig;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.qrcode.QRCodeReader;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

public class QrCodeUtils {

    private static final int DEFAULT_WIDTH = 300;
    private static final int DEFAULT_HEIGHT = 300;
    private static final String DEFAULT_FORMAT = "PNG";
    private static final int DEFAULT_MARGIN = 1;
    private static final int DEFAULT_FOREGROUND_COLOR = 0xFF000000;
    private static final int DEFAULT_BACKGROUND_COLOR = 0xFFFFFFFF;

    public static BufferedImage generateQrCodeImage(String content) {
        return generateQrCodeImage(content, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static BufferedImage generateQrCodeImage(String content, int width, int height) {
        return generateQrCodeImage(content, width, height, DEFAULT_FOREGROUND_COLOR, DEFAULT_BACKGROUND_COLOR);
    }

    public static BufferedImage generateQrCodeImage(String content, int width, int height, int foregroundColor, int backgroundColor) {
        try {
            Map<EncodeHintType, Object> hints = new HashMap<>();
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");
            hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.H);
            hints.put(EncodeHintType.MARGIN, DEFAULT_MARGIN);

            QRCodeWriter qrCodeWriter = new QRCodeWriter();
            BitMatrix bitMatrix = qrCodeWriter.encode(content, BarcodeFormat.QR_CODE, width, height, hints);
            MatrixToImageConfig config = new MatrixToImageConfig(foregroundColor, backgroundColor);
            return MatrixToImageWriter.toBufferedImage(bitMatrix, config);
        } catch (WriterException e) {
            throw new RuntimeException("生成二维码失败", e);
        }
    }

    public static String generateQrCodeBase64(String content) {
        return generateQrCodeBase64(content, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static String generateQrCodeBase64(String content, int width, int height) {
        return generateQrCodeBase64(content, width, height, DEFAULT_FOREGROUND_COLOR, DEFAULT_BACKGROUND_COLOR);
    }

    public static String generateQrCodeBase64(String content, int width, int height, int foregroundColor, int backgroundColor) {
        BufferedImage image = generateQrCodeImage(content, width, height, foregroundColor, backgroundColor);
        return imageToBase64(image);
    }

    public static byte[] generateQrCodeBytes(String content) {
        return generateQrCodeBytes(content, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static byte[] generateQrCodeBytes(String content, int width, int height) {
        BufferedImage image = generateQrCodeImage(content, width, height);
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            ImageIO.write(image, DEFAULT_FORMAT, baos);
            return baos.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("生成二维码字节数组失败", e);
        }
    }

    public static void generateQrCodeFile(String content, String filePath) {
        generateQrCodeFile(content, filePath, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static void generateQrCodeFile(String content, String filePath, int width, int height) {
        BufferedImage image = generateQrCodeImage(content, width, height);
        try {
            File file = new File(filePath);
            File parentDir = file.getParentFile();
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs();
            }
            ImageIO.write(image, DEFAULT_FORMAT, file);
        } catch (IOException e) {
            throw new RuntimeException("生成二维码文件失败", e);
        }
    }

    public static BufferedImage generateQrCodeWithLogo(String content, String logoPath) {
        return generateQrCodeWithLogo(content, logoPath, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static BufferedImage generateQrCodeWithLogo(String content, String logoPath, int width, int height) {
        BufferedImage qrCodeImage = generateQrCodeImage(content, width, height);
        try {
            BufferedImage logoImage = ImageIO.read(new File(logoPath));
            return mergeImageWithLogo(qrCodeImage, logoImage, width, height);
        } catch (IOException e) {
            throw new RuntimeException("生成带Logo的二维码失败", e);
        }
    }

    public static BufferedImage generateQrCodeWithLogo(String content, BufferedImage logoImage) {
        return generateQrCodeWithLogo(content, logoImage, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static BufferedImage generateQrCodeWithLogo(String content, BufferedImage logoImage, int width, int height) {
        BufferedImage qrCodeImage = generateQrCodeImage(content, width, height);
        return mergeImageWithLogo(qrCodeImage, logoImage, width, height);
    }

    public static String generateQrCodeBase64WithLogo(String content, String logoPath) {
        return generateQrCodeBase64WithLogo(content, logoPath, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static String generateQrCodeBase64WithLogo(String content, String logoPath, int width, int height) {
        BufferedImage image = generateQrCodeWithLogo(content, logoPath, width, height);
        return imageToBase64(image);
    }

    public static String generateQrCodeBase64WithLogo(String content, BufferedImage logoImage) {
        return generateQrCodeBase64WithLogo(content, logoImage, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static String generateQrCodeBase64WithLogo(String content, BufferedImage logoImage, int width, int height) {
        BufferedImage image = generateQrCodeWithLogo(content, logoImage, width, height);
        return imageToBase64(image);
    }

    public static BufferedImage generateQrCodeWithText(String content, String bottomText) {
        return generateQrCodeWithText(content, bottomText, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static BufferedImage generateQrCodeWithText(String content, String bottomText, int width, int height) {
        if (StrUtil.isBlank(bottomText)) {
            return generateQrCodeImage(content, width, height);
        }
        BufferedImage qrImage = generateQrCodeImage(content, width, height);
        int textHeight = 50;
        BufferedImage combinedImage = new BufferedImage(width, height + textHeight, BufferedImage.TYPE_INT_RGB);
        Graphics2D g2d = combinedImage.createGraphics();
        g2d.setColor(Color.WHITE);
        g2d.fillRect(0, 0, width, height + textHeight);
        g2d.drawImage(qrImage, 0, 0, null);
        g2d.setColor(Color.BLACK);
        g2d.setFont(new Font("SansSerif", Font.BOLD, 18));
        FontMetrics fm = g2d.getFontMetrics();
        int textWidth = fm.stringWidth(bottomText);
        int textX = (width - textWidth) / 2;
        int textY = height + 30;
        g2d.drawString(bottomText, textX, textY);
        g2d.dispose();
        return combinedImage;
    }

    public static String generateQrCodeBase64WithText(String content, String bottomText) {
        return generateQrCodeBase64WithText(content, bottomText, DEFAULT_WIDTH, DEFAULT_HEIGHT);
    }

    public static String generateQrCodeBase64WithText(String content, String bottomText, int width, int height) {
        BufferedImage image = generateQrCodeWithText(content, bottomText, width, height);
        return imageToBase64(image);
    }

    public static String decodeQrCode(String imagePath) {
        try {
            BufferedImage image = ImageIO.read(new File(imagePath));
            return decodeQrCode(image);
        } catch (IOException e) {
            throw new RuntimeException("读取二维码图片文件失败", e);
        }
    }

    public static String decodeQrCode(byte[] imageBytes) {
        try (ByteArrayInputStream bis = new ByteArrayInputStream(imageBytes)) {
            BufferedImage image = ImageIO.read(bis);
            return decodeQrCode(image);
        } catch (IOException e) {
            throw new RuntimeException("解析二维码字节数据失败", e);
        }
    }

    public static String decodeQrCode(InputStream inputStream) {
        try {
            BufferedImage image = ImageIO.read(inputStream);
            return decodeQrCode(image);
        } catch (IOException e) {
            throw new RuntimeException("解析二维码输入流失败", e);
        }
    }

    public static String decodeQrCode(BufferedImage image) {
        try {
            if (image == null) {
                throw new IllegalArgumentException("二维码图片不能为空");
            }
            LuminanceSource source = new BufferedImageLuminanceSource(image);
            BinaryBitmap bitmap = new BinaryBitmap(new HybridBinarizer(source));
            Map<DecodeHintType, Object> hints = new HashMap<>();
            hints.put(DecodeHintType.CHARACTER_SET, "UTF-8");
            hints.put(DecodeHintType.POSSIBLE_FORMATS, BarcodeFormat.QR_CODE);
            hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
            QRCodeReader reader = new QRCodeReader();
            Result result = reader.decode(bitmap, hints);
            return result.getText();
        } catch (NotFoundException | ChecksumException | FormatException e) {
            throw new RuntimeException("解析二维码内容失败", e);
        }
    }

    public static boolean isValidQrCode(String content) {
        if (StrUtil.isBlank(content)) {
            return false;
        }
        try {
            Map<EncodeHintType, Object> hints = new HashMap<>();
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");
            hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.L);
            hints.put(EncodeHintType.MARGIN, 0);
            new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, 10, 10, hints);
            return true;
        } catch (WriterException e) {
            return false;
        }
    }

    private static BufferedImage mergeImageWithLogo(BufferedImage qrCodeImage, BufferedImage logoImage, int width, int height) {
        try {
            Graphics2D graphics = qrCodeImage.createGraphics();
            graphics.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            graphics.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);

            int logoWidth = width / 5;
            int logoHeight = height / 5;
            int x = (width - logoWidth) / 2;
            int y = (height - logoHeight) / 2;

            int borderWidth = 4;
            graphics.setColor(Color.WHITE);
            graphics.fillRoundRect(x - borderWidth, y - borderWidth,
                    logoWidth + 2 * borderWidth, logoHeight + 2 * borderWidth, 8, 8);
            graphics.setColor(Color.LIGHT_GRAY);
            graphics.drawRoundRect(x - borderWidth, y - borderWidth,
                    logoWidth + 2 * borderWidth, logoHeight + 2 * borderWidth, 8, 8);

            graphics.drawImage(logoImage, x, y, logoWidth, logoHeight, null);
            graphics.dispose();

            return qrCodeImage;
        } catch (Exception e) {
            throw new RuntimeException("合并二维码与Logo失败", e);
        }
    }

    private static String imageToBase64(BufferedImage image) {
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            ImageIO.write(image, DEFAULT_FORMAT, baos);
            byte[] bytes = baos.toByteArray();
            return "data:image/png;base64," + java.util.Base64.getEncoder().encodeToString(bytes);
        } catch (IOException e) {
            throw new RuntimeException("图片转Base64失败", e);
        }
    }
}
