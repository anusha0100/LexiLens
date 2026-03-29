class DocumentModel {
  final String? id;
  final String userId;
  final String name;
  final String content;
  final String? filePath;
  final DateTime uploadedDate;
  final DateTime? lastReadDate;
  final List<String> tags;
  final bool isFavorite;
  final String? detectedLanguage;
  final String? detectedScript;

  // ── Fields added to match SDS ER diagram ──────────────────────────────────
  // MIME sub-type of the source image, e.g. 'jpeg', 'png', 'webp'.
  final String? imageFormat;

  // Average ML Kit confidence score across all recognised text blocks (0–1).
  final double? ocrConfidence;

  // Wall-clock milliseconds taken by the OCR pipeline for this document.
  final int? processingTimeMs;

  DocumentModel({
    this.id,
    required this.userId,
    required this.name,
    required this.content,
    this.filePath,
    required this.uploadedDate,
    this.lastReadDate,
    this.tags = const [],
    this.isFavorite = false,
    this.detectedLanguage,
    this.detectedScript,
    this.imageFormat,
    this.ocrConfidence,
    this.processingTimeMs,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) '_id': id,
        'userId': userId,
        'fileName': name,
        'documentText': content,
        if (filePath != null) 'filePath': filePath,
        'uploadedDate': uploadedDate.toIso8601String(),
        if (lastReadDate != null) 'lastReadDate': lastReadDate!.toIso8601String(),
        'tags': tags,
        'isFavorite': isFavorite,
        if (detectedLanguage != null) 'detectedLanguage': detectedLanguage,
        if (detectedScript != null) 'detectedScript': detectedScript,
        if (imageFormat != null) 'imageFormat': imageFormat,
        if (ocrConfidence != null) 'ocrConfidence': ocrConfidence,
        if (processingTimeMs != null) 'processingTimeMs': processingTimeMs,
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        id: json['_id']?.toString(),
        userId: json['userId'] ?? '',
        name: json['fileName'] ?? 'Untitled',
        content: json['documentText'] ?? '',
        filePath: json['filePath'],
        uploadedDate: json['uploadedDate'] != null
            ? DateTime.parse(json['uploadedDate'])
            : DateTime.now(),
        lastReadDate: json['lastReadDate'] != null
            ? DateTime.parse(json['lastReadDate'])
            : null,
        tags: List<String>.from(json['tags'] ?? []),
        isFavorite: json['isFavorite'] ?? false,
        detectedLanguage: json['detectedLanguage'],
        detectedScript: json['detectedScript'],
        imageFormat: json['imageFormat'],
        ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
        processingTimeMs: (json['processingTimeMs'] as num?)?.toInt(),
      );
}