package com.waste.gateway;

import cn.hutool.core.util.HexUtil;
import cn.hutool.core.util.NumberUtil;
import cn.hutool.core.util.StrUtil;
import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageDecoder;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
public class ScaleProtocolDecoder extends ByteToMessageDecoder {

    private static final int MAX_FRAME_LENGTH = 1024;

    public enum ProtocolType {
        YAOHUA("耀华", "ST,[GN]T,\\d+\\.?\\d*"),
        KELI("柯力", "WT:\\d+\\.?\\d*"),
        XK3190("XK3190", "[+-]?\\d+\\.\\d{3}"),
        TOSHIBA("东芝", "=\\d+\\.?\\d*\\s*kg"),
        METTLER("梅特勒", "S\\s+\\d+\\.?\\d*\\s*kg"),
        STANDARD("标准", "\\d+\\.?\\d*"),
        CUSTOM("自定义", ".*");

        private final String name;
        private final Pattern pattern;

        ProtocolType(String name, String regex) {
            this.name = name;
            this.pattern = Pattern.compile(regex);
        }

        public String getName() {
            return name;
        }

        public Pattern getPattern() {
            return pattern;
        }
    }

    @Data
    public static class DecodedFrame {
        private String deviceId;
        private ProtocolType protocolType;
        private BigDecimal weight;
        private String unit = "kg";
        private boolean stable;
        private LocalDateTime measureTime;
        private String rawHex;
        private String rawAscii;
    }

    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        if (in.readableBytes() < 2) {
            return;
        }

        in.markReaderIndex();
        int frameLength = findFrameLength(in);

        if (frameLength <= 0) {
            in.resetReaderIndex();
            return;
        }

        if (frameLength > MAX_FRAME_LENGTH) {
            log.warn("地磅数据帧过长, length={}, channel={}", frameLength, ctx.channel().remoteAddress());
            in.skipBytes(in.readableBytes());
            return;
        }

        if (in.readableBytes() < frameLength) {
            in.resetReaderIndex();
            return;
        }

        byte[] frameBytes = new byte[frameLength];
        in.readBytes(frameBytes);

        try {
            DecodedFrame decodedFrame = decodeFrame(frameBytes);
            if (decodedFrame != null) {
                out.add(decodedFrame);
            }
        } catch (Exception e) {
            log.warn("解析地磅数据帧失败, hex={}", HexUtil.encodeHexStr(frameBytes), e);
        }
    }

    private int findFrameLength(ByteBuf in) {
        int readerIndex = in.readerIndex();
        int readableBytes = in.readableBytes();

        for (int i = 0; i < readableBytes - 1; i++) {
            byte b1 = in.getByte(readerIndex + i);
            byte b2 = in.getByte(readerIndex + i + 1);

            if ((b1 == 0x0D && b2 == 0x0A) || (b1 == 0x7E && b2 == 0x7E)) {
                return i + 2;
            }

            if (b1 == 0x0D || b1 == 0x0A) {
                return i + 1;
            }
        }

        if (readableBytes > 100) {
            for (int i = 0; i < readableBytes; i++) {
                byte b = in.getByte(readerIndex + i);
                if (b == 0x02 || b == 0x03) {
                    return i + 1;
                }
            }
        }

        return -1;
    }

    private DecodedFrame decodeFrame(byte[] frameBytes) {
        String hexData = HexUtil.encodeHexStr(frameBytes);
        String asciiData = new String(frameBytes, StandardCharsets.ISO_8859_1);
        String cleanAscii = cleanAscii(asciiData);

        DecodedFrame frame = new DecodedFrame();
        frame.setRawHex(hexData);
        frame.setRawAscii(cleanAscii);
        frame.setMeasureTime(LocalDateTime.now());

        ProtocolType detectedProtocol = detectProtocol(cleanAscii, frameBytes);
        frame.setProtocolType(detectedProtocol);

        switch (detectedProtocol) {
            case YAOHUA:
                parseYaoHua(frame, cleanAscii);
                break;
            case KELI:
                parseKeLi(frame, cleanAscii);
                break;
            case XK3190:
                parseXK3190(frame, cleanAscii, frameBytes);
                break;
            case TOSHIBA:
                parseToshiba(frame, cleanAscii);
                break;
            case METTLER:
                parseMettler(frame, cleanAscii);
                break;
            case STANDARD:
            case CUSTOM:
            default:
                parseStandard(frame, cleanAscii, frameBytes);
                break;
        }

        if (frame.getWeight() == null) {
            parseFallback(frame, frameBytes);
        }

        if (frame.getWeight() != null && frame.getWeight().compareTo(BigDecimal.ZERO) < 0) {
            frame.setWeight(BigDecimal.ZERO);
        }

        return frame;
    }

    private String cleanAscii(String ascii) {
        StringBuilder sb = new StringBuilder();
        for (char c : ascii.toCharArray()) {
            if (c >= 0x20 && c <= 0x7E) {
                sb.append(c);
            }
        }
        return sb.toString().trim();
    }

    private ProtocolType detectProtocol(String ascii, byte[] bytes) {
        if (ascii.contains("ST,") && (ascii.contains("GS,") || ascii.contains("NT,"))) {
            return ProtocolType.YAOHUA;
        }

        if (ascii.contains("WT:") || ascii.contains("wt:")) {
            return ProtocolType.KELI;
        }

        Pattern xkPattern = Pattern.compile("[+-]?\\d+\\.\\d{3}");
        if (xkPattern.matcher(ascii).find()) {
            return ProtocolType.XK3190;
        }

        if (ascii.contains("kg") && ascii.contains("=")) {
            return ProtocolType.TOSHIBA;
        }

        if (ascii.startsWith("S ") && ascii.contains("kg")) {
            return ProtocolType.METTLER;
        }

        if (bytes.length >= 8) {
            boolean hasHeader = false;
            for (byte b : bytes) {
                if (b == 0x02 || b == 0x1B) {
                    hasHeader = true;
                    break;
                }
            }
            if (hasHeader) {
                return ProtocolType.XK3190;
            }
        }

        return ProtocolType.STANDARD;
    }

    private void parseYaoHua(DecodedFrame frame, String ascii) {
        try {
            Pattern gsPattern = Pattern.compile("ST,GS,(\\d+\\.?\\d*)");
            Matcher gsMatcher = gsPattern.matcher(ascii);
            if (gsMatcher.find()) {
                String weightStr = gsMatcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(true);
                    return;
                }
            }

            Pattern ntPattern = Pattern.compile("ST,NT,(\\d+\\.?\\d*)");
            Matcher ntMatcher = ntPattern.matcher(ascii);
            if (ntMatcher.find()) {
                String weightStr = ntMatcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(false);
                    return;
                }
            }

            Pattern anyPattern = Pattern.compile("(?:ST,[GN]T,)(\\d+\\.?\\d*)");
            Matcher anyMatcher = anyPattern.matcher(ascii);
            if (anyMatcher.find()) {
                String weightStr = anyMatcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(ascii.contains("GS"));
                }
            }
        } catch (Exception e) {
            log.debug("解析耀华协议失败, ascii={}", ascii, e);
        }
    }

    private void parseKeLi(DecodedFrame frame, String ascii) {
        try {
            Pattern wtPattern = Pattern.compile("(?:WT:|wt:)([+-]?\\d+\\.?\\d*)");
            Matcher wtMatcher = wtPattern.matcher(ascii);
            if (wtMatcher.find()) {
                String weightStr = wtMatcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(true);
                }
            }
        } catch (Exception e) {
            log.debug("解析柯力协议失败, ascii={}", ascii, e);
        }
    }

    private void parseXK3190(DecodedFrame frame, String ascii, byte[] bytes) {
        try {
            if (bytes.length >= 10) {
                boolean foundSTX = false;
                int dataStart = 0;
                for (int i = 0; i < bytes.length; i++) {
                    if (bytes[i] == 0x02) {
                        foundSTX = true;
                        dataStart = i + 1;
                        break;
                    }
                }

                if (foundSTX && dataStart + 6 <= bytes.length) {
                    StringBuilder sb = new StringBuilder();
                    boolean hasDot = false;
                    for (int i = dataStart; i < Math.min(dataStart + 10, bytes.length); i++) {
                        int b = bytes[i] & 0xFF;
                        if (b == 0x03) {
                            break;
                        }
                        if (b >= 0x30 && b <= 0x39) {
                            sb.append((char) b);
                        } else if (b == 0x2E && !hasDot) {
                            sb.append('.');
                            hasDot = true;
                        } else if (b == 0x2B || b == 0x2D) {
                            if (sb.length() == 0) {
                                sb.append((char) b);
                            }
                        }
                    }
                    String num = sb.toString();
                    if (NumberUtil.isNumber(num)) {
                        frame.setWeight(new BigDecimal(num));
                        frame.setStable(true);
                        return;
                    }
                }
            }

            Pattern numPattern = Pattern.compile("[+-]?\\d+\\.\\d{3}");
            Matcher numMatcher = numPattern.matcher(ascii);
            if (numMatcher.find()) {
                String num = numMatcher.group();
                if (NumberUtil.isNumber(num)) {
                    frame.setWeight(new BigDecimal(num));
                    frame.setStable(!ascii.contains("?"));
                }
            }
        } catch (Exception e) {
            log.debug("解析XK3190协议失败, ascii={}", ascii, e);
        }
    }

    private void parseToshiba(DecodedFrame frame, String ascii) {
        try {
            Pattern pattern = Pattern.compile("=([+-]?\\d+\\.?\\d*)\\s*kg");
            Matcher matcher = pattern.matcher(ascii);
            if (matcher.find()) {
                String weightStr = matcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(true);
                }
            }
        } catch (Exception e) {
            log.debug("解析东芝协议失败, ascii={}", ascii, e);
        }
    }

    private void parseMettler(DecodedFrame frame, String ascii) {
        try {
            Pattern pattern = Pattern.compile("S\\s+([+-]?\\d+\\.?\\d*)\\s*kg");
            Matcher matcher = pattern.matcher(ascii);
            if (matcher.find()) {
                String weightStr = matcher.group(1);
                if (NumberUtil.isNumber(weightStr)) {
                    frame.setWeight(new BigDecimal(weightStr));
                    frame.setStable(true);
                }
            }
        } catch (Exception e) {
            log.debug("解析梅特勒协议失败, ascii={}", ascii, e);
        }
    }

    private void parseStandard(DecodedFrame frame, String ascii, byte[] bytes) {
        try {
            if (StrUtil.isNotBlank(ascii)) {
                String[] patterns = {
                        "(\\d+\\.\\d{2,3})",
                        "([+-]?\\d+\\.\\d+)",
                        "(\\d{5,}\\.\\d+)",
                        "(\\d+)"
                };

                for (String regex : patterns) {
                    Pattern p = Pattern.compile(regex);
                    Matcher m = p.matcher(ascii);
                    if (m.find()) {
                        String num = m.group(1);
                        if (NumberUtil.isNumber(num) && num.length() >= 3) {
                            BigDecimal weight = new BigDecimal(num);
                            if (weight.compareTo(new BigDecimal("0.001")) >= 0) {
                                frame.setWeight(weight);
                                frame.setStable(true);
                                return;
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.debug("解析标准协议失败, ascii={}", ascii, e);
        }
    }

    private void parseFallback(DecodedFrame frame, byte[] bytes) {
        try {
            if (bytes.length < 4) {
                return;
            }

            int dataStart = Math.max(0, bytes.length - 8);
            StringBuilder sb = new StringBuilder();
            boolean hasDot = false;

            for (int i = dataStart; i < bytes.length; i++) {
                int b = bytes[i] & 0xFF;
                if (b >= 0x30 && b <= 0x39) {
                    sb.append((char) b);
                } else if (b == 0x2E && !hasDot) {
                    sb.append('.');
                    hasDot = true;
                } else if (b == 0x2B || b == 0x2D) {
                    if (sb.length() == 0) {
                        sb.append((char) b);
                    }
                }
            }

            String num = sb.toString();
            if (NumberUtil.isNumber(num) && num.length() >= 3) {
                BigDecimal weight = new BigDecimal(num);
                if (weight.compareTo(BigDecimal.ZERO) >= 0) {
                    frame.setWeight(weight);
                    frame.setStable(true);
                }
            }
        } catch (Exception e) {
            log.debug("Fallback解析失败, hex={}", HexUtil.encodeHexStr(bytes), e);
        }
    }

    public static boolean validateChecksum(byte[] data) {
        if (data == null || data.length < 3) {
            return true;
        }

        int checksum = 0;
        for (int i = 1; i < data.length - 2; i++) {
            checksum ^= data[i];
        }

        int receivedChecksum;
        try {
            String hex = String.format("%02X%02X", data[data.length - 2], data[data.length - 1]);
            receivedChecksum = Integer.parseInt(hex, 16);
        } catch (Exception e) {
            return true;
        }

        return checksum == receivedChecksum;
    }
}
