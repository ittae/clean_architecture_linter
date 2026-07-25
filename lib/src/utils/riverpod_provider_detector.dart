import 'package:analyzer/dart/ast/ast.dart';

import '../compat/analyzer_ast_compat.dart';

/// Shared Riverpod 3 provider/notifier recognition.
///
/// Historically several presentation rules each carried their own
/// `_isRiverpodProviderClass` gate that only accepted codegen state classes
/// (a `@riverpod` annotation or an `extends _$Name` generated superclass).
/// Riverpod 3.3 keeps the **non-codegen** class API first-class —
/// `class TodoNotifier extends Notifier<Todo>`,
/// `extends AsyncNotifier<Todo>`, `extends StreamNotifier<Todo>`, and their
/// `AutoDispose*` / `Family*` variants — so the codegen-only gate produced
/// false negatives on real Riverpod 3 code while the fake-provider fixtures
/// stayed green.
///
/// This module centralises the AST-based signals so every rule recognises the
/// same set of state-layer classes. The heuristics deliberately lean
/// false-negative (a missed report is safer than punishing valid code) and
/// work on parsed-only results — no element resolution required.

/// Flutter widget superclasses that are unambiguously UI layer, never a
/// Riverpod state-layer class.
const riverpodWidgetSuperclasses = {
  'StatelessWidget',
  'StatefulWidget',
  'State',
  'ConsumerWidget',
  'HookConsumerWidget',
  'HookWidget',
  'ConsumerState',
  'ConsumerStatefulWidget',
  'StatefulHookConsumerWidget',
};

/// Flutter notifiers that end in "Notifier" but are NOT Riverpod state layer.
/// Without this list, `class Foo extends ChangeNotifier` would be exempted by
/// the "ends with Notifier" suffix heuristic.
const nonRiverpodNotifierSuperclasses = {'ChangeNotifier', 'ValueNotifier'};

/// Whether [name] is a Riverpod `Notifier` family superclass — the codegen
/// base (`_$Name`) or any `*Notifier` (Notifier, AsyncNotifier, StreamNotifier
/// and their AutoDispose / Family variants, plus project-local base notifiers).
///
/// Returns `null` when the name is a known non-Riverpod class (a Flutter widget
/// or a `ChangeNotifier`/`ValueNotifier`), so callers can short-circuit before
/// falling back to weaker heuristics.
bool? _classifySuperclassName(String name) {
  if (name.startsWith('_\$')) return true;
  if (riverpodWidgetSuperclasses.contains(name)) return false;
  if (nonRiverpodNotifierSuperclasses.contains(name)) return false;
  if (name.endsWith('Notifier')) return true;
  return null;
}

/// Whether [className] looks like a Flutter UI class by name suffix
/// (`Page` / `Screen` / `View` / `Widget`) rather than a state-layer Notifier.
bool hasWidgetNameSuffix(String className) {
  return className.endsWith('Page') ||
      className.endsWith('Screen') ||
      className.endsWith('View') ||
      className.endsWith('Widget');
}

/// Whether [metadata] carries the Riverpod `@riverpod` / `@Riverpod(...)`
/// annotation.
bool hasRiverpodAnnotation(Iterable<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = annotation.name.name;
    if (name == 'riverpod' || name == 'Riverpod') return true;
  }
  return false;
}

/// Whether [node] declares a Riverpod state-layer class — a codegen Notifier
/// (`@riverpod` / `extends _$Name`) or a non-codegen `Notifier` family class
/// (`extends Notifier` / `AsyncNotifier` / `StreamNotifier` and variants).
///
/// Signals are checked strongest first, because the weak name heuristics on
/// both sides overlap: a provider may be called `TodoView` and a widget may be
/// called `TodoNotifier`.
///
/// 1. `@riverpod` / `@Riverpod(...)` annotation — unambiguous state layer.
/// 2. The superclass name: `_$Name` (codegen) or a `*Notifier` base, minus the
///    Flutter widgets and `ChangeNotifier`/`ValueNotifier` that also match the
///    suffix.
/// 3. Only then the class-name suffixes (widget-suffixed names are excluded).
bool isRiverpodNotifierClass(ClassDeclaration node) {
  if (hasRiverpodAnnotation(node.metadata)) return true;

  final superclassName = node.extendsClause?.superclass.name.lexeme;
  if (superclassName != null) {
    final classified = _classifySuperclassName(superclassName);
    if (classified != null) return classified;
  }

  final className = classDeclarationName(node);
  if (className == null) return false;
  if (hasWidgetNameSuffix(className)) return false;

  return className.endsWith('Notifier');
}

/// Riverpod provider constructors that declare state manually instead of via
/// the `@riverpod` generator. Recognising these lets `riverpod_generator`
/// nudge teams toward codegen.
///
/// Covers the legacy 2.x forms already flagged plus the Riverpod 3 non-codegen
/// `Notifier` family (`NotifierProvider`, `AsyncNotifierProvider`,
/// `StreamNotifierProvider`) and their `AutoDispose*` type-name variants.
/// Idiomatic `.autoDispose` / `.family` MethodInvocation chains are resolved
/// by `riverpod_generator` against this same set (root type must match).
///
/// Bare `Provider` / `FutureProvider` / `StreamProvider` for pure dependency
/// injection are intentionally NOT auto-expanded here beyond the existing set,
/// to avoid a false-positive surge on valid DI providers.
const manualRiverpodProviderConstructors = {
  // Legacy 2.x manual providers (already flagged historically).
  'StateNotifierProvider',
  'ChangeNotifierProvider',
  'StateProvider',
  'FutureProvider',
  'StreamProvider',
  // Riverpod 3 non-codegen Notifier family.
  'NotifierProvider',
  'AsyncNotifierProvider',
  'StreamNotifierProvider',
  // AutoDispose variants of the Notifier family.
  'AutoDisposeNotifierProvider',
  'AutoDisposeAsyncNotifierProvider',
  'AutoDisposeStreamNotifierProvider',
};

/// Whether [name] is a manual Riverpod provider constructor.
bool isManualRiverpodProviderConstructor(String name) =>
    manualRiverpodProviderConstructors.contains(name);
