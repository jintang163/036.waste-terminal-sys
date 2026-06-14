package com.waste.service.impl;

import cn.hutool.core.io.FileUtil;
import cn.hutool.core.util.StrUtil;
import com.waste.common.ResultCode;
import com.waste.common.exception.BusinessException;
import com.waste.entity.SysFile;
import com.waste.mapper.SysFileMapper;
import com.waste.service.FileService;
import com.waste.utils.FileUploadUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.List;

@Service
public class FileServiceImpl implements FileService {

    @Autowired
    private FileUploadUtils fileUploadUtils;

    @Autowired
    private SysFileMapper sysFileMapper;

    @Override
    public SysFile upload(MultipartFile file, String bizType, Long enterpriseId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(ResultCode.FILE_UPLOAD_ERROR, "上传文件不能为空");
        }

        try {
            String objectKey = fileUploadUtils.uploadFile(file, bizType);
            String originalFilename = file.getOriginalFilename();

            SysFile sysFile = new SysFile();
            sysFile.setFileName(originalFilename);
            sysFile.setFileUrl(objectKey);
            sysFile.setFileSize(file.getSize());
            sysFile.setFileType(file.getContentType());
            sysFile.setFileExt(FileUtil.extName(originalFilename));
            sysFile.setStorageType("minio");
            sysFile.setBizType(bizType);
            if (enterpriseId != null) {
                sysFile.setEnterpriseId(enterpriseId);
            }

            sysFileMapper.insert(sysFile);
            return sysFile;
        } catch (Exception e) {
            throw new BusinessException(ResultCode.FILE_UPLOAD_ERROR, e.getMessage());
        }
    }

    @Override
    public List<SysFile> uploadBatch(List<MultipartFile> files, String bizType, Long enterpriseId) {
        if (files == null || files.isEmpty()) {
            throw new BusinessException(ResultCode.FILE_UPLOAD_ERROR, "上传文件不能为空");
        }

        List<SysFile> result = new ArrayList<>();
        for (MultipartFile file : files) {
            SysFile sysFile = upload(file, bizType, enterpriseId);
            result.add(sysFile);
        }
        return result;
    }

    @Override
    public SysFile getById(Long id) {
        SysFile sysFile = sysFileMapper.selectById(id);
        if (sysFile == null) {
            throw new BusinessException(ResultCode.FILE_NOT_FOUND);
        }
        return sysFile;
    }

    @Override
    public String getFileUrl(Long id) {
        SysFile sysFile = getById(id);
        if (StrUtil.isBlank(sysFile.getFileUrl())) {
            return "";
        }
        return fileUploadUtils.getFileUrl(sysFile.getFileUrl());
    }

    @Override
    public void delete(Long id) {
        SysFile sysFile = getById(id);
        try {
            if (StrUtil.isNotBlank(sysFile.getFileUrl())) {
                fileUploadUtils.deleteFile(sysFile.getFileUrl());
            }
        } catch (Exception e) {
            // ignore
        }
        sysFileMapper.deleteById(id);
    }
}
