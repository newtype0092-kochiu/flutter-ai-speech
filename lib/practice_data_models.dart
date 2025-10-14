/// Data models for speech practice application
import 'dart:typed_data';
import 'opfs_storage_service.dart';

/// Practice group - represents repeated practice of the same content
class PracticeGroup {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final List<PracticeItem> items;

  const PracticeGroup({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.items,
  });

  /// Get native practice item
  PracticeItem? get nativeItem {
    try {
      return items.firstWhere((item) => item.isNative);
    } catch (e) {
      return null;
    }
  }

  /// Get user practice items list
  List<PracticeItem> get userItems {
    return items.where((item) => !item.isNative).toList();
  }

  /// Create from JSON
  factory PracticeGroup.fromJson(Map<String, dynamic> json) {
    return PracticeGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: List<String>.from(json['tags'] as List),
      items: (json['items'] as List)
          .map((item) => PracticeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Create copy with updated fields
  PracticeGroup copyWith({
    String? title,
    DateTime? updatedAt,
    List<String>? tags,
    List<PracticeItem>? items,
  }) {
    return PracticeGroup(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      items: items ?? this.items,
    );
  }

  /// Save to OPFS storage
  Future<void> saveToOPFS() async {
    final fileName = PracticeFileNaming.groupInfoFile(id);
    await OPFSStorageService.saveJsonFile(fileName, toJson());
  }

  /// Load from OPFS storage
  static Future<PracticeGroup?> loadFromOPFS(String groupId) async {
    try {
      final fileName = PracticeFileNaming.groupInfoFile(groupId);
      final data = await OPFSStorageService.readJsonFile(fileName);
      return PracticeGroup.fromJson(data);
    } catch (e) {
      print('Failed to load practice group $groupId: $e');
      return null;
    }
  }

  /// Delete from OPFS storage (including all related files)
  Future<void> deleteFromOPFS() async {
    try {
      // Delete group info file
      final groupFileName = PracticeFileNaming.groupInfoFile(id);
      await OPFSStorageService.deleteFile(groupFileName);

      // Delete all audio and annotation files for this group
      for (final item in items) {
        try {
          await OPFSStorageService.deleteFile(item.audioFile);
        } catch (e) {
          print('Warning: Failed to delete audio file ${item.audioFile}: $e');
        }
        try {
          await OPFSStorageService.deleteFile(item.annotationFile);
        } catch (e) {
          print('Warning: Failed to delete annotation file ${item.annotationFile}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete practice group $id: $e');
    }
  }

  /// Check if group exists in OPFS
  static Future<bool> existsInOPFS(String groupId) async {
    final fileName = PracticeFileNaming.groupInfoFile(groupId);
    return await OPFSStorageService.fileExists(fileName);
  }

  /// List all practice groups in OPFS
  static Future<List<PracticeGroup>> listAllFromOPFS() async {
    try {
      final allFiles = await OPFSStorageService.listFiles();
      final groups = <PracticeGroup>[];

      for (final fileName in allFiles) {
        if (fileName.endsWith('.info')) {
          try {
            final data = await OPFSStorageService.readJsonFile(fileName);
            final group = PracticeGroup.fromJson(data);
            groups.add(group);
          } catch (e) {
            print('Warning: Failed to load group from $fileName: $e');
          }
        }
      }

      // Sort by creation date (newest first)
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    } catch (e) {
      throw Exception('Failed to list practice groups: $e');
    }
  }
}

/// Practice item - represents a single pronunciation practice
class PracticeItem {
  final String id;
  final String groupId;
  final bool isNative;
  final DateTime createdAt;
  final String audioFile;
  final String annotationFile;
  final bool processed;
  final double? score;

  const PracticeItem({
    required this.id,
    required this.groupId,
    required this.isNative,
    required this.createdAt,
    required this.audioFile,
    required this.annotationFile,
    required this.processed,
    this.score,
  });

  /// Generate file name prefix
  String get filePrefix => '$groupId.$id';

  /// Create from JSON
  factory PracticeItem.fromJson(Map<String, dynamic> json) {
    return PracticeItem(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      isNative: json['isNative'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      audioFile: json['audioFile'] as String,
      annotationFile: json['annotationFile'] as String,
      processed: json['processed'] as bool,
      score: json['score'] as double?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'isNative': isNative,
      'createdAt': createdAt.toIso8601String(),
      'audioFile': audioFile,
      'annotationFile': annotationFile,
      'processed': processed,
      'score': score,
    };
  }

  /// Create copy with updated fields
  PracticeItem copyWith({
    bool? processed,
    double? score,
  }) {
    return PracticeItem(
      id: id,
      groupId: groupId,
      isNative: isNative,
      createdAt: createdAt,
      audioFile: audioFile,
      annotationFile: annotationFile,
      processed: processed ?? this.processed,
      score: score ?? this.score,
    );
  }
}

/// Audio annotation data
class AudioAnnotations {
  final String audioFile;
  final double duration;
  final int sampleRate;
  final String transcript;
  final List<WordAnnotation> annotations;
  final bool processed;

  const AudioAnnotations({
    required this.audioFile,
    required this.duration,
    required this.sampleRate,
    required this.transcript,
    required this.annotations,
    required this.processed,
  });

  /// Create empty annotation for unprocessed audio
  factory AudioAnnotations.empty(String audioFile) {
    return AudioAnnotations(
      audioFile: audioFile,
      duration: 0.0,
      sampleRate: 44100,
      transcript: '',
      annotations: [],
      processed: false,
    );
  }

  /// Create from JSON
  factory AudioAnnotations.fromJson(Map<String, dynamic> json) {
    return AudioAnnotations(
      audioFile: json['audioFile'] as String,
      duration: (json['duration'] as num).toDouble(),
      sampleRate: json['sampleRate'] as int,
      transcript: json['transcript'] as String,
      annotations: (json['annotations'] as List)
          .map((annotation) => WordAnnotation.fromJson(annotation as Map<String, dynamic>))
          .toList(),
      processed: json['processed'] as bool,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'audioFile': audioFile,
      'duration': duration,
      'sampleRate': sampleRate,
      'transcript': transcript,
      'annotations': annotations.map((annotation) => annotation.toJson()).toList(),
      'processed': processed,
    };
  }

  /// Create copy with updated fields
  AudioAnnotations copyWith({
    double? duration,
    int? sampleRate,
    String? transcript,
    List<WordAnnotation>? annotations,
    bool? processed,
  }) {
    return AudioAnnotations(
      audioFile: audioFile,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      transcript: transcript ?? this.transcript,
      annotations: annotations ?? this.annotations,
      processed: processed ?? this.processed,
    );
  }

  /// Save to OPFS storage
  Future<void> saveToOPFS(String annotationFileName) async {
    await OPFSStorageService.saveJsonFile(annotationFileName, toJson());
  }

  /// Load from OPFS storage
  static Future<AudioAnnotations?> loadFromOPFS(String annotationFileName) async {
    try {
      final data = await OPFSStorageService.readJsonFile(annotationFileName);
      return AudioAnnotations.fromJson(data);
    } catch (e) {
      print('Failed to load audio annotations from $annotationFileName: $e');
      return null;
    }
  }

  /// Save audio file to OPFS storage
  static Future<void> saveAudioToOPFS(String audioFileName, Uint8List audioData) async {
    await OPFSStorageService.saveBinaryFile(audioFileName, audioData);
  }

  /// Load audio file from OPFS storage
  static Future<Uint8List?> loadAudioFromOPFS(String audioFileName) async {
    try {
      return await OPFSStorageService.readBinaryFile(audioFileName);
    } catch (e) {
      print('Failed to load audio file $audioFileName: $e');
      return null;
    }
  }
}

/// Word annotation data
class WordAnnotation {
  final String word;
  final String phoneme;
  final double startTime;
  final double endTime;

  const WordAnnotation({
    required this.word,
    required this.phoneme,
    required this.startTime,
    required this.endTime,
  });

  /// Get duration of this annotation
  double get duration => endTime - startTime;

  /// Check if a given time falls within this annotation
  bool containsTime(double time) {
    return time >= startTime && time <= endTime;
  }

  /// Create from JSON
  factory WordAnnotation.fromJson(Map<String, dynamic> json) {
    return WordAnnotation(
      word: json['word'] as String,
      phoneme: json['phoneme'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'phoneme': phoneme,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  @override
  String toString() {
    return 'WordAnnotation(word: $word, phoneme: $phoneme, start: ${startTime.toStringAsFixed(2)}s, end: ${endTime.toStringAsFixed(2)}s)';
  }
}

/// File naming utility class
class PracticeFileNaming {
  /// Generate practice group info file name
  static String groupInfoFile(String groupId) => '$groupId.info';

  /// Generate audio file name
  static String audioFile(String groupId, String itemId) => '$groupId.$itemId.wav';

  /// Generate annotation file name
  static String annotationFile(String groupId, String itemId) => '$groupId.$itemId.json';

  /// Generate new user practice item ID
  static String generateUserItemId(List<PracticeItem> existingItems) {
    final userItems = existingItems.where((item) => !item.isNative).toList();
    final nextNumber = userItems.length + 1;
    return nextNumber.toString().padLeft(3, '0'); // 001, 002, 003...
  }

  /// Native practice item fixed ID
  static const String nativeItemId = 'nat';

  /// Generate practice group ID using timestamp
  static String generateGroupId() {
    return 'p${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create native practice item
  static PracticeItem createNativeItem(String groupId) {
    final now = DateTime.now();
    return PracticeItem(
      id: nativeItemId,
      groupId: groupId,
      isNative: true,
      createdAt: now,
      audioFile: audioFile(groupId, nativeItemId),
      annotationFile: annotationFile(groupId, nativeItemId),
      processed: false,
    );
  }

  /// Create user practice item
  static PracticeItem createUserItem(String groupId, List<PracticeItem> existingItems) {
    final itemId = generateUserItemId(existingItems);
    final now = DateTime.now();
    return PracticeItem(
      id: itemId,
      groupId: groupId,
      isNative: false,
      createdAt: now,
      audioFile: audioFile(groupId, itemId),
      annotationFile: annotationFile(groupId, itemId),
      processed: false,
    );
  }
}