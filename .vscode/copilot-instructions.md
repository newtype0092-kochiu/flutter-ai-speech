# Flutter AI Speech Project Guidelines

## Language & Internationalization
- All code comments, UI text, and error messages MUST be in English
- Use clear, descriptive variable and function names
- Avoid abbreviations unless they are widely recognized
- Write documentation that is easy to understand for international developers

## Flutter Best Practices

### Widget Design
- Use `const` constructors wherever possible for better performance
- Prefer `StatelessWidget` when state is not needed
- Implement `AutomaticKeepAliveClientMixin` for widgets that need to preserve state across navigation
- Keep widget classes focused and small (single responsibility principle)

### State Management
- Use `IndexedStack` to maintain state for multiple pages
- Implement proper lifecycle methods (`initState`, `dispose`)
- Cancel all subscriptions and dispose resources in `dispose` method
- Use `StreamSubscription` for reactive state updates

### Async Operations
- Always handle errors with try-catch blocks
- Provide meaningful error messages to users
- Use `async/await` syntax for cleaner async code
- Use assertions to enforce platform requirements in this web-only project:
  - Prefer `assert(kIsWeb, 'This feature requires web platform')` over if/else checks
  - Place assertions at the start of web-only methods/functions
  - This approach makes the web-only requirement explicit and helps catch platform misuse during development
  - Consider creating a utility class for reusable platform assertions

## Web Development

### Modern Web APIs
- Use `package:web` instead of deprecated `dart:html`
- Use `dart:js_interop` for JavaScript interoperability
- Always check browser compatibility for Web APIs

### Web-Specific Features
- Implement proper feature detection before using Web APIs
- Handle browser-specific quirks gracefully with fallback options
- Manage web resources (blob URLs, object URLs) lifecycle properly
- Provide user-friendly error messages when features are unavailable

## Audio Processing

### Streaming & Performance
- Use streaming APIs (`Stream<Uint8List>`) for memory efficiency
- Implement downsampling for large audio data
- Process audio data in chunks to avoid blocking the UI
- Use `compute` for heavy audio processing when needed

### Recording & Playback
- Check microphone permissions before starting recording
- Implement proper amplitude detection and visualization
- Use WAV format for compatibility
- Handle recording state properly (start, stop, pause)

## Google Drive Integration

### Authentication
- Always check `isAuthorized` status before API calls
- Handle authentication errors gracefully
- Provide clear instructions when user needs to sign in
- Implement automatic token refresh when needed

### File Operations
- Use AppData folder for application-specific files

### Error Handling
- Show user-friendly error messages
- Log detailed errors to console for debugging
- Implement retry logic for network failures
- Validate file IDs and response data

## Code Organization

### Service Classes
- Use singleton pattern for services (`factory` constructor)
- Separate concerns: authentication, API calls, data processing
- Implement stream-based state management
- Keep services stateless when possible

### File Structure
```
lib/
  ├── main.dart           (app entry point)
  ├── pages/              (UI pages)
  ├── widgets/            (reusable widgets)
  ├── services/           (business logic & external APIs)
  ├── models/             (data models)
  ├── utils/              (utility functions & helpers)
  └── src/                (internal helpers & platform wrappers)
```

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Methods: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE` or `kConstantName`
- Private members: prefix with underscore `_privateMember`

## Testing & Debugging

### Debugging
- Use `kDebugMode` for debug-only code
- Print useful context in debug logs
- Include file IDs, sizes, and timestamps in logs
- Log API responses for troubleshooting

### Error Messages
- Provide context in error messages (what failed and why)
- Include relevant data (file names, sizes, IDs)
- Suggest solutions when possible
- Use consistent error message format

## Documentation

### Code Comments
- Document complex algorithms and business logic
- Explain "why" not just "what"
- Add TODO comments for future improvements
- Document platform-specific quirks

### Function Documentation
```dart
/// Brief description of what the function does.
///
/// More detailed explanation if needed.
///
/// Parameters:
/// - [param1]: Description of parameter
///
/// Returns: Description of return value
///
/// Throws: List of possible exceptions
Future<void> exampleFunction(String param1) async {
  // implementation
}
```

## Security & Privacy

### API Keys & Secrets
- Never commit API keys or secrets
- Use environment variables for sensitive data
- Implement proper OAuth flow for Google services
- Store tokens securely

### User Data
- Only request necessary permissions
- Handle user data according to privacy policies
- Implement proper data cleanup on sign-out
- Use AppData folder for user-specific files

## Performance Optimization

### Memory Management
- Dispose controllers and subscriptions
- Use `const` constructors to reduce rebuilds
- Implement lazy loading for large lists
- Stream large files instead of loading in memory

### UI Performance
- Avoid expensive operations in `build` methods
- Use `RepaintBoundary` for complex widgets
- Implement proper list view recycling
- Cache computed values when appropriate

## Platform-Specific Code

### Web Platform
- Check `kIsWeb` before using web-specific features
- Provide fallbacks for unsupported browsers
- Test thoroughly in target browsers
- Handle browser differences gracefully

### Mobile Platform (Future)
- Separate platform-specific implementations
- Use conditional imports when needed
- Test on both iOS and Android
- Handle platform permissions properly

## Common Patterns in This Project

### Amplitude Detection
- Convert dBFS to linear scale for visualization
- Implement sliding window for waveform display
- Use appropriate sample rates
- Auto-scroll to latest data

### File Upload Flow
1. Check authentication
2. Convert blob to bytes (web)
3. Generate unique filename with timestamp
4. Upload with proper MIME type
5. Display file ID to user
6. Refresh file list

### State Preservation
- Use `IndexedStack` for navigation
- Implement `AutomaticKeepAliveClientMixin`
- Override `wantKeepAlive` to return `true`
- Call `super.build(context)` in build method

## Example Code Patterns

### Service Singleton
```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
  
  // service implementation
}
```

### Stream-based State
```dart
final _stateController = StreamController<MyState>.broadcast();
Stream<MyState> get stateStream => _stateController.stream;

void _notifyStateChanged() {
  _stateController.add(currentState);
}
```

### Proper Disposal
```dart
@override
void dispose() {
  _subscription?.cancel();
  _controller.dispose();
  super.dispose();
}
```

---

**Note**: These guidelines should be followed for all new code and when refactoring existing code. Consistency is key to maintaining a clean and maintainable codebase.
