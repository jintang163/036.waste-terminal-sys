package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.Camera;
import com.waste.service.CameraService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/camera")
public class CameraController {

    @Autowired
    private CameraService cameraService;

    @GetMapping("/page")
    public Result<PageResult<Camera>> page(PageQuery pageQuery, Camera camera,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<Camera> page = cameraService.page(pageQuery, camera, enterpriseId);
        PageResult<Camera> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<Camera> getById(@PathVariable Long id) {
        Camera camera = cameraService.getById(id);
        return Result.success(camera);
    }

    @PostMapping
    public Result<Void> add(@RequestBody Camera camera,
                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        cameraService.add(camera, enterpriseId);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody Camera camera) {
        cameraService.update(id, camera);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        cameraService.delete(id);
        return Result.success();
    }

    @GetMapping("/list")
    public Result<List<Camera>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<Camera> list = cameraService.listByEnterpriseId(enterpriseId);
        return Result.success(list);
    }

    @GetMapping("/code/{cameraCode}")
    public Result<Camera> getByCode(@PathVariable String cameraCode,
                                     @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        Camera camera = cameraService.getByCode(cameraCode, enterpriseId);
        return Result.success(camera);
    }

    @PutMapping("/status/{id}")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestParam Integer status) {
        cameraService.updateStatus(id, status);
        return Result.success();
    }

    @PutMapping("/ai/{id}")
    public Result<Void> toggleAi(@PathVariable Long id, @RequestParam Boolean enabled) {
        cameraService.toggleAi(id, enabled);
        return Result.success();
    }

    @GetMapping("/{id}/preview-url")
    public Result<String> getPreviewUrl(@PathVariable Long id) {
        Camera camera = cameraService.getById(id);
        String previewUrl = camera.getRtspUrl();
        if (previewUrl == null || previewUrl.isEmpty()) {
            previewUrl = camera.getHttpUrl();
        }
        return Result.success(previewUrl);
    }

    @GetMapping("/{id}/snapshot-url")
    public Result<String> getSnapshotUrl(@PathVariable Long id) {
        Camera camera = cameraService.getById(id);
        return Result.success(camera.getSnapshotUrl());
    }
}
