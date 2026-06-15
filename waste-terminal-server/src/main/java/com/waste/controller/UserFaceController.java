package com.waste.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.waste.common.PageQuery;
import com.waste.common.PageResult;
import com.waste.common.Result;
import com.waste.entity.UserFace;
import com.waste.service.UserFaceService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/user-face")
public class UserFaceController {

    @Autowired
    private UserFaceService userFaceService;

    @GetMapping("/page")
    public Result<PageResult<UserFace>> page(PageQuery pageQuery, UserFace userFace,
                                              @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        IPage<UserFace> page = userFaceService.page(pageQuery, userFace, enterpriseId);
        PageResult<UserFace> pageResult = PageResult.of(page.getTotal(), page.getCurrent(),
                page.getSize(), page.getRecords());
        return Result.success(pageResult);
    }

    @GetMapping("/{id}")
    public Result<UserFace> getById(@PathVariable Long id) {
        UserFace userFace = userFaceService.getById(id);
        return Result.success(userFace);
    }

    @GetMapping("/user/{userId}")
    public Result<UserFace> getByUserId(@PathVariable Long userId,
                                         @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        UserFace userFace = userFaceService.getByUserId(userId, enterpriseId);
        return Result.success(userFace);
    }

    @GetMapping("/username/{username}")
    public Result<UserFace> getByUsername(@PathVariable String username,
                                           @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        UserFace userFace = userFaceService.getByUsername(username, enterpriseId);
        return Result.success(userFace);
    }

    @GetMapping("/face/{faceId}")
    public Result<UserFace> getByFaceId(@PathVariable String faceId,
                                         @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        UserFace userFace = userFaceService.getByFaceId(faceId, enterpriseId);
        return Result.success(userFace);
    }

    @PostMapping
    public Result<Map<String, Object>> add(@RequestBody UserFace userFace,
                                            @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        userFaceService.add(userFace, enterpriseId);
        Map<String, Object> data = new HashMap<>();
        data.put("id", userFace.getId());
        data.put("faceId", userFace.getFaceId());
        return Result.success(data);
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody UserFace userFace) {
        userFaceService.update(id, userFace);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        userFaceService.delete(id);
        return Result.success();
    }

    @GetMapping("/list")
    public Result<List<UserFace>> list(@RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        List<UserFace> list = userFaceService.listByEnterpriseId(enterpriseId);
        return Result.success(list);
    }

    @PutMapping("/status/{id}")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestParam Integer status) {
        userFaceService.updateStatus(id, status);
        return Result.success();
    }

    @PostMapping("/sync")
    public Result<Map<String, Object>> syncFaceData(@RequestBody UserFace userFace,
                                                     @RequestParam(required = false) Long enterpriseId) {
        if (enterpriseId == null) {
            enterpriseId = 1L;
        }
        UserFace exist = null;
        if (userFace.getFaceId() != null) {
            exist = userFaceService.getByFaceId(userFace.getFaceId(), enterpriseId);
        }
        if (exist == null && userFace.getUserId() != null) {
            exist = userFaceService.getByUserId(userFace.getUserId(), enterpriseId);
        }

        Map<String, Object> data = new HashMap<>();
        if (exist == null) {
            userFaceService.add(userFace, enterpriseId);
            data.put("id", userFace.getId());
            data.put("action", "insert");
        } else {
            userFaceService.update(exist.getId(), userFace);
            data.put("id", exist.getId());
            data.put("action", "update");
        }
        data.put("faceId", userFace.getFaceId());
        return Result.success(data);
    }
}
