import 'dart:async';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'google_auth_service.dart';

/// Drive API服务类
/// 封装所有与Google Drive API相关的操作
class DriveApiService {
  static final DriveApiService _instance = DriveApiService._internal();
  factory DriveApiService() => _instance;
  DriveApiService._internal();

  final GoogleAuthService _authService = GoogleAuthService();

  // 状态变量
  List<File> _fileList = [];
  bool _isLoadingFiles = false;
  String _errorMessage = '';

  // 状态变化流控制器
  final StreamController<DriveApiState> _stateController = StreamController<DriveApiState>.broadcast();

  // Getters
  List<File> get fileList => _fileList;
  bool get isLoadingFiles => _isLoadingFiles;
  String get errorMessage => _errorMessage;
  Stream<DriveApiState> get driveStateStream => _stateController.stream;

  /// 获取已认证的Drive API客户端
  Future<DriveApi?> _getDriveApi() async {
    final authorization = await _authService.getAuthorizationForScopes();
    if (authorization == null) {
      _setError('Not authorized for Drive access');
      return null;
    }

    final authenticatedClient = authorization.authClient(
      scopes: GoogleAuthService.scopes,
    );
    
    return DriveApi(authenticatedClient);
  }

  /// 上传文件到appdata文件夹
  Future<void> uploadFile() async {
    try {
      _setError(''); // 清除之前的错误
      
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      // 生成 JSON 文件内容
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileContent = jsonEncode({
        'upload_time': timestamp,
      });
      final fileName = '$timestamp.json';

      // 创建文件元数据
      final fileMetadata = File()
        ..name = fileName
        ..parents = ['appDataFolder']; // 指定上传到 appdata 文件夹

      // 将字符串转换为字节流
      final bytes = fileContent.codeUnits;

      // 创建媒体内容
      final media = Media(
        Stream.fromIterable([bytes]),
        bytes.length,
        contentType: 'application/json',
      );

      // 上传文件
      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      print('File uploaded successfully!');
      print('File ID: ${uploadedFile.id}');
      print('File Name: ${uploadedFile.name}');
      print('File Size: ${uploadedFile.size}');

      // 上传成功后刷新文件列表
      await listFiles();
      
    } catch (e) {
      _setError('Error uploading file: $e');
      print('Error uploading file: $e');
    }
  }

  /// 获取appdata文件夹中的文件列表
  Future<void> listFiles() async {
    try {
      _setLoadingState(true);
      _setError(''); // 清除之前的错误

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        _setLoadingState(false);
        return;
      }

      // 获取 appdata 文件夹中的文件列表
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
      );

      _fileList = fileList.files ?? [];
      _setLoadingState(false);

      print('Found ${_fileList.length} files in appdata folder');
      _notifyStateChanged();
      
    } catch (e) {
      _setLoadingState(false);
      _setError('Error listing files: $e');
      print('Error listing files: $e');
    }
  }

  /// 删除指定文件
  Future<void> deleteFile(String fileId, String fileName) async {
    try {
      _setError(''); // 清除之前的错误
      
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      await driveApi.files.delete(fileId);

      print('File deleted successfully: $fileName');

      // 删除成功后刷新文件列表
      await listFiles();
      
    } catch (e) {
      _setError('Error deleting file: $e');
      print('Error deleting file: $e');
    }
  }

  /// 设置加载状态
  void _setLoadingState(bool isLoading) {
    _isLoadingFiles = isLoading;
    _notifyStateChanged();
  }

  /// 设置错误信息
  void _setError(String error) {
    _errorMessage = error;
    _notifyStateChanged();
  }

  /// 通知状态变化
  void _notifyStateChanged() {
    _stateController.add(DriveApiState(
      fileList: List.from(_fileList),
      isLoadingFiles: _isLoadingFiles,
      errorMessage: _errorMessage,
    ));
  }

  /// 清理资源
  void dispose() {
    _stateController.close();
  }
}

/// Drive API状态数据类
class DriveApiState {
  final List<File> fileList;
  final bool isLoadingFiles;
  final String errorMessage;

  const DriveApiState({
    required this.fileList,
    required this.isLoadingFiles,
    required this.errorMessage,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriveApiState &&
        other.fileList.length == fileList.length &&
        other.isLoadingFiles == isLoadingFiles &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return fileList.length.hashCode ^
        isLoadingFiles.hashCode ^
        errorMessage.hashCode;
  }
}