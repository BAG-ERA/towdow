# Users API Service

The Users API Service provides functionality to interact with TowDow's user management API endpoints. It follows the same pattern as the Share Service and is designed to work with TowDow Cloud and self-hosted accounts.

## Features

- **Current User Information**: Retrieve the currently authenticated user's information
- **User Lookup**: Get user information by email address
- **Provider Support**: Only works with TowDow Cloud and self-hosted accounts

## API Endpoints

### GET /current_user
Retrieves the currently authenticated user's information.

**Response:**
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "sub": "user123",
  "role": ["user"],
  "locale": "en"
}
```

### GET /user/{email}
Retrieves user information by email address.

**Response:**
```json
{
  "id": 1,
  "isGuest": false,
  "homePath": "/home/user",
  "email": "user@example.com",
  "kcId": "kc123",
  "firstname": "John",
  "lastname": "Doe"
}
```

## Usage

### Basic Usage

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/users_api_service.dart';

// Get the service from providers
final usersApiService = ref.watch(usersApiServiceProvider(account));

// Check if the account supports users API
if (usersApiService.supportsUsersApi) {
  // Get current user
  final currentUserResult = await usersApiService.getCurrentUser();
  
  currentUserResult.when(
    success: (currentUser) {
      print('Current user: ${currentUser.email}');
      print('Name: ${currentUser.name}');
      print('Roles: ${currentUser.role}');
    },
    failure: (failure) {
      print('Error: ${failure.message}');
    },
  );

  // Get user by email
  final userInfoResult = await usersApiService.getUserByEmail('other@example.com');
  
  userInfoResult.when(
    success: (userInfo) {
      print('User found: ${userInfo.firstname} ${userInfo.lastname}');
      print('Is guest: ${userInfo.isGuest}');
    },
    failure: (failure) {
      print('Error: ${failure.message}');
    },
  );
}
```

### Integration with ViewModels

```dart
class UserViewModel extends ChangeNotifier {
  final UsersApiService _usersApiService;
  
  UserViewModel(this._usersApiService);
  
  CurrentUser? _currentUser;
  CurrentUser? get currentUser => _currentUser;
  
  Future<void> loadCurrentUser() async {
    final result = await _usersApiService.getCurrentUser();
    
    result.when(
      success: (user) {
        _currentUser = user;
        notifyListeners();
      },
      failure: (failure) {
        // Handle error
        print('Failed to load current user: ${failure.message}');
      },
    );
  }
}
```

## Data Models

### CurrentUser
Represents the currently authenticated user.

```dart
class CurrentUser {
  final String email;
  final String name;
  final String sub;
  final List<String> role;
  final String locale;
}
```

### UserInfo
Represents detailed user information.

```dart
class UserInfo {
  final int id;
  final bool isGuest;
  final String homePath;
  final String email;
  final String kcId;
  final String firstname;
  final String lastname;
}
```

## Error Handling

The service uses the `Result` pattern for error handling:

- **Success**: Returns the requested data
- **Failure**: Returns a `Failure` object with error details

Common error scenarios:
- Network connectivity issues
- Authentication failures
- User not found (404 for getUserByEmail)
- Server errors (500+)

## Provider Support

The service is available through Riverpod providers:

```dart
// Provider for UsersApiService
final usersApiServiceProvider = Provider.family<UsersApiService, CaldavAccount>((ref, account) {
  return UsersApiService(account: account);
});
```

## Authentication

The service automatically uses the same authentication mechanism as other TowDow services:
- **Basic Auth**: For custom CalDAV servers
- **OAuth/Keycloak**: For TowDow Cloud and self-hosted instances

Authentication headers are automatically managed by the WebDAV client. 