class WasteAiRecognitionResult {
  final int? catalogId;
  final String? wasteCode;
  final String? wasteName;
  final String? wasteCategory;
  final String? wasteType;
  final String? hazardCode;
  final String? disposalMethod;
  final String? storageRequirement;
  final String? safetyMeasures;
  final double? confidence;
  final String? description;

  WasteAiRecognitionResult({
    this.catalogId,
    this.wasteCode,
    this.wasteName,
    this.wasteCategory,
    this.wasteType,
    this.hazardCode,
    this.disposalMethod,
    this.storageRequirement,
    this.safetyMeasures,
    this.confidence,
    this.description,
  });

  factory WasteAiRecognitionResult.fromJson(Map<String, dynamic> json) {
    return WasteAiRecognitionResult(
      catalogId: json['catalogId'] as int?,
      wasteCode: json['wasteCode'] as String?,
      wasteName: json['wasteName'] as String?,
      wasteCategory: json['wasteCategory'] as String?,
      wasteType: json['wasteType'] as String?,
      hazardCode: json['hazardCode'] as String?,
      disposalMethod: json['disposalMethod'] as String?,
      storageRequirement: json['storageRequirement'] as String?,
      safetyMeasures: json['safetyMeasures'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'catalogId': catalogId,
      'wasteCode': wasteCode,
      'wasteName': wasteName,
      'wasteCategory': wasteCategory,
      'wasteType': wasteType,
      'hazardCode': hazardCode,
      'disposalMethod': disposalMethod,
      'storageRequirement': storageRequirement,
      'safetyMeasures': safetyMeasures,
      'confidence': confidence,
      'description': description,
    };
  }
}

class WasteAiRecognitionResponse {
  final bool success;
  final String? message;
  final String? imageUrl;
  final List<WasteAiRecognitionResult>? results;
  final DateTime? recognitionTime;
  final String? provider;
  final int? processingTime;

  WasteAiRecognitionResponse({
    required this.success,
    this.message,
    this.imageUrl,
    this.results,
    this.recognitionTime,
    this.provider,
    this.processingTime,
  });

  factory WasteAiRecognitionResponse.fromJson(Map<String, dynamic> json) {
    return WasteAiRecognitionResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      imageUrl: json['imageUrl'] as String?,
      results: (json['results'] as List<dynamic>?)
          ?.map((e) => WasteAiRecognitionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      recognitionTime: json['recognitionTime'] != null
          ? DateTime.tryParse(json['recognitionTime'] as String)
          : null,
      provider: json['provider'] as String?,
      processingTime: json['processingTime'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'imageUrl': imageUrl,
      'results': results?.map((e) => e.toJson()).toList(),
      'recognitionTime': recognitionTime?.toIso8601String(),
      'provider': provider,
      'processingTime': processingTime,
    };
  }
}
