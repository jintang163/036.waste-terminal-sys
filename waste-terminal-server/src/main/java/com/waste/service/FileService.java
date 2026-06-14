package com.waste.service;

import com.waste.entity.SysFile;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public interface FileService {

    SysFile upload(MultipartFile file, String bizType, Long enterpriseId);

    List<SysFile> uploadBatch(List<MultipartFile> files, String bizType, Long enterpriseId);

    SysFile getById(Long id);

    String getFileUrl(Long id);

    void delete(Long id);
}
