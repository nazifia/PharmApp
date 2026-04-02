import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../shared/models/customer.dart';
import 'customer_api_client.dart';

export 'customer_api_client.dart' show WalletTransaction, CustomerSale;

final customerApiProvider = Provider<CustomerApiClient>((ref) {
  final isDev = ref.watch(isDevModeProvider);
  if (isDev) return CustomerApiClient.local();
  return CustomerApiClient.remote(ref.watch(dioProvider));
});

/// Full customer list — refresh with ref.invalidate(customerListProvider)
final customerListProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(customerApiProvider).fetchCustomers();
});

/// Single customer by ID
final customerDetailProvider = FutureProvider.family<Customer, int>((ref, id) {
  return ref.watch(customerApiProvider).fetchCustomer(id);
});

/// Recent sales for a customer
final customerSalesProvider =
    FutureProvider.family<List<CustomerSale>, int>((ref, id) {
  return ref.watch(customerApiProvider).fetchCustomerSales(id);
});

/// Wallet transactions for a customer
final walletTransactionsProvider =
    FutureProvider.family<List<WalletTransaction>, int>((ref, id) {
  return ref.watch(customerApiProvider).fetchWalletTransactions(id);
});

// ── Customer create / update / delete notifier ────────────────────────────────

class CustomerNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerApiClient _api;
  final Ref _ref;

  CustomerNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<Customer?> createCustomer(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final customer = await _api.createCustomer(data);
      _ref.invalidate(customerListProvider);
      state = const AsyncValue.data(null);
      return customer;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/customers/',
          body: data,
          description: 'Create customer "${data['name'] ?? ''}"',
        );
        state = const AsyncValue.data(null);
        return null; // null signals "queued offline" to the caller
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Customer?> updateCustomer(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final customer = await _api.updateCustomer(id, data);
      _ref.invalidate(customerListProvider);
      _ref.invalidate(customerDetailProvider(id));
      state = const AsyncValue.data(null);
      return customer;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'PATCH', '/customers/$id/',
          body: data,
          description: 'Update customer "${data['name'] ?? id}"',
        );
        state = const AsyncValue.data(null);
        return null;
      }
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    state = const AsyncValue.loading();
    try {
      await _api.deleteCustomer(id);
      _ref.invalidate(customerListProvider);
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'DELETE', '/customers/$id/',
          description: 'Delete customer #$id',
        );
        _ref.invalidate(customerListProvider);
        state = const AsyncValue.data(null);
        return true; // treat as success — will sync later
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final customerNotifierProvider =
    StateNotifierProvider<CustomerNotifier, AsyncValue<void>>((ref) {
  return CustomerNotifier(ref.watch(customerApiProvider), ref);
});

// ── Wallet top-up / deduct / reset notifier ───────────────────────────────────

class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerApiClient _api;
  final Ref _ref;
  final int _customerId;

  WalletNotifier(this._api, this._ref, this._customerId)
      : super(const AsyncValue.data(null));

  void _refresh() {
    _ref.invalidate(customerDetailProvider(_customerId));
    _ref.invalidate(walletTransactionsProvider(_customerId));
  }

  Future<bool> topUp(double amount) async {
    state = const AsyncValue.loading();
    try {
      await _api.topUpWallet(_customerId, amount);
      _refresh();
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/customers/$_customerId/wallet/topup/',
          body: {'amount': amount},
          description: 'Wallet top-up ₦$amount for customer #$_customerId',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deduct(double amount) async {
    state = const AsyncValue.loading();
    try {
      await _api.deductWallet(_customerId, amount);
      _refresh();
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/customers/$_customerId/wallet/deduct/',
          body: {'amount': amount},
          description: 'Wallet deduct ₦$amount for customer #$_customerId',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> resetWallet() async {
    state = const AsyncValue.loading();
    try {
      await _api.resetWallet(_customerId);
      _refresh();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      // Wallet reset requires accurate server balance — fail if offline
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> recordPayment({required double amount, String method = 'cash'}) async {
    state = const AsyncValue.loading();
    try {
      await _api.recordPayment(_customerId, amount: amount, method: method);
      _refresh();
      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e, st) {
      if (e.response == null) {
        await _ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/customers/$_customerId/record-payment/',
          body: {'amount': amount, 'method': method},
          description: 'Record payment ₦$amount for customer #$_customerId',
        );
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final walletNotifierProvider =
    StateNotifierProvider.family<WalletNotifier, AsyncValue<void>, int>(
        (ref, id) {
  return WalletNotifier(ref.watch(customerApiProvider), ref, id);
});
