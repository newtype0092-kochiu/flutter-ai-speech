import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import '../services/drive_api_service.dart';
import '../src/web_wrapper.dart' as web;

/// Google Drive AppData Demo Page
/// Demonstrates Google login and Drive file management functionality
class SignInDemo extends StatefulWidget {
  /// Client ID, optional
  final String? clientId;
  
  /// Server client ID, optional
  final String? serverClientId;
  
  const SignInDemo({
    super.key,
    this.clientId,
    this.serverClientId,
  });

  @override
  State createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> with AutomaticKeepAliveClientMixin {
  final GoogleAuthService _authService = GoogleAuthService();
  final DriveApiService _driveService = DriveApiService();
  
  // Current state
  AuthState _authState = const AuthState(
    isAuthorized: false,
    errorMessage: '',
    serverAuthCode: '',
  );
  
  DriveApiState _driveState = const DriveApiState(
    fileList: [],
    isLoadingFiles: false,
    errorMessage: '',
  );

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<DriveApiState>? _driveSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Listen to authentication state changes
    _authSubscription = _authService.authStateStream.listen((state) {
      final wasAuthorized = _authState.isAuthorized;
      setState(() {
        _authState = state;
      });
      
      // If just completed authorization, automatically load file list
      if (state.isAuthorized && !wasAuthorized) {
        _driveService.listFiles();
      }
    });
    
    // Listen to Drive API state changes
    _driveSubscription = _driveService.driveStateStream.listen((state) {
      setState(() {
        _driveState = state;
      });
    });

    // Initialize authentication service
    _authService.initialize(
      clientId: widget.clientId,
      serverClientId: widget.serverClientId,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _driveSubscription?.cancel();
    super.dispose();
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_authState.currentUser != null)
            ..._buildAuthenticatedWidgets()
          else
            ..._buildUnauthenticatedWidgets(),
          
          // Show authentication errors
          if (_authState.errorMessage.isNotEmpty) 
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Auth Error: ${_authState.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            
          // Show Drive API errors
          if (_driveState.errorMessage.isNotEmpty) 
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Drive Error: ${_driveState.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns the list of widgets to include if the user is authenticated.
  List<Widget> _buildAuthenticatedWidgets() {
    final user = _authState.currentUser!;
    return <Widget>[
      // The user is Authenticated.
      ListTile(
        leading: CircleAvatar(
          backgroundImage: user.photoUrl != null 
              ? NetworkImage(user.photoUrl!) 
              : null,
          child: user.photoUrl == null 
              ? Text(user.displayName?.substring(0, 1) ?? '?')
              : null,
        ),
        title: Text(user.displayName ?? ''),
        subtitle: Text(user.email),
      ),
      const Text('Signed in successfully.'),
      if (_authState.isAuthorized) ...<Widget>[
        // The user has Authorized all required scopes.
        const SizedBox(height: 20),
        
        // 文件操作按钮区域
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => _driveService.uploadFile(),
              child: const Text('UPLOAD FILE'),
            ),
            ElevatedButton(
              onPressed: _driveState.isLoadingFiles ? null : () => _driveService.listFiles(),
              child: _driveState.isLoadingFiles 
                ? const Text('LOADING...')
                : const Text('REFRESH FILES'),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // 文件列表
        const Text(
          'AppData Files:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        
        if (_driveState.fileList.isEmpty && !_driveState.isLoadingFiles)
          const Text('No files found. Upload a file or refresh the list.')
        else if (_driveState.isLoadingFiles)
          const CircularProgressIndicator()
        else
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
            ),
            child: ListView.builder(
              itemCount: _driveState.fileList.length,
              itemBuilder: (context, index) {
                final file = _driveState.fileList[index];
                return ListTile(
                  title: Text(file.name ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${file.id ?? 'Unknown'}'),
                      if (file.size != null)
                        Text('Size: ${file.size} bytes'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _driveService.deleteFile(
                      file.id ?? '', 
                      file.name ?? 'Unknown'
                    ),
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 20),
        
        if (_authState.serverAuthCode.isEmpty)
          ElevatedButton(
            child: const Text('REQUEST SERVER CODE'),
            onPressed: () => _authService.getServerAuthCode(),
          )
        else
          Text('Server auth code:\n${_authState.serverAuthCode}'),
      ] else ...<Widget>[
        // The user has NOT Authorized all required scopes.
        const Text('Authorization needed to read your drive.'),
        ElevatedButton(
          onPressed: () => _authService.authorizeScopes(),
          child: const Text('REQUEST PERMISSIONS'),
        ),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => _authService.signOut(),
        child: const Text('SIGN OUT')
      ),
    ];
  }

  /// Returns the list of widgets to include if the user is not authenticated.
  List<Widget> _buildUnauthenticatedWidgets() {
    return <Widget>[
      const Text('You are not currently signed in.'),
      // #docregion ExplicitSignIn
      if (_authService.supportsAuthenticate())
        ElevatedButton(
          onPressed: () => _authService.signIn(),
          child: const Text('SIGN IN'),
        )
      else ...<Widget>[
        if (kIsWeb)
          web.renderButton()
        // #enddocregion ExplicitSignIn
        else
          const Text(
            'This platform does not have a known authentication method',
          ),
        // #docregion ExplicitSignIn
      ],
      // #enddocregion ExplicitSignIn
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive AppData Demo')),
      body: _buildBody(),
    );
  }
}