package com.waste.utils;

import cn.hutool.crypto.BCUtil;
import cn.hutool.crypto.SmUtil;
import cn.hutool.crypto.asymmetric.KeyType;
import cn.hutool.crypto.asymmetric.SM2;
import cn.hutool.crypto.symmetric.SM4;
import org.bouncycastle.crypto.engines.SM2Engine;
import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.PrivateKey;
import java.security.PublicKey;

public class SmUtils {

    public static KeyPair generateSm2KeyPair() {
        return BCUtil.generateSm2KeyPair();
    }

    public static String sm2Encrypt(String publicKeyStr, String data) {
        SM2 sm2 = SmUtil.sm2(null, publicKeyStr);
        return sm2.encryptBase64(data, KeyType.PublicKey);
    }

    public static String sm2Decrypt(String privateKeyStr, String encryptedData) {
        SM2 sm2 = SmUtil.sm2(privateKeyStr, null);
        return sm2.decryptStr(encryptedData, KeyType.PrivateKey);
    }

    public static String sm2Sign(String privateKeyStr, String data) {
        SM2 sm2 = SmUtil.sm2(privateKeyStr, null);
        return sm2.signHex(data);
    }

    public static boolean sm2Verify(String publicKeyStr, String data, String sign) {
        SM2 sm2 = SmUtil.sm2(null, publicKeyStr);
        return sm2.verifyHex(data, sign);
    }

    public static String sm2Encrypt(PublicKey publicKey, String data) {
        byte[] publicKeyBytes = BCUtil.encodeECPublicKey(publicKey);
        String publicKeyHex = cn.hutool.core.util.HexUtil.encodeHexStr(publicKeyBytes);
        SM2 sm2 = SmUtil.sm2(null, publicKeyHex);
        return sm2.encryptBase64(data, KeyType.PublicKey);
    }

    public static String sm2Decrypt(PrivateKey privateKey, String encryptedData) {
        byte[] privateKeyBytes = BCUtil.encodeECPrivateKey(privateKey);
        String privateKeyHex = cn.hutool.core.util.HexUtil.encodeHexStr(privateKeyBytes);
        SM2 sm2 = SmUtil.sm2(privateKeyHex, null);
        return sm2.decryptStr(encryptedData, KeyType.PrivateKey);
    }

    public static String sm2Sign(PrivateKey privateKey, String data) {
        byte[] privateKeyBytes = BCUtil.encodeECPrivateKey(privateKey);
        String privateKeyHex = cn.hutool.core.util.HexUtil.encodeHexStr(privateKeyBytes);
        SM2 sm2 = SmUtil.sm2(privateKeyHex, null);
        return sm2.signHex(data);
    }

    public static boolean sm2Verify(PublicKey publicKey, String data, String sign) {
        byte[] publicKeyBytes = BCUtil.encodeECPublicKey(publicKey);
        String publicKeyHex = cn.hutool.core.util.HexUtil.encodeHexStr(publicKeyBytes);
        SM2 sm2 = SmUtil.sm2(null, publicKeyHex);
        return sm2.verifyHex(data, sign);
    }

    public static String sm4Encrypt(String key, String data) {
        SM4 sm4 = SmUtil.sm4(key.getBytes(StandardCharsets.UTF_8));
        return sm4.encryptBase64(data);
    }

    public static String sm4Decrypt(String key, String encryptedData) {
        SM4 sm4 = SmUtil.sm4(key.getBytes(StandardCharsets.UTF_8));
        return sm4.decryptStr(encryptedData);
    }

    public static byte[] sm4Encrypt(byte[] key, byte[] data) {
        SM4 sm4 = SmUtil.sm4(key);
        return sm4.encrypt(data);
    }

    public static byte[] sm4Decrypt(byte[] key, byte[] encryptedData) {
        SM4 sm4 = SmUtil.sm4(key);
        return sm4.decrypt(encryptedData);
    }

    public static String sm3(String data) {
        return SmUtil.sm3(data);
    }

    public static String sm3(byte[] data) {
        return SmUtil.sm3(data);
    }
}
