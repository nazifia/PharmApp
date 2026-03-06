import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../schemas/user_schema.dart';
import '../../shared/models/user_model.dart';

class UserRepository {
  final Isar _isar;

  UserRepository(this._isar);

  // Create user
  Future<int> createUser(User user) async {
    try {
      final userSchema = UserSchema.fromDomain(user);
      final id = await _isar.writeTxn(() async {
        return await _isar.users.put(userSchema);
      });
      return id;
    } catch (e) {
      rethrow;
    }
  }

  // Get user by ID
  Future<User?> getUserById(int id) async {
    try {
      final userSchema = await _isar.readTxn(() async {
        return await _isar.users.findById(id);
      });
      return userSchema?.toDomain();
    } catch (e) {
      rethrow;
    }
  }

  // Get user by phone number
  Future<User?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final userSchema = await _isar.readTxn(() async {
        return await _isar.users.findBy(
          (user) => user.phoneNumber.equals(phoneNumber),
        );
      });
      return userSchema?.toDomain();
    } catch (e) {
      rethrow;
    }
  }

  // Update user
  Future<bool> updateUser(User user) async {
    try {
      final userSchema = UserSchema.fromDomain(user);
      final success = await _isar.writeTxn(() async {
        return await _isar.users.put(userSchema) != null;
      });
      return success;
    } catch (e) {
      rethrow;
    }
  }

  // Delete user
  Future<bool> deleteUser(int id) async {
    try {
      final success = await _isar.writeTxn(() async {
        return await _isar.users.removeById(id);
      });
      return success;
    } catch (e) {
      rethrow;
    }
  }

  // Get all users
  Future<List<User>> getAllUsers() async {
    try {
      final users = await _isar.readTxn(() async {
        return await _isar.users.findAll();
      });
      return users.map((user) => user.toDomain()).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get users by role
  Future<List<User>> getUsersByRole(String role) async {
    try {
      final users = await _isar.readTxn(() async {
        return await _isar.users.filter()
          .role.equals(role)
          .findAll();
      });
      return users.map((user) => user.toDomain()).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get active users
  Future<List<User>> getActiveUsers() async {
    try {
      final users = await _isar.readTxn(() async {
        return await _isar.users.filter()
          .isActive.equals(true)
          .findAll();
      });
      return users.map((user) => user.toDomain()).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Search users
  Future<List<User>> searchUsers(String query) async {
    try {
      final users = await _isar.readTxn(() async {
        return await _isar.users.filter()
          .name.contains(query, caseSensitive: false)
          .or()
          .phoneNumber.contains(query)
          .findAll();
      });
      return users.map((user) => user.toDomain()).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get user count
  Future<int> getUserCount() async {
    try {
      final count = await _isar.readTxn(() async {
        return await _isar.users.count();
      });
      return count;
    } catch (e) {
      rethrow;
    }
  }

  // Clear all users (for testing)
  Future<void> clearUsers() async {
    try {
      await _isar.writeTxn(() async {
        await _isar.users.clear();
      });
    } catch (e) {
      rethrow;
    }
  }
}

// Riverpod providers
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return UserRepository(isar);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return AuthService(userRepository);
});