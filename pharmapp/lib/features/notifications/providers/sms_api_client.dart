import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

enum SmsTemplate {
  prescriptionReady,
  walletCredit,
  paymentReminder,
  custom,
}

extension SmsTemplateExt on SmsTemplate {
  String get apiKey => switch (this) {
    SmsTemplate.prescriptionReady  => 'prescription_ready',
    SmsTemplate.walletCredit       => 'wallet_credit',
    SmsTemplate.paymentReminder    => 'payment_reminder',
    SmsTemplate.custom             => 'custom',
  };

  String get displayName => switch (this) {
    SmsTemplate.prescriptionReady  => 'Prescription Ready',
    SmsTemplate.walletCredit       => 'Wallet Credit Alert',
    SmsTemplate.paymentReminder    => 'Payment Reminder',
    SmsTemplate.custom             => 'Custom Message',
  };

  String defaultMessage(String pharmacyName, {double? amount}) => switch (this) {
    SmsTemplate.prescriptionReady  => 'Your prescription is ready for pickup at $pharmacyName. Please come with your prescription card.',
    SmsTemplate.walletCredit       => 'Your wallet has been credited with ${amount != null ? '₦${amount.toStringAsFixed(2)}' : 'an amount'} at $pharmacyName.',
    SmsTemplate.paymentReminder    => 'You have an outstanding balance${amount != null ? ' of ₦${amount.toStringAsFixed(2)}' : ''} at $pharmacyName. Please settle at your earliest convenience.',
    SmsTemplate.custom             => '',
  };
}

class SmsApiClient {
  final Dio _dio;
  SmsApiClient(this._dio);

  Future<bool> sendSms({
    required int customerId,
    required String message,
    String template = 'custom',
  }) async {
    try {
      await _dio.post('/notifications/send-sms/', data: {
        'customer_id': customerId,
        'message': message,
        'template': template,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to send SMS');
    }
  }
}

final smsApiClientProvider = Provider<SmsApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return SmsApiClient(dio);
});

class SmsNotifier extends StateNotifier<AsyncValue<void>> {
  final SmsApiClient _client;
  SmsNotifier(this._client) : super(const AsyncValue.data(null));

  Future<bool> sendSms({
    required int customerId,
    required String message,
    String template = 'custom',
  }) async {
    state = const AsyncValue.loading();
    try {
      final ok = await _client.sendSms(
          customerId: customerId, message: message, template: template);
      state = const AsyncValue.data(null);
      return ok;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final smsNotifierProvider =
    StateNotifierProvider<SmsNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(smsApiClientProvider);
  return SmsNotifier(client);
});
