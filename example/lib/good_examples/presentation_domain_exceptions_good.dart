// ignore_for_file: unused_element, unused_local_variable

import 'package:flutter/material.dart';

// Domain layer exceptions (Allowed in Presentation)
class TodoNotFoundException implements Exception {
  final String message;
  TodoNotFoundException(this.message);
}

class TodoNetworkException implements Exception {
  final String message;
  TodoNetworkException(this.message);
}

class TodoUnauthorizedException implements Exception {
  final String message;
  TodoUnauthorizedException(this.message);
}

class TodoValidationException implements Exception {
  final String message;
  TodoValidationException(this.message);
}

// ✅ GOOD: Presentation handling Domain exceptions
class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final error = Exception();

    // ✅ Presentation handles Domain exceptions
    if (error is TodoNotFoundException) {
      return const Text('할 일을 찾을 수 없습니다');
    }

    // ✅ Domain network exception
    if (error is TodoNetworkException) {
      return const Text('네트워크 연결을 확인해주세요');
    }

    // ✅ Domain unauthorized exception
    if (error is TodoUnauthorizedException) {
      return const Text('권한이 없습니다');
    }

    return const SizedBox();
  }
}

// ✅ GOOD: Error handling widget with Domain exceptions
class ErrorHandlerWidget extends StatelessWidget {
  final Object error;

  const ErrorHandlerWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // ✅ All Domain exception checks
    if (error is TodoNotFoundException) {
      return const ErrorDisplay(message: '할 일을 찾을 수 없습니다');
    }

    if (error is TodoValidationException) {
      return ErrorDisplay(
          message: '입력 값을 확인해주세요: ${(error as TodoValidationException).message}');
    }

    if (error is TodoNetworkException) {
      return const ErrorDisplay(message: '네트워크 오류가 발생했습니다');
    }

    if (error is TodoUnauthorizedException) {
      return const ErrorDisplay(message: '로그인이 필요합니다');
    }

    return const ErrorDisplay(message: '알 수 없는 오류');
  }
}

// ✅ GOOD: AsyncValue error handling with Domain exceptions
class TodoListWidget extends StatelessWidget {
  const TodoListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulating AsyncValue from Riverpod
    final error = Exception();

    // ✅ Domain exception handling in AsyncValue.when
    if (error is TodoNotFoundException) {
      return const Center(child: Text('할 일이 없습니다'));
    } else if (error is TodoNetworkException) {
      return const Center(child: Text('네트워크 오류'));
    }

    return const SizedBox();
  }
}

// ✅ GOOD: Multiple Domain exception types
class TodoErrorBoundary extends StatelessWidget {
  final Object error;
  final Widget child;

  const TodoErrorBoundary({
    super.key,
    required this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Feature-specific Domain exceptions
    if (error is TodoNotFoundException ||
        error is TodoValidationException ||
        error is TodoNetworkException ||
        error is TodoUnauthorizedException) {
      return ErrorDisplay(message: _getErrorMessage(error));
    }

    return child;
  }

  String _getErrorMessage(Object error) {
    if (error is TodoNotFoundException) return '할 일을 찾을 수 없습니다';
    if (error is TodoValidationException) return '유효하지 않은 값입니다';
    if (error is TodoNetworkException) return '네트워크 오류';
    if (error is TodoUnauthorizedException) return '권한 없음';
    return '오류 발생';
  }
}

class ErrorDisplay extends StatelessWidget {
  final String message;

  const ErrorDisplay({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Text(message);
}
