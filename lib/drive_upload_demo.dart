import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// 替换为你的 Client ID (可选，Web 平台可以只在 index.html 配置)
String? clientId;
String? serverClientId;

/// Google Drive 需要的权限
const List<String> scopes = <String>[
  'https://www.googleapis.com/auth/drive.file',
];

class DriveUploadDemo extends StatefulWidget {
  const DriveUploadDemo({super.key});

  @override
  State<DriveUploadDemo> createState() => _DriveUploadDemoState();
}

class _DriveUploadDemoState extends State<DriveUploadDemo> {
  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false;
  String _statusMessage = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    final GoogleSignIn signIn = GoogleSignIn.instance;
    unawaited(signIn
        .initialize(clientId: clientId, serverClientId: serverClientId)
        .then((_) {
      signIn.authenticationEvents
          .listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);
      signIn.attemptLightweightAuthentication();
    }));
  }

  Future<void> _handleAuthenticationEvent(
      GoogleSignInAuthenticationEvent event) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    // 检查是否已有授权
    final GoogleSignInClientAuthorization? authorization =
        await user?.authorizationClient.authorizationForScopes(scopes);

    setState(() {
      _currentUser = user;
      _isAuthorized = authorization != null;
      _errorMessage = '';
    });
  }

  Future<void> _handleAuthenticationError(Object e) async {
    setState(() {
      _currentUser = null;
      _isAuthorized = false;
      _errorMessage = e is GoogleSignInException
          ? 'Sign in error: ${e.code}'
          : 'Unknown error: $e';
    });
  }

  // 请求 Drive 权限
  Future<void> _handleAuthorizeScopes(GoogleSignInAccount user) async {
    try {
      final GoogleSignInClientAuthorization authorization =
          await user.authorizationClient.authorizeScopes(scopes);
      
      setState(() {
        _isAuthorized = true;
        _errorMessage = '';
        _statusMessage = 'Drive 权限已授予！';
      });
    } on GoogleSignInException catch (e) {
      setState(() {
        _errorMessage = 'Authorization failed: ${e.code}';
      });
    }
  }

  // 上传录音到 Google Drive
  Future<void> _uploadRecording() async {
    if (_currentUser == null) {
      setState(() {
        _errorMessage = '请先登录';
      });
      return;
    }

    setState(() {
      _statusMessage = '正在上传...';
      _errorMessage = '';
    });

    try {
      // 获取授权头
      final Map<String, String>? headers =
          await _currentUser!.authorizationClient.authorizationHeaders(scopes);

      if (headers == null) {
        setState(() {
          _statusMessage = '';
          _errorMessage = '无法获取授权，请重新授权';
          _isAuthorized = false;
        });
        return;
      }

      // 创建 HTTP 客户端
      final client = _AuthClient(headers);
      final driveApi = drive.DriveApi(client);

      // 创建模拟的录音数据（在实际应用中替换为真实录音）
      final audioData = _createMockAudioData();

      // 创建文件元数据
      final driveFile = drive.File();
      driveFile.name = 'recording_${DateTime.now().millisecondsSinceEpoch}.webm';
      driveFile.mimeType = 'audio/webm';

      // 创建媒体流
      final media = drive.Media(
        Stream.value(audioData.toList()),
        audioData.length,
      );

      // 上传文件
      final response = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      setState(() {
        _statusMessage = '上传成功！文件 ID: ${response.id}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '';
        _errorMessage = '上传失败: $e';
        if (e.toString().contains('401') || e.toString().contains('403')) {
          _isAuthorized = false;
        }
      });
    }
  }

  // 创建模拟录音数据（仅用于演示）
  Uint8List _createMockAudioData() {
    // 在实际应用中，这里应该是真实的录音数据
    return Uint8List.fromList(List.generate(1000, (i) => i % 256));
  }

  Future<void> _handleSignOut() async {
    await GoogleSignIn.instance.disconnect();
    setState(() {
      _statusMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive 录音上传'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentUser != null) ...[
                // 已登录
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _currentUser!.photoUrl != null
                      ? NetworkImage(_currentUser!.photoUrl!)
                      : null,
                  child: _currentUser!.photoUrl == null
                      ? Text(_currentUser!.displayName?[0] ?? 'U')
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser!.displayName ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(_currentUser!.email),
                const SizedBox(height: 24),
                if (_isAuthorized) ...[
                  // 已授权 Drive 权限
                  const Text('✓ Drive 权限已授予'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _uploadRecording,
                    icon: const Icon(Icons.upload),
                    label: const Text('上传录音到 Drive'),
                  ),
                ] else ...[
                  // 需要授权
                  const Text('需要授权访问 Google Drive'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _handleAuthorizeScopes(_currentUser!),
                    child: const Text('授权 Drive 访问'),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _handleSignOut,
                  child: const Text('登出'),
                ),
              ] else ...[
                // 未登录
                const Text('请先登录 Google 账号'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (GoogleSignIn.instance.supportsAuthenticate()) {
                        await GoogleSignIn.instance.authenticate();
                      } else {
                        // Web 平台或其他不支持 authenticate 的平台
                        // 使用 signIn 方法
                        // final user = await GoogleSignIn.instance.signIn();
                        // if (user == null) {
                        //   setState(() {
                        //     _errorMessage = '登录已取消';
                        //   });
                        // }
                      }
                    } catch (e) {
                      setState(() {
                        _errorMessage = '登录失败: $e';
                      });
                    }
                  },
                  child: const Text('登录 Google'),
                ),
              ],
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusMessage),
                ),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 简单的 HTTP 客户端，用于添加授权头
class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}