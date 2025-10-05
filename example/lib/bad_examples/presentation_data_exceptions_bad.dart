// ignore_for_file: unused_element, unused_local_variable

import 'package:flutter/material.dart';

// Data layer exceptions (should NOT be used in Presentation)
class NotFoundException implements Exception {}
class UnauthorizedException implements Exception {}
class NetworkException implements Exception {}
class DataSourceException implements Exception {}
class ServerException implements Exception {}

// ❌ BAD: Presentation handling Data exceptions
// This will trigger: presentation_no_data_exceptions
class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final error = Exception();

    // ❌ Presentation should NOT check Data exceptions
    if (error is NotFoundException) {
      return const Text('Not found'); // Should use TodoNotFoundException
    }

    // ❌ Network exception check
    if (error is NetworkException) {
      return const Text('Network error'); // Should use TodoNetworkException
    }

    // ❌ Unauthorized check
    if (error is UnauthorizedException) {
      return const Text('Unauthorized'); // Should use TodoUnauthorizedException
    }

    return const SizedBox();
  }
}

// ❌ BAD: Error handling widget with Data exceptions
class ErrorHandlerWidget extends StatelessWidget {
  final Object error;

  const ErrorHandlerWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // ❌ Multiple Data exception checks
    if (error is NotFoundException) {
      return const ErrorDisplay(message: 'Resource not found');
    }

    if (error is ServerException) {
      return const ErrorDisplay(message: 'Server error');
    }

    if (error is DataSourceException) {
      return const ErrorDisplay(message: 'Data source error');
    }

    return const ErrorDisplay(message: 'Unknown error');
  }
}

class ErrorDisplay extends StatelessWidget {
  final String message;

  const ErrorDisplay({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Text(message);
}
