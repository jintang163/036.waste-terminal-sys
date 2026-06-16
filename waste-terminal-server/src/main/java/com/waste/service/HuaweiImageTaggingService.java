package com.waste.service;

import com.waste.config.WasteAiRecognitionConfig;

import java.util.List;

public interface HuaweiImageTaggingService {

    List<ImageTag> tagImage(byte[] imageBytes, WasteAiRecognitionConfig.WasteAiRecognitionProperties properties);

    List<ImageTag> tagImageByUrl(String imageUrl, WasteAiRecognitionConfig.WasteAiRecognitionProperties properties);

    class ImageTag {
        private String tag;
        private Double confidence;
        private String category;

        public ImageTag() {
        }

        public ImageTag(String tag, Double confidence, String category) {
            this.tag = tag;
            this.confidence = confidence;
            this.category = category;
        }

        public String getTag() {
            return tag;
        }

        public void setTag(String tag) {
            this.tag = tag;
        }

        public Double getConfidence() {
            return confidence;
        }

        public void setConfidence(Double confidence) {
            this.confidence = confidence;
        }

        public String getCategory() {
            return category;
        }

        public void setCategory(String category) {
            this.category = category;
        }
    }
}
