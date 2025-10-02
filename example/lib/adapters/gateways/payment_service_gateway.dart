// GOOD: External Service Adapter properly isolating external service
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/payment_repository.dart';

// GOOD: Adapter implements domain interface
class PaymentServiceGateway implements PaymentRepository {
  final PaymentApiClient _apiClient;

  PaymentServiceGateway(this._apiClient);

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    try {
      // GOOD: Convert domain data to external format
      final apiRequest = _toApiRequest(request);

      // GOOD: Call external service
      final apiResponse = await _apiClient.processPayment(apiRequest);

      // GOOD: Convert external response to domain format
      return _fromApiResponse(apiResponse);
    } catch (e) {
      // GOOD: Convert external errors to domain errors
      return _handlePaymentError(e);
    }
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    try {
      final statusResponse = await _apiClient.getPaymentStatus(paymentId);
      return _convertPaymentStatus(statusResponse.status);
    } catch (e) {
      throw PaymentException('Failed to get payment status: ${e.toString()}');
    }
  }

  // GOOD: Convert domain to external format
  PaymentApiRequest _toApiRequest(PaymentRequest request) {
    return PaymentApiRequest(
      amount: request.amount.amount,
      currency: request.amount.currency,
      orderId: request.orderId,
      customerId: request.customerId,
      paymentMethod: request.paymentMethod,
    );
  }

  // GOOD: Convert external to domain format
  PaymentResult _fromApiResponse(PaymentApiResponse response) {
    if (response.success) {
      return PaymentResult.success(
        paymentId: response.paymentId,
        transactionId: response.transactionId,
        amount: Money(response.amount, response.currency),
      );
    } else {
      return PaymentResult.failure(
        reason: response.errorMessage ?? 'Payment failed',
      );
    }
  }

  // GOOD: Error handling and conversion
  PaymentResult _handlePaymentError(dynamic error) {
    if (error is PaymentApiException) {
      return PaymentResult.failure(
        reason: _translateApiError(error.code),
      );
    } else {
      return PaymentResult.failure(
        reason: 'Payment service unavailable',
      );
    }
  }

  String _translateApiError(String apiErrorCode) {
    switch (apiErrorCode) {
      case 'INSUFFICIENT_FUNDS':
        return 'Insufficient funds';
      case 'INVALID_CARD':
        return 'Invalid payment method';
      case 'EXPIRED_CARD':
        return 'Payment method expired';
      default:
        return 'Payment failed';
    }
  }

  PaymentStatus _convertPaymentStatus(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.failed;
    }
  }
}

// External service client (would typically be injected)
class PaymentApiClient {
  Future<PaymentApiResponse> processPayment(PaymentApiRequest request) async {
    // Simulate external API call
    await Future.delayed(Duration(milliseconds: 500));
    return PaymentApiResponse(
      success: true,
      paymentId: 'pay_123',
      transactionId: 'txn_456',
      amount: request.amount,
      currency: request.currency,
    );
  }

  Future<PaymentStatusResponse> getPaymentStatus(String paymentId) async {
    await Future.delayed(Duration(milliseconds: 200));
    return PaymentStatusResponse(status: 'completed');
  }
}

// External API data structures
class PaymentApiRequest {
  final double amount;
  final String currency;
  final String orderId;
  final String customerId;
  final String paymentMethod;

  PaymentApiRequest({
    required this.amount,
    required this.currency,
    required this.orderId,
    required this.customerId,
    required this.paymentMethod,
  });
}

class PaymentApiResponse {
  final bool success;
  final String? paymentId;
  final String? transactionId;
  final double amount;
  final String currency;
  final String? errorMessage;

  PaymentApiResponse({
    required this.success,
    this.paymentId,
    this.transactionId,
    required this.amount,
    required this.currency,
    this.errorMessage,
  });
}

class PaymentStatusResponse {
  final String status;

  PaymentStatusResponse({required this.status});
}

class PaymentApiException implements Exception {
  final String code;
  final String message;

  PaymentApiException(this.code, this.message);
}

// Domain types (would be imported from domain layer)
abstract class PaymentRepository {
  Future<PaymentResult> processPayment(PaymentRequest request);
  Future<PaymentStatus> getPaymentStatus(String paymentId);
}

class PaymentRequest {
  final Money amount;
  final String orderId;
  final String customerId;
  final String paymentMethod;

  PaymentRequest({
    required this.amount,
    required this.orderId,
    required this.customerId,
    required this.paymentMethod,
  });
}

class PaymentResult {
  final bool isSuccess;
  final String? paymentId;
  final String? transactionId;
  final Money? amount;
  final String? failureReason;

  PaymentResult._({
    required this.isSuccess,
    this.paymentId,
    this.transactionId,
    this.amount,
    this.failureReason,
  });

  factory PaymentResult.success({
    required String paymentId,
    required String transactionId,
    required Money amount,
  }) {
    return PaymentResult._(
      isSuccess: true,
      paymentId: paymentId,
      transactionId: transactionId,
      amount: amount,
    );
  }

  factory PaymentResult.failure({required String reason}) {
    return PaymentResult._(
      isSuccess: false,
      failureReason: reason,
    );
  }
}

enum PaymentStatus { pending, completed, failed }

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
}

class Money {
  final double amount;
  final String currency;
  Money(this.amount, this.currency);
}
