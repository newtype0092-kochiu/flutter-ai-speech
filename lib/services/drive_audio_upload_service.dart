import 'dart:async';
import 'dart:typed_data';
import 'drive_api_service.dart';

/// Drive API Service Extension
/// Specifically for uploading audio files to Google Drive AppData
class DriveAudioUploadService {
  static final DriveAudioUploadService _instance = DriveAudioUploadService._internal();
  factory DriveAudioUploadService() => _instance;
  DriveAudioUploadService._internal();

  final DriveApiService _driveService = DriveApiService();

  /// 上传音频文件到AppData文件夹 
  /// 实现：直接上传音频文件本身（WAV格式）
  Future<Map<String, dynamic>?> uploadAudioFile(String fileName, Uint8List audioBytes) async {
    try {
      // 使用Drive API直接上传音频文件
      final fileId = await _driveService.uploadAudioMetadata(fileName, audioBytes);
      
      // 返回上传信息，包含真实的文件ID
      return {
        'fileId': fileId,
        'fileName': fileName,
        'size': audioBytes.length,
        'uploadTime': DateTime.now().millisecondsSinceEpoch,
        'type': 'audio/wav',
        'note': 'Audio file uploaded to Google Drive AppData folder.',
      };
    } catch (e) {
      print('Error uploading audio file: $e');
      rethrow;
    }
  }

}