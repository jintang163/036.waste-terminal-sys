package com.waste.controller;

import com.waste.common.Result;
import com.waste.entity.SysFile;
import com.waste.service.FileService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/file")
public class FileController {

    @Autowired
    private FileService fileService;

    @PostMapping("/upload")
    public Result<SysFile> upload(@RequestParam("file") MultipartFile file,
                                  @RequestParam(required = false) String bizType,
                                  @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        SysFile sysFile = fileService.upload(file, bizType, enterpriseId);
        return Result.success(sysFile);
    }

    @PostMapping("/upload/batch")
    public Result<List<SysFile>> uploadBatch(@RequestParam("files") List<MultipartFile> files,
                                             @RequestParam(required = false) String bizType,
                                             @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<SysFile> list = fileService.uploadBatch(files, bizType, enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/{id}")
    public Result<SysFile> getById(@PathVariable Long id) {
        SysFile sysFile = fileService.getById(id);
        return Result.success(sysFile);
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        fileService.delete(id);
        return Result.success();
    }
}
