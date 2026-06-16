package com.waste.utils;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

public class HuaweiApigwSigner {

    private static final String ALGORITHM = "SDK-HMAC-SHA256";
    private static final String HMAC_SHA256 = "HmacSHA256";
    private static final String SHA_256 = "SHA-256";
    private static final String DATE_FORMAT = "yyyyMMdd'T'HHmmss'Z'";
    private static final String DATE_SHORT_FORMAT = "yyyyMMdd";
    private static final String X_SDK_DATE = "X-Sdk-Date";
    private static final String HOST = "Host";
    private static final String CONTENT_TYPE = "Content-Type";

    public static String sign(String ak, String sk, String method, String url, Map<String, String> headers, String body) {
        URI uri = URI.create(url);
        String host = uri.getHost();
        int port = uri.getPort();
        if (port != -1 && port != 80 && port != 443) {
            host = host + ":" + port;
        }

        Map<String, String> allHeaders = new HashMap<>(headers);
        allHeaders.put(HOST, host);

        String date = allHeaders.get(X_SDK_DATE);
        if (date == null || date.isEmpty()) {
            SimpleDateFormat sdf = new SimpleDateFormat(DATE_FORMAT, Locale.US);
            sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
            date = sdf.format(new Date());
            allHeaders.put(X_SDK_DATE, date);
        }

        String dateShort = date.substring(0, 8);
        String canonicalUri = uri.getPath();
        if (canonicalUri == null || canonicalUri.isEmpty()) {
            canonicalUri = "/";
        }

        String canonicalQueryString = buildCanonicalQueryString(uri.getRawQuery());
        String signedHeaders = getSignedHeaders(allHeaders);
        String canonicalHeaders = buildCanonicalHeaders(allHeaders, signedHeaders);

        String hashedPayload;
        if (body == null) {
            body = "";
        }
        hashedPayload = toHex(sha256(body.getBytes(StandardCharsets.UTF_8)));

        String canonicalRequest = buildCanonicalRequest(method, canonicalUri, canonicalQueryString,
                canonicalHeaders, signedHeaders, hashedPayload);
        String hashedCanonicalRequest = toHex(sha256(canonicalRequest.getBytes(StandardCharsets.UTF_8)));

        String credentialScope = dateShort + "/sdk_request";
        String stringToSign = buildStringToSign(date, credentialScope, hashedCanonicalRequest);

        String signature = getSignature(sk, dateShort, credentialScope, stringToSign);

        return ALGORITHM + " " +
                "Credential=" + ak + "/" + credentialScope + ", " +
                "SignedHeaders=" + signedHeaders + ", " +
                "Signature=" + signature;
    }

    private static String buildCanonicalRequest(String method, String canonicalUri, String canonicalQueryString,
                                                 String canonicalHeaders, String signedHeaders, String hashedPayload) {
        return method + "\n" +
                canonicalUri + "\n" +
                canonicalQueryString + "\n" +
                canonicalHeaders + "\n" +
                signedHeaders + "\n" +
                hashedPayload;
    }

    private static String buildStringToSign(String date, String credentialScope, String hashedCanonicalRequest) {
        return ALGORITHM + "\n" +
                date + "\n" +
                credentialScope + "\n" +
                hashedCanonicalRequest;
    }

    private static String getSignature(String sk, String date, String credentialScope, String stringToSign) {
        byte[] kSecret = ("SDK" + sk).getBytes(StandardCharsets.UTF_8);
        byte[] kDate = hmacSha256(kSecret, date);
        byte[] kSigning = hmacSha256(kDate, "sdk_request");
        byte[] signature = hmacSha256(kSigning, stringToSign);
        return toHex(signature);
    }

    private static String getSignedHeaders(Map<String, String> headers) {
        List<String> sortedHeaders = new ArrayList<>();
        for (String key : headers.keySet()) {
            sortedHeaders.add(key.toLowerCase(Locale.US));
        }
        Collections.sort(sortedHeaders);
        return String.join(";", sortedHeaders);
    }

    private static String buildCanonicalHeaders(Map<String, String> headers, String signedHeaders) {
        StringBuilder sb = new StringBuilder();
        String[] signedHeadersArray = signedHeaders.split(";");
        for (String header : signedHeadersArray) {
            String value = null;
            for (Map.Entry<String, String> entry : headers.entrySet()) {
                if (entry.getKey().toLowerCase(Locale.US).equals(header)) {
                    value = entry.getValue();
                    break;
                }
            }
            if (value == null) {
                value = "";
            }
            sb.append(header).append(":").append(value.trim()).append("\n");
        }
        return sb.toString();
    }

    private static String buildCanonicalQueryString(String query) {
        if (query == null || query.isEmpty()) {
            return "";
        }
        Map<String, String> queryParams = new HashMap<>();
        String[] pairs = query.split("&");
        for (String pair : pairs) {
            if (pair.isEmpty()) {
                continue;
            }
            int idx = pair.indexOf("=");
            String key;
            String value;
            if (idx == -1) {
                key = pair;
                value = "";
            } else {
                key = pair.substring(0, idx);
                value = pair.substring(idx + 1);
            }
            queryParams.put(key, value);
        }
        List<String> sortedKeys = new ArrayList<>(queryParams.keySet());
        Collections.sort(sortedKeys);
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (String key : sortedKeys) {
            if (!first) {
                sb.append("&");
            }
            first = false;
            sb.append(uriEncode(key, true)).append("=").append(uriEncode(queryParams.get(key), true));
        }
        return sb.toString();
    }

    private static String toHex(byte[] data) {
        StringBuilder sb = new StringBuilder();
        for (byte b : data) {
            String hex = Integer.toHexString(b & 0xFF);
            if (hex.length() == 1) {
                sb.append('0');
            }
            sb.append(hex);
        }
        return sb.toString();
    }

    private static byte[] hmacSha256(byte[] key, String data) {
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256);
            SecretKeySpec secretKeySpec = new SecretKeySpec(key, HMAC_SHA256);
            mac.init(secretKeySpec);
            return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new RuntimeException("HMAC-SHA256 error", e);
        }
    }

    private static byte[] sha256(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance(SHA_256);
            return md.digest(data);
        } catch (Exception e) {
            throw new RuntimeException("SHA-256 error", e);
        }
    }

    private static String uriEncode(String value, boolean encodeSlash) {
        if (value == null) {
            return "";
        }
        try {
            String encoded = URLEncoder.encode(value, StandardCharsets.UTF_8.name());
            encoded = encoded.replace("+", "%20");
            encoded = encoded.replace("*", "%2A");
            encoded = encoded.replace("%7E", "~");
            if (!encodeSlash) {
                encoded = encoded.replace("%2F", "/");
            }
            return encoded;
        } catch (Exception e) {
            throw new RuntimeException("URI encode error", e);
        }
    }
}
