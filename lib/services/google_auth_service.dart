import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

/// Google Authentication Service Class
/// Encapsulates all logic related to Google login and authorization
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  // Permission scopes
  static const List<String> scopes = [
    DriveApi.driveAppdataScope,
  ];

  // 状态变量
  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false;
  String _errorMessage = '';
  String _serverAuthCode = '';

  // 状态变化流控制器
  final StreamController<AuthState> _stateController = StreamController<AuthState>.broadcast();

  // Getters
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthorized => _isAuthorized;
  String get errorMessage => _errorMessage;
  String get serverAuthCode => _serverAuthCode;
  Stream<AuthState> get authStateStream => _stateController.stream;

  /// 初始化Google登录
  Future<void> initialize({String? clientId, String? serverClientId}) async {
    final GoogleSignIn signIn = GoogleSignIn.instance;
    
    await signIn.initialize(
      clientId: clientId, 
      serverClientId: serverClientId
    );
    
    // 监听认证事件
    signIn.authenticationEvents
        .listen(_handleAuthenticationEvent)
        .onError(_handleAuthenticationError);

    // 尝试轻量级认证
    await signIn.attemptLightweightAuthentication();
  }

  /// 处理认证事件
  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    // 检查现有授权
    final GoogleSignInClientAuthorization? authorization = await user
        ?.authorizationClient
        .authorizationForScopes(scopes);

    _currentUser = user;
    _isAuthorized = authorization != null;
    _errorMessage = '';

    _notifyStateChanged();
  }

  /// 处理认证错误
  Future<void> _handleAuthenticationError(Object e) async {
    _currentUser = null;
    _isAuthorized = false;
    _errorMessage = e is GoogleSignInException
        ? _errorMessageFromSignInException(e)
        : 'Unknown error: $e';

    _notifyStateChanged();
  }

  /// 显式登录
  Future<void> signIn() async {
    try {
      _errorMessage = '';
      await GoogleSignIn.instance.authenticate();
      _notifyStateChanged();
    } catch (e) {
      _errorMessage = e.toString();
      _notifyStateChanged();
    }
  }

  /// 授权指定权限范围
  Future<void> authorizeScopes() async {
    if (_currentUser == null) {
      _errorMessage = 'No user signed in';
      _notifyStateChanged();
      return;
    }

    try {
      final GoogleSignInClientAuthorization authorization = await _currentUser!
          .authorizationClient
          .authorizeScopes(scopes);

      // 忽略返回值，因为我们使用状态管理
      // ignore: unnecessary_statements
      authorization;

      _isAuthorized = true;
      _errorMessage = '';
      _notifyStateChanged();
    } on GoogleSignInException catch (e) {
      _errorMessage = _errorMessageFromSignInException(e);
      _notifyStateChanged();
    }
  }

  /// 获取服务器认证码
  Future<void> getServerAuthCode() async {
    if (_currentUser == null) {
      _errorMessage = 'No user signed in';
      _notifyStateChanged();
      return;
    }

    try {
      final GoogleSignInServerAuthorization? serverAuth = await _currentUser!
          .authorizationClient
          .authorizeServer(scopes);

      _serverAuthCode = serverAuth?.serverAuthCode ?? '';
      _notifyStateChanged();
    } on GoogleSignInException catch (e) {
      _errorMessage = _errorMessageFromSignInException(e);
      _notifyStateChanged();
    }
  }

  /// 登出
  Future<void> signOut() async {
    await GoogleSignIn.instance.disconnect();
    _currentUser = null;
    _isAuthorized = false;
    _serverAuthCode = '';
    _errorMessage = '';
    _notifyStateChanged();
  }

  /// 获取已授权的客户端
  Future<GoogleSignInClientAuthorization?> getAuthorizationForScopes() async {
    if (_currentUser == null) return null;
    
    return await _currentUser!.authorizationClient.authorizationForScopes(scopes);
  }

  /// 检查是否支持认证
  bool supportsAuthenticate() {
    return GoogleSignIn.instance.supportsAuthenticate();
  }

  /// 通知状态变化
  void _notifyStateChanged() {
    _stateController.add(AuthState(
      currentUser: _currentUser,
      isAuthorized: _isAuthorized,
      errorMessage: _errorMessage,
      serverAuthCode: _serverAuthCode,
    ));
  }

  /// 将GoogleSignInException转换为错误信息
  String _errorMessageFromSignInException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in canceled',
      _ => 'GoogleSignInException ${e.code}: ${e.description}',
    };
  }

  /// 清理资源
  void dispose() {
    _stateController.close();
  }
}

/// 认证状态数据类
class AuthState {
  final GoogleSignInAccount? currentUser;
  final bool isAuthorized;
  final String errorMessage;
  final String serverAuthCode;

  const AuthState({
    this.currentUser,
    required this.isAuthorized,
    required this.errorMessage,
    required this.serverAuthCode,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.currentUser == currentUser &&
        other.isAuthorized == isAuthorized &&
        other.errorMessage == errorMessage &&
        other.serverAuthCode == serverAuthCode;
  }

  @override
  int get hashCode {
    return currentUser.hashCode ^
        isAuthorized.hashCode ^
        errorMessage.hashCode ^
        serverAuthCode.hashCode;
  }
}