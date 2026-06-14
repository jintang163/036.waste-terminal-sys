package com.waste;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 危废智能终端系统启动类
 */
@SpringBootApplication
@MapperScan("com.waste.mapper")
@EnableScheduling
@EnableAsync
public class WasteTerminalApplication {

    public static void main(String[] args) {
        SpringApplication.run(WasteTerminalApplication.class, args);
        System.out.println("============================================");
        System.out.println("  危废智能终端系统启动成功!");
        System.out.println("  接口文档: http://localhost:8080/api/doc.html");
        System.out.println("============================================");
    }
}
