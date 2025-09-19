// This file demonstrates circular dependency violations
// File B imports File A (creating a circular dependency)

import 'circular_dependency_a.dart';

class ServiceB {
  ServiceA? _serviceA;

  void setServiceA(ServiceA serviceA) {
    _serviceA = serviceA;
  }

  void process() {
    print('ServiceB processing');
    // BAD: Creating circular dependency
    _serviceA?.helperMethod();
  }
}