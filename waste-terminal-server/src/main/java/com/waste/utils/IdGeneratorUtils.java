package com.waste.utils;

import cn.hutool.core.lang.Snowflake;
import cn.hutool.core.util.IdUtil;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class IdGeneratorUtils {

    private static final Snowflake snowflake = IdUtil.getSnowflake(1, 1);

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    public static Long nextId() {
        return snowflake.nextId();
    }

    public static String nextIdStr() {
        return snowflake.nextIdStr();
    }

    public static String generateInNo() {
        return "RK" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateOutNo() {
        return "CK" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateTransferOrderNo() {
        return "LD" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateCheckNo() {
        return "PD" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateWarningNo() {
        return "YJ" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateSyncNo() {
        return "TB" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateLedgerNo() {
        return "TZ" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }

    public static String generateLedgerReportLogNo() {
        return "RZ" + LocalDateTime.now().format(DATE_FORMATTER) + String.format("%04d", snowflake.nextId() % 10000);
    }
}
