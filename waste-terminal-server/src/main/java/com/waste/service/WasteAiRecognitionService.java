package com.waste.service;

import com.waste.dto.WasteAiRecognitionDTO;
import org.springframework.web.multipart.MultipartFile;

public interface WasteAiRecognitionService {

    WasteAiRecognitionDTO.WasteAiRecognitionResponse recognizeWaste(MultipartFile imageFile, Long enterpriseId);
}
