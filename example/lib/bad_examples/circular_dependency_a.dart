// This file demonstrates circular dependency violations
// File A imports File B

import 'circular_dependency_b.dart';

class ServiceA {
  final ServiceB serviceB;

  ServiceA(this.serviceB);

  void doSomething() {
    print('ServiceA doing something');
    serviceB.process();
  }

  void helperMethod() {
    print('Helper method in ServiceA');
  }
}
