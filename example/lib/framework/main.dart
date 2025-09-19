// GOOD: Proper main.dart with only glue code
import '../adapters/controllers/order_controller.dart';
import '../domain/usecases/create_order_usecase.dart';
import '../adapters/gateways/payment_service_gateway.dart';
import 'config/dependency_injection.dart';

// GOOD: Simple main function with minimal glue code
void main() async {
  // GOOD: Setup and configuration only
  await setupApplication();

  // GOOD: Start the application
  runApplication();
}

// GOOD: Configuration and wiring
Future<void> setupApplication() async {
  // GOOD: Initialize framework components
  await DatabaseConfig.initialize();

  // GOOD: Setup dependency injection
  DependencyInjection.configure();

  // GOOD: Configure external services
  await ExternalServiceConfig.setup();
}

// GOOD: Simple application runner
void runApplication() {
  print('Application started successfully');

  // GOOD: Delegate to appropriate components
  final container = DependencyInjection.container;
  final orderController = container.get<OrderController>();

  // GOOD: Start application logic (would be more complex in real app)
  print('Order system ready');
}

// GOOD: Framework-specific configuration classes
class DatabaseConfig {
  static Future<void> initialize() async {
    // GOOD: Framework-specific database setup
    print('Database initialized');
  }
}

class ExternalServiceConfig {
  static Future<void> setup() async {
    // GOOD: External service configuration
    print('External services configured');
  }
}

// Mock dependency injection for example
class DependencyInjection {
  static late DIContainer container;

  static void configure() {
    container = DIContainer();
    // GOOD: Simple wiring without business logic
    container.register<CreateOrderUseCase>(() => CreateOrderUseCase(
      userRepository: container.get(),
      orderRepository: container.get(),
    ));

    // GOOD: Register other dependencies...
  }
}

class DIContainer {
  final Map<Type, Function> _factories = {};
  final Map<Type, dynamic> _instances = {};

  void register<T>(Function factory) {
    _factories[T] = factory;
  }

  T get<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }

    final factory = _factories[T];
    if (factory != null) {
      final instance = factory();
      _instances[T] = instance;
      return instance;
    }

    throw Exception('No registration found for type $T');
  }
}