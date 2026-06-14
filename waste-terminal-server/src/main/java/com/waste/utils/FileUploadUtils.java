package com.waste.utils;

import cn.hutool.core.date.DateUtil;
import cn.hutool.core.io.FileTypeUtil;
import cn.hutool.core.util.IdUtil;
import cn.hutool.core.util.StrUtil;
import com.waste.config.MinioConfig;
import io.minio.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.Date;

@Component
public class FileUploadUtils {

    @Autowired
    private MinioClient minioClient;

    @Autowired
    private MinioConfig.MinioProperties minioProperties;

    public String uploadFile(MultipartFile file, String bizType) {
        return uploadFile(file, bizType, null);
    }

    public String uploadFile(MultipartFile file, String bizType, String bizId) {
        try {
            String originalFilename = file.getOriginalFilename();
            String fileExt = getFileExt(originalFilename);
            String objectKey = generateObjectKey(bizType, fileExt);

            InputStream inputStream = file.getInputStream();
            String contentType = file.getContentType();

            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(minioProperties.getBucketName())
                            .object(objectKey)
                            .stream(inputStream, file.getSize(), -1)
                            .contentType(contentType)
                            .build()
            );

            return objectKey;
        } catch (Exception e) {
            throw new RuntimeException("文件上传失败", e);
        }
    }

    public String getFileUrl(String objectKey) {
        try {
            return minioClient.getPresignedObjectUrl(
                    GetPresignedObjectUrlArgs.builder()
                            .method(Method.GET)
                            .bucket(minioProperties.getBucketName())
                            .object(objectKey)
                            .expiry(60 * 60 * 24)
                            .build()
            );
        } catch (Exception e) {
            throw new RuntimeException("获取文件访问URL失败", e);
        }
    }

    public InputStream downloadFile(String objectKey) {
        try {
            return minioClient.getObject(
                    GetObjectArgs.builder()
                            .bucket(minioProperties.getBucketName())
                            .object(objectKey)
                            .build()
            );
        } catch (Exception e) {
            throw new RuntimeException("文件下载失败", e);
        }
    }

    public void deleteFile(String objectKey) {
        try {
            minioClient.removeObject(
                    RemoveObjectArgs.builder()
                            .bucket(minioProperties.getBucketName())
                            .object(objectKey)
                            .build()
            );
        } catch (Exception e) {
            throw new RuntimeException("文件删除失败", e);
        }
    }

    public boolean checkFileExists(String objectKey) {
        try {
            minioClient.statObject(
                    StatObjectArgs.builder()
                            .bucket(minioProperties.getBucketName())
                            .object(objectKey)
                            .build()
            );
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private String generateObjectKey(String bizType, String fileExt) {
        String datePath = DateUtil.format(new Date(), "yyyy/MM/dd");
        String fileName = IdUtil.simpleUUID() + fileExt;
        if (StrUtil.isNotBlank(bizType)) {
            return bizType + "/" + datePath + "/" + fileName;
        }
        return datePath + "/" + fileName;
    }

    private String getFileExt(String fileName) {
        if (StrUtil.isBlank(fileName)) {
            return "";
        }
        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0 && dotIndex < fileName.length() - 1) {
            return fileName.substring(dotIndex);
        }
        return "";
    }
}
