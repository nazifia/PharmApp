import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/customer.dart';
import 'customer_api_client.dart';

export 'customer_api_client.dart' show WalletTransaction, CustomerSale;

final customerApiProvider = Provider<CustomerApiClient>((ref) {
  return CustomerApiClient(ref.watch(dioProvider));
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

// ── Customer create / update notifier ─────────────────────────────────────────

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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final customerNotifierProvider =
    StateNotifierProvider<CustomerNotifier, AsyncValue<void>>((ref) {
  return CustomerNotifier(ref.watch(customerApiProvider), ref);
});

// ── Wallet top-up / deduct notifier ───────────────────────────────────────────

class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerApiClient _api;
  final Ref _ref;
  final int _customerId;

  WalletNotifier(this._api, this._ref, this._customerId)
      : super(const AsyncValue.data(null));

  Future<bool> topUp(double amount) async {
    state = const AsyncValue.loading();
    try {
      await _api.topUpWallet(_customerId, amount);
      _ref.invalidate(customerDetailProvider(_customerId));
      _ref.invalidate(walletTransactionsProvider(_customerId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deduct(double amount) async {
    state = const AsyncValue.loading();
    try {
      await _api.deductWallet(_customerId, amount);
      _ref.invalidate(customerDetailProvider(_customerId));
      _ref.invalidate(walletTransactionsProvider(_customerId));
      state = const AsyncValue.data(null);
      return true;
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
