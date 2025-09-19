// This file demonstrates how to avoid circular dependencies

// GOOD: Using dependency injection and interfaces

// Service interface (abstraction)
abstract class IServiceA {
  void doSomething();
  void helperMethod();
}

abstract class IServiceB {
  void process();
}

// Concrete implementations
class ServiceA implements IServiceA {
  final IServiceB serviceB;

  ServiceA(this.serviceB);

  @override
  void doSomething() {
    print('ServiceA doing something');
    serviceB.process();
  }

  @override
  void helperMethod() {
    print('Helper method in ServiceA');
  }
}

class ServiceB implements IServiceB {
  // GOOD: No direct dependency on ServiceA
  // If needed, can depend on IServiceA interface

  @override
  void process() {
    print('ServiceB processing independently');
  }
}

// Alternative: Using event-based communication
class EventBus {
  final _listeners = <String, List<Function>>{};

  void emit(String event, dynamic data) {
    _listeners[event]?.forEach((listener) => listener(data));
  }

  void on(String event, Function callback) {
    _listeners[event] ??= [];
    _listeners[event]!.add(callback);
  }
}

class ServiceWithEvents {
  final EventBus eventBus;

  ServiceWithEvents(this.eventBus);

  void doWork() {
    print('Doing work');
    // Emit event instead of direct dependency
    eventBus.emit('work_completed', {'status': 'success'});
  }
}