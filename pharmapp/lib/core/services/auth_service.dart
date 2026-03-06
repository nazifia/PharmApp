import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:stacked/stacked.dart';
import '../database/database_provider.dart';
import '../database/repositories/user_repository.dart';
import 'package:pharmapp/shared/models/user_model.dart';

class AuthService extends BaseService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final UserRepository _userRepository;

  AuthService(this._userRepository);

  // Authentication state
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  // Authentication tokens
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // Login with phone number
  Future<bool> loginWithPhone(
    String phoneNumber, {
    required VoidCallback onVerificationCompleted,
    required VoidCallback onVerificationFailed,
    required VoidCallback onCodeSent,
    required VoidCallback onCodeAutoRetrievalTimeout,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval completed
          await _handleCredential(credential);
          onVerificationCompleted();
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed();
        },
        codeSent: (String verificationId, int? resendToken) async {
          // Save verification ID for later use
          await _secureStorage.write(
            key: 'verificationId',
            value: verificationId,
          );
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout();
        },
        timeout: const Duration(seconds: 60),
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Verify phone code
  Future<bool> verifyPhoneCode(String code) async {
    try {
      final verificationId = await _secureStorage.read(key: 'verificationId');
      if (verificationId == null) {
        throw Exception('Verification ID not found');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      await _handleCredential(credential);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Handle authentication credential
  Future<void> _handleCredential(PhoneAuthCredential credential) async {
    try {
      final authResult = await _firebaseAuth.signInWithCredential(credential);

      if (authResult.user != null) {
        await _completeAuthentication(authResult.user!);
      } else {
        throw Exception('Authentication failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Complete authentication process
  Future<void> _completeAuthentication(User firebaseUser) async {
    try {
      // Get user data from backend
      final userData = await _fetchUserData(firebaseUser.phoneNumber);

      if (userData == null) {
        // New user - redirect to setup
        await _handleNewUser(firebaseUser);
      } else {
        // Existing user - complete login
        await _handleExistingUser(userData);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fetch user data from backend
  Future<Map<String, dynamic>?> _fetchUserData(String phoneNumber) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.pharmapp.com/users/$phoneNumber'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null; // New user
      } else {
        throw Exception('Failed to fetch user data');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Handle new user
  Future<void> _handleNewUser(User firebaseUser) async {
    try {
      // Create new user in local database
      final newUser = User(
        id: 0, // Will be auto-generated
        phoneNumber: firebaseUser.phoneNumber!,
        role: 'Customer',
        isActive: true,
        isWholesaleOperator: false,
      );

      await _userRepository.createUser(newUser);

      // Store user data
      await _storeUserData(newUser);

      // Set authentication state
      _currentUser = newUser;
      _isAuthenticated = true;
    } catch (e) {
      rethrow;
    }
  }

  // Handle existing user
  Future<void> _handleExistingUser(Map<String, dynamic> userData) async {
    try {
      // Create user from backend data
      final user = User(
        id: userData['id'],
        phoneNumber: userData['phone_number'],
        role: userData['role'],
        isActive: userData['is_active'],
        isWholesaleOperator: userData['is_wholesale_operator'] ?? false,
      );

      // Update local database
      await _userRepository.updateUser(user);

      // Store user data
      await _storeUserData(user);

      // Set authentication state
      _currentUser = user;
      _isAuthenticated = true;
    } catch (e) {
      rethrow;
    }
  }

  // Store user data securely
  Future<void> _storeUserData(User user) async {
    try {
      final userData = {
        'id': user.id,
        'phone_number': user.phoneNumber,
        'role': user.role,
        'is_active': user.isActive,
        'is_wholesale_operator': user.isWholesaleOperator,
      };

      await _secureStorage.write(
        key: 'user_data',
        value: json.encode(userData),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Clear authentication state
      _currentUser = null;
      _isAuthenticated = false;

      // Clear secure storage
      await _secureStorage.delete(key: 'user_data');
      await _secureStorage.delete(key: 'verificationId');
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');

      // Sign out from Firebase
      await _firebaseAuth.signOut();

    } catch (e) {
      rethrow;
    }
  }

  // Check authentication status
  Future<bool> checkAuthStatus() async {
    try {
      final userData = await _secureStorage.read(key: 'user_data');
      if (userData != null) {
        final data = json.decode(userData);

        _currentUser = User(
          id: data['id'],
          phoneNumber: data['phone_number'],
          role: data['role'],
          isActive: data['is_active'],
          isWholesaleOperator: data['is_wholesale_operator'] ?? false,
        );

        _isAuthenticated = true;
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  // Get user permissions
  List<String> getUserPermissions() {
    switch (_currentUser?.role) {
      case 'Admin':
        return ['admin', 'manage_users', 'manage_inventory', 'manage_sales', 'view_reports'];
      case 'Pharmacist':
        return ['manage_inventory', 'manage_sales', 'view_reports'];
      case 'Cashier':
        return ['manage_sales', 'view_reports'];
      case 'Wholesaler':
        return ['manage_wholesale', 'view_reports'];
      default:
        return ['customer', 'view_inventory', 'place_orders'];
    }
  }

  // Check permission
  bool hasPermission(String permission) {
    final permissions = getUserPermissions();
    return permissions.contains(permission);
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      // Update backend
      final response = await http.put(
        Uri.parse('https://api.pharmapp.com/users/${_currentUser!.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        // Update local database
        await _userRepository.updateUser(_currentUser!);
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.pharmapp.com/password-reset'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'email': email}),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // Complete password reset
  Future<bool> completePasswordReset(String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.pharmapp.com/password-reset/$token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'new_password': newPassword}),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // Social login (Google)
  Future<bool> loginWithGoogle() async {
    try {
      // TODO: Implement Google Sign-In
      return false;
    } catch (e) {
      rethrow;
    }
  }

  // Social login (Facebook)
  Future<bool> loginWithFacebook() async {
    try {
      // TODO: Implement Facebook Login
      return false;
    } catch (e) {
      rethrow;
    }
  }

  // Biometric authentication
  Future<bool> authenticateWithBiometrics() async {
    try {
      // TODO: Implement Biometric Authentication
      return false;
    } catch (e) {
      rethrow;
    }
  }
}