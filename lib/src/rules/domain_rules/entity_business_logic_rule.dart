import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Domain Entities contain business logic, not just data fields.
///
/// In Clean Architecture, Entities should be rich domain models with business
/// logic, not anemic data holders. This rule detects entities that only have
/// getters/fields without business logic methods.
///
/// ## What This Rule Checks
///
/// 1. **Anemic Entity Detection**: Entities with only getters/fields trigger warnings
/// 2. **Freezed + Extension Pattern**: Recognizes business logic in entity extensions
/// 3. **Value Object Allowance**: Simple value objects (Money, Email) are permitted
/// 4. **Immutability Validation**: Fields must be final, no setters allowed
///
/// ## Error Handling Flow
///
/// Domain entities should contain:
/// - **Business Logic Methods**: Calculations, validations, transformations
/// - **Immutable Fields**: All fields must be `final`
/// - **No Setters**: Use `copyWith()` pattern instead
///
/// ## ✅ Correct Patterns
///
/// ### Pattern 1: Regular Entity with Business Logic
/// ```dart
/// class Todo {
///   final String id;
///   final String title;
///   final bool isCompleted;
///   final DateTime? dueDate;
///
///   const Todo({
///     required this.id,
///     required this.title,
///     required this.isCompleted,
///     this.dueDate,
///   });
///
///   // ✅ Business logic methods
///   bool get isOverdue {
///     if (dueDate == null || isCompleted) return false;
///     return DateTime.now().isAfter(dueDate!);
///   }
///
///   Todo markAsCompleted() {
///     return Todo(
///       id: id,
///       title: title,
///       isCompleted: true,
///       dueDate: dueDate,
///     );
///   }
/// }
/// ```
///
/// ### Pattern 2: Freezed Entity with Extension Methods
/// ```dart
/// @freezed
/// class Todo with _$Todo {
///   const factory Todo({
///     required String id,
///     required String title,
///     required bool isCompleted,
///     DateTime? dueDate,
///   }) = _Todo;
/// }
///
/// // ✅ Business logic in extension (same file)
/// extension TodoX on Todo {
///   bool get isOverdue {
///     if (dueDate == null || isCompleted) return false;
///     return DateTime.now().isAfter(dueDate!);
///   }
///
///   Todo markAsCompleted() => copyWith(isCompleted: true);
/// }
/// ```
///
/// ### Pattern 3: Value Object (Allowed)
/// ```dart
/// // ✅ Simple value objects are allowed without complex business logic
/// class Email {
///   final String value;
///
///   const Email(this.value);
///
///   bool get isValid => value.contains('@');
/// }
///
/// class Money {
///   final double amount;
///   final String currency;
///
///   const Money(this.amount, this.currency);
/// }
/// ```
///
/// ## ❌ Wrong Patterns
///
/// ### Anti-Pattern 1: Anemic Entity
/// ```dart
/// // ❌ Only data fields, no business logic
/// class Todo {
///   final String id;
///   final String title;
///   final bool isCompleted;
///
///   const Todo({
///     required this.id,
///     required this.title,
///     required this.isCompleted,
///   });
///   // Missing: Business logic methods
/// }
/// ```
///
/// ### Anti-Pattern 2: Mutable Entity
/// ```dart
/// // ❌ Non-final field
/// class Todo {
///   String title; // Should be final
///   final String id;
///
///   Todo({required this.title, required this.id});
///
///   // ❌ Setter method
///   void setTitle(String newTitle) {
///     title = newTitle;
///   }
/// }
/// ```
///
/// ### Anti-Pattern 3: Freezed Without Extensions
/// ```dart
/// @freezed
/// class Todo with _$Todo {
///   const factory Todo({
///     required String id,
///     required String title,
///   }) = _Todo;
///   // ❌ Missing extension with business logic
/// }
/// ```
///
/// ## Implementation Notes
///
/// - **Freezed Detection**: Looks for `@freezed` annotation and checks for extensions
/// - **Value Object Heuristic**: Classes named *Value, *VO, or common patterns (Email, Money)
/// - **Business Logic**: Methods that are not getters, setters, or constructors
/// - **Immutability**: All fields must be final, const constructor recommended
///
class EntityBusinessLogicRule extends CleanArchitectureLintRule {
  const EntityBusinessLogicRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_business_logic',
    problemMessage: 'Domain Entity appears to be anemic (only data fields without business logic). '
        'Entities should contain business logic methods.',
    correctionMessage: 'Add business logic methods to Entity:\n'
        '  - Calculations: get isOverdue, get totalAmount\n'
        '  - Validations: bool isValid(), bool canPerform()\n'
        '  - Transformations: Entity markAsCompleted()\n\n'
        'OR use Freezed with extension methods:\n'
        '  @freezed class Todo with _\$Todo {...}\n'
        '  extension TodoX on Todo { methods... }\n\n'
        'Value objects (Email, Money) are allowed without complex logic.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEntityClass(node, reporter, resolver);
    });
  }

  void _checkEntityClass(
    ClassDeclaration classNode,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final className = classNode.name.lexeme;
    final filePath = resolver.source.fullName;

    // Only check domain layer entities
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Skip non-entity classes
    if (!_isEntityClass(className, classNode)) return;

    // Skip if this is a value object
    if (_isValueObject(className)) return;

    // Check if class is Freezed
    final isFreezed = _hasFreezedAnnotation(classNode);

    if (isFreezed) {
      // Check for sealed class modifier
      if (!_isSealedClass(classNode)) {
        reporter.atNode(
          classNode,
          LintCode(
            name: 'entity_business_logic',
            problemMessage: 'Freezed Entity "$className" should be a sealed class',
            correctionMessage: 'Add "sealed" modifier before "class" keyword (e.g., "sealed class $className").',
          ),
        );
      }

      // For Freezed entities, check for extension in same file
      if (!_hasExtensionInFile(className, classNode)) {
        reporter.atNode(
          classNode,
          LintCode(
            name: 'entity_business_logic',
            problemMessage: 'Freezed Entity "$className" lacks business logic extension. '
                'Add extension with business logic methods in same file.',
            correctionMessage: 'Add extension to Freezed entity:\n'
                '  extension ${className}X on $className {\n'
                '    bool get isValid => /* validation logic */;\n'
                '    $className performAction() => /* business logic */;\n'
                '  }',
          ),
        );
      }
    } else {
      // For regular entities, check for business logic methods
      final hasBusinessLogic = _hasBusinessLogicMethods(classNode);
      final hasMutableFields = _hasMutableFields(classNode);

      if (hasMutableFields) {
        reporter.atNode(
          classNode,
          LintCode(
            name: 'entity_immutability',
            problemMessage: 'Entity "$className" has non-final fields. '
                'Domain entities must be immutable.',
            correctionMessage: 'Make all fields final:\n'
                '  final String name; // Not: String name;\n\n'
                'Use copyWith pattern for updates:\n'
                '  Entity copyWith({String? name}) => Entity(name: name ?? this.name);',
          ),
        );
      }

      if (!hasBusinessLogic && !hasMutableFields) {
        reporter.atNode(classNode, _code);
      }
    }
  }

  /// Checks if class name indicates it's an entity
  bool _isEntityClass(String className, ClassDeclaration classNode) {
    // Entity naming patterns
    if (className.endsWith('Entity')) return true;
    if (className.endsWith('Model')) return false; // Models are in data layer
    if (className.endsWith('State')) return false; // States are in presentation
    if (className.endsWith('DTO')) return false;
    if (className.endsWith('Request')) return false;
    if (className.endsWith('Response')) return false;
    if (className.endsWith('UseCase')) return false;
    if (className.endsWith('Repository')) return false;
    if (className.endsWith('Exception')) return false;
    if (className.endsWith('Failure')) return false;

    return true;
  }

  /// Checks if class is a simple value object
  bool _isValueObject(String className) {
    // Common value object patterns
    const valueObjectPatterns = [
      'Email',
      'Money',
      'Address',
      'PhoneNumber',
      'Url',
      'Username',
      'Password',
      'Date',
      'Time',
      'Currency',
      'Price',
      'Quantity',
    ];

    for (final pattern in valueObjectPatterns) {
      if (className.contains(pattern)) return true;
    }

    // Explicit value object naming
    if (className.endsWith('Value')) return true;
    if (className.endsWith('VO')) return true;

    return false;
  }

  /// Checks if class has @freezed annotation
  bool _hasFreezedAnnotation(ClassDeclaration classNode) {
    final metadata = classNode.metadata;
    for (final annotation in metadata) {
      final name = annotation.name.name;
      if (name == 'freezed' || name == 'Freezed') return true;
    }
    return false;
  }

  /// Checks if class is sealed
  bool _isSealedClass(ClassDeclaration classNode) {
    return classNode.sealedKeyword != null;
  }

  /// Checks if there's an extension for this class in the same file
  bool _hasExtensionInFile(String className, ClassDeclaration classNode) {
    final compilationUnit = classNode.thisOrAncestorOfType<CompilationUnit>();
    if (compilationUnit == null) return false;

    for (final declaration in compilationUnit.declarations) {
      if (declaration is ExtensionDeclaration) {
        final extendedType = declaration.onClause?.extendedType;
        if (extendedType != null && extendedType is NamedType) {
          final typeName = extendedType.name2.lexeme;
          if (typeName == className) {
            // Check if extension has methods
            final methods = declaration.members.whereType<MethodDeclaration>().where((m) => !m.isStatic).toList();
            if (methods.isNotEmpty) return true;
          }
        }
      }
    }
    return false;
  }

  /// Checks if class has business logic methods
  bool _hasBusinessLogicMethods(ClassDeclaration classNode) {
    final methods = classNode.members.whereType<MethodDeclaration>();

    for (final method in methods) {
      // Skip private methods
      if (method.name.lexeme.startsWith('_')) continue;

      // Skip static methods
      if (method.isStatic) continue;

      // Skip setters
      if (method.isSetter) continue;

      // Skip simple getters (these are not business logic)
      if (method.isGetter && _isSimpleGetter(method)) continue;

      // Skip constructors
      if (method.name.lexeme == classNode.name.lexeme) continue;

      // Skip common utility methods
      if (_isUtilityMethod(method.name.lexeme)) continue;

      // This is a business logic method
      return true;
    }

    return false;
  }

  /// Checks if getter is a simple field accessor
  bool _isSimpleGetter(MethodDeclaration method) {
    if (!method.isGetter) return false;

    // Simple getters typically just return a field
    // Complex getters with logic are business logic
    final body = method.body;
    if (body is ExpressionFunctionBody) {
      // Expression body: get foo => _foo; (simple)
      // vs: get isValid => email.contains('@'); (business logic)
      final expression = body.expression;
      return expression is SimpleIdentifier || expression is PropertyAccess;
    }

    return false;
  }

  /// Checks if method name indicates a utility method
  bool _isUtilityMethod(String methodName) {
    const utilityMethods = [
      'toString',
      'toJson',
      'fromJson',
      'copyWith',
      'toMap',
      'fromMap',
      'toEntity',
      'fromEntity',
      'hashCode',
      'operator==',
    ];
    return utilityMethods.contains(methodName);
  }

  /// Checks if class has non-final fields
  bool _hasMutableFields(ClassDeclaration classNode) {
    final fields = classNode.members.whereType<FieldDeclaration>();

    for (final field in fields) {
      // Skip static fields
      if (field.isStatic) continue;

      // Check if field is final
      if (!field.fields.isFinal && !field.fields.isConst) {
        return true;
      }
    }

    return false;
  }
}
