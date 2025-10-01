# Clean Architecture Guide

This guide provides best practices for implementing Clean Architecture in Flutter/Dart projects.

## Table of Contents

- [Layer Overview](#layer-overview)
- [Dependency Rules](#dependency-rules)
- [Layer-Specific Patterns](#layer-specific-patterns)
- [Data Flow](#data-flow)
- [Common Patterns](#common-patterns)
- [Examples](#examples)

## Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer (UI)                                     │
│ • State Management (Riverpod with riverpod_generator)      │
│ • UI Components (Widgets, Pages, Screens)                  │
│ • View Models / UI State (Freezed)                         │
│ • Uses: Domain Entities                                     │
└─────────────────────────────────────────────────────────────┘
                           ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│ Domain Layer (Business Logic)                               │
│ • Entities (Freezed)                                        │
│ • Use Cases (Business Rules)                                │
│ • Repository Interfaces (Abstractions)                      │
│ • Domain Services                                            │
└─────────────────────────────────────────────────────────────┘
                           ↑ implements
┌─────────────────────────────────────────────────────────────┐
│ Data Layer (External Data)                                  │
│ • Models (Freezed for JSON/DB)                              │
│ • Repository Implementations                                │
│ • Data Sources (Remote, Local, Cache)                       │
│ • API Clients                                                │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Rules

### Golden Rule: Dependencies Point Inward

**Allowed Dependencies:**
- ✅ Presentation → Domain
- ✅ Data → Domain
- ✅ Presentation (internal dependencies)
- ✅ Data (internal dependencies)
- ✅ Domain (internal dependencies)

**Prohibited Dependencies:**
- ❌ Domain → Presentation
- ❌ Domain → Data
- ❌ Presentation → Data

### Import Rules

```dart
// ✅ GOOD: Presentation imports Domain
// presentation/widgets/ranking_list.dart
import 'package:app/features/rankings/domain/entities/ranking.dart';

// ❌ BAD: Presentation imports Data
// presentation/widgets/ranking_list.dart
import 'package:app/features/rankings/data/models/ranking_model.dart';

// ✅ GOOD: Data imports Domain
// data/repositories/ranking_repository_impl.dart
import 'package:app/features/rankings/domain/entities/ranking.dart';
import 'package:app/features/rankings/domain/repositories/ranking_repository.dart';

// ❌ BAD: Domain imports Data
// domain/usecases/get_rankings.dart
import 'package:app/features/rankings/data/models/ranking_model.dart';
```

## Layer-Specific Patterns

### 1. Data Layer: Use Freezed Models

**Purpose**: Handle external data formats (JSON, Database, API responses)

**Key Pattern**: Freezed Model contains Entity + JSON fields + Extension methods

```dart
// data/models/ranking_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/ranking.dart';

part 'ranking_model.freezed.dart';
part 'ranking_model.g.dart';

@freezed
class RankingModel with _$RankingModel {
  const factory RankingModel({
    required Ranking entity,  // Contains Domain Entity
    @JsonKey(name: 'start_time') required String startTime,  // API field
    @JsonKey(name: 'end_time') required String endTime,  // API field
    @JsonKey(name: 'attendee_count') required int attendeeCount,  // API field
  }) = _RankingModel;

  // Custom fromJson that builds both Model and Entity
  factory RankingModel.fromJson(Map<String, dynamic> json) {
    // Build Entity from JSON
    final entity = Ranking(
      id: json['id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      attendeeCount: json['attendee_count'] as int,
    );

    // Build Model with Entity
    return RankingModel(
      entity: entity,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      attendeeCount: json['attendee_count'] as int,
    );
  }

  // Custom toJson for API requests
  Map<String, dynamic> toJson() => {
    'id': entity.id,
    'start_time': startTime,
    'end_time': endTime,
    'attendee_count': attendeeCount,
  };
}

// Model conversion extensions
extension RankingModelX on RankingModel {
  // Extract Domain Entity from Model (simple getter)
  Ranking toEntity() => entity;
}

extension RankingToModelX on Ranking {
  // Convert Domain Entity to Model
  RankingModel toModel() {
    return RankingModel(
      entity: this,
      startTime: startTime.toIso8601String(),
      endTime: endTime.toIso8601String(),
      attendeeCount: attendeeCount,
    );
  }
}
```

**Data Source Example:**

```dart
// data/datasources/ranking_remote_datasource.dart
abstract class RankingRemoteDataSource {
  Future<List<RankingModel>> getRankings();
  Future<RankingModel> createRanking(RankingModel model);
}

class RankingRemoteDataSourceImpl implements RankingRemoteDataSource {
  final http.Client client;

  RankingRemoteDataSourceImpl({required this.client});

  @override
  Future<List<RankingModel>> getRankings() async {
    final response = await client.get(Uri.parse('$baseUrl/rankings'));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => RankingModel.fromJson(json)).toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<RankingModel> createRanking(RankingModel model) async {
    final response = await client.post(
      Uri.parse('$baseUrl/rankings'),
      body: json.encode(model.toJson()),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return RankingModel.fromJson(json.decode(response.body));
    } else {
      throw ServerException();
    }
  }
}
```

**Repository Implementation:**

```dart
// data/repositories/ranking_repository_impl.dart
import '../../domain/entities/ranking.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../datasources/ranking_remote_datasource.dart';
import '../models/ranking_model.dart';

class RankingRepositoryImpl implements RankingRepository {
  final RankingRemoteDataSource remoteDataSource;

  RankingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Ranking>> getRankings() async {
    // Get Models from data source
    final models = await remoteDataSource.getRankings();

    // Convert Models to Entities using extension
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Ranking> createRanking(Ranking ranking) async {
    // Convert Entity to Model using extension
    final model = ranking.toModel();

    // Send Model to data source
    final resultModel = await remoteDataSource.createRanking(model);

    // Convert back to Entity
    return resultModel.toEntity();
  }
}
```

### 2. Domain Layer: Use Freezed Entities

**Purpose**: Represent business objects independent of external systems

**Key Pattern**: Freezed Entity + Extension methods for business logic

```dart
// domain/entities/ranking.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ranking.freezed.dart';
part 'ranking.g.dart';

@freezed
class Ranking with _$Ranking {
  const factory Ranking({
    required String id,
    required DateTime startTime,
    required DateTime endTime,
    required int attendeeCount,
  }) = _Ranking;

  factory Ranking.fromJson(Map<String, dynamic> json) =>
      _$RankingFromJson(json);
}

// Business logic in extensions
extension RankingX on Ranking {
  Duration get duration => endTime.difference(startTime);

  bool get isHighAttendance => attendeeCount > 5;

  bool isOverlapping(Ranking other) {
    return startTime.isBefore(other.endTime) &&
           endTime.isAfter(other.startTime);
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
```

**Repository Interface:**

```dart
// domain/repositories/ranking_repository.dart
import '../entities/ranking.dart';

abstract class RankingRepository {
  Future<List<Ranking>> getRankings();
  Future<Ranking> getRankingById(String id);
  Future<Ranking> createRanking(Ranking ranking);
  Future<void> deleteRanking(String id);
}
```

**Use Case:**

```dart
// domain/usecases/get_rankings_usecase.dart
import '../entities/ranking.dart';
import '../repositories/ranking_repository.dart';

class GetRankingsUseCase {
  final RankingRepository repository;

  GetRankingsUseCase(this.repository);

  Future<List<Ranking>> call({bool onlyHighAttendance = false}) async {
    final rankings = await repository.getRankings();

    if (onlyHighAttendance) {
      // Use business logic from extension
      return rankings.where((r) => r.isHighAttendance).toList();
    }

    return rankings;
  }
}
```

### 3. Presentation Layer: Use Riverpod + Freezed State (NO ViewModels)

**Purpose**: Manage UI state and user interactions

**Key Pattern**: Riverpod Generator + Freezed State + Extension methods for UI logic

**Important**: We use **State** pattern, NOT **ViewModel** pattern. ViewModels are from the old MVVM pattern with ChangeNotifier.

#### Why State, Not ViewModel?

| Aspect | ViewModel (Old Pattern) | State (Our Pattern) |
|--------|------------------------|---------------------|
| **Mutability** | Mutable state | Immutable state (Freezed) |
| **Separation** | Logic + Data mixed | State (data) + Notifier (logic) separated |
| **Pattern** | MVVM with ChangeNotifier | Riverpod State Management |
| **Updates** | `notifyListeners()` | `state = newState` |
| **Debugging** | Hard to track changes | Easy time-travel debugging |

```dart
// ❌ OLD: ViewModel Pattern (Don't use)
class RankingViewModel extends ChangeNotifier {
  List<Ranking> rankings = [];  // Mutable
  bool isLoading = false;

  void loadRankings() {
    isLoading = true;
    notifyListeners();  // Manual notification
  }
}

// ✅ NEW: State Pattern (Use this)
@freezed
class RankingState with _$RankingState {
  const factory RankingState({
    @Default([]) List<Ranking> rankings,  // Immutable
    @Default(false) bool isLoading,
  }) = _RankingState;
}

@riverpod
class RankingNotifier extends _$RankingNotifier {
  @override
  RankingState build() => const RankingState();

  Future<void> loadRankings() async {
    state = state.copyWith(isLoading: true);  // Immutable update
  }
}
```

#### Riverpod with riverpod_generator

**State Class:**

```dart
// presentation/states/ranking_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/ranking.dart';

part 'ranking_state.freezed.dart';

@freezed
class RankingState with _$RankingState {
  const factory RankingState({
    @Default([]) List<Ranking> rankings,
    @Default(null) String? selectedRankingId,
    @Default(false) bool isLoading,
    @Default(null) String? error,
  }) = _RankingState;
}

// Computed properties and UI logic in extensions
extension RankingStateX on RankingState {
  List<Ranking> get highAttendanceRankings =>
      rankings.where((r) => r.isHighAttendance).toList();

  Ranking? get selectedRanking =>
      rankings.cast<Ranking?>().firstWhere(
        (r) => r?.id == selectedRankingId,
        orElse: () => null,
      );

  int get totalAttendees =>
      rankings.fold(0, (sum, r) => sum + r.attendeeCount);

  bool isSelected(String id) => selectedRankingId == id;
}
```

**Notifier with riverpod_generator:**

```dart
// presentation/providers/ranking_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/usecases/get_rankings_usecase.dart';
import '../states/ranking_state.dart';

part 'ranking_provider.g.dart';

@riverpod
class RankingNotifier extends _$RankingNotifier {
  @override
  RankingState build() {
    return const RankingState();
  }

  Future<void> loadRankings({bool onlyHighAttendance = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final getRankingsUseCase = ref.read(getRankingsUseCaseProvider);
      final rankings = await getRankingsUseCase(
        onlyHighAttendance: onlyHighAttendance,
      );
      state = state.copyWith(rankings: rankings, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void selectRanking(String rankingId) {
    state = state.copyWith(selectedRankingId: rankingId);
  }

  void clearSelection() {
    state = state.copyWith(selectedRankingId: null);
  }
}
```

**Widget:**

```dart
// presentation/widgets/ranking_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ranking_provider.dart';
import '../states/ranking_state.dart';

class RankingList extends ConsumerWidget {
  const RankingList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rankingNotifierProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}'));
    }

    return Column(
      children: [
        // Use computed property from extension
        Text('Total Attendees: ${state.totalAttendees}'),
        Expanded(
          child: ListView.builder(
            itemCount: state.rankings.length,
            itemBuilder: (context, index) {
              final ranking = state.rankings[index];
              final isSelected = state.isSelected(ranking.id);

              return RankingItem(
                ranking: ranking,
                isSelected: isSelected,
                onTap: () {
                  ref.read(rankingNotifierProvider.notifier)
                      .selectRanking(ranking.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
```

## Data Flow

### Complete Flow Example

```
User Action (Tap Button)
         ↓
[Presentation] Widget calls Notifier method
         ↓
[Presentation] Notifier calls UseCase
         ↓
[Domain] UseCase calls Repository Interface
         ↓
[Data] Repository Implementation calls DataSource
         ↓
[Data] DataSource fetches JSON from API
         ↓
[Data] DataSource converts JSON → Model (Freezed)
         ↓
[Data] Repository converts Model → Entity (Extension)
         ↓
[Domain] UseCase applies business logic to Entities
         ↓
[Presentation] Notifier updates State (Freezed) with Entities
         ↓
[Presentation] Widget rebuilds with new State
         ↓
User sees updated UI
```

### Code Flow Example

```dart
// 1. User taps button in Widget
ElevatedButton(
  onPressed: () {
    // 2. Call Notifier method
    ref.read(rankingNotifierProvider.notifier).loadRankings();
  },
)

// 3. Notifier calls UseCase
Future<void> loadRankings(...) async {
  final rankings = await getRankingsUseCase();  // Domain Entity
  state = state.copyWith(rankings: rankings);   // Update Freezed State
}

// 4. UseCase calls Repository
Future<List<Ranking>> call() async {
  return await repository.getRankings();  // Domain Entity
}

// 5. Repository calls DataSource
Future<List<Ranking>> getRankings() async {
  final models = await remoteDataSource.getRankings();     // Freezed Model
  return models.map((m) => m.toEntity()).toList();         // Extension conversion
}

// 6. DataSource fetches from API
Future<List<RankingModel>> getRankings() async {
  final response = await client.get(...);
  final json = jsonDecode(response.body);
  return json.map((j) => RankingModel.fromJson(j)).toList();  // Freezed fromJson
}

// 7. Widget rebuilds with new state
final state = ref.watch(rankingNotifierProvider);  // Freezed State
return Text('Count: ${state.rankings.length}');     // Use Entity
```

## Common Patterns

### Pattern 1: UI-Specific Logic (Extension Methods)

When you need simple UI formatting or calculations, use extensions on Domain Entities:

```dart
// presentation/extensions/ranking_ui_extensions.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/ranking.dart';

extension RankingUIX on Ranking {
  String get formattedTimeRange {
    final start = DateFormat('HH:mm').format(startTime);
    final end = DateFormat('HH:mm').format(endTime);
    return '$start - $end';
  }

  Color get attendanceColor {
    if (attendeeCount > 10) return Colors.green;
    if (attendeeCount > 5) return Colors.orange;
    return Colors.red;
  }

  IconData get attendanceIcon {
    if (isHighAttendance) return Icons.group;
    return Icons.person;
  }

  String get attendanceLabel {
    if (attendeeCount == 0) return 'No attendees';
    if (attendeeCount == 1) return '1 attendee';
    return '$attendeeCount attendees';
  }
}

// Usage in Widget
Text(ranking.formattedTimeRange);
Icon(ranking.attendanceIcon, color: ranking.attendanceColor);
Text(ranking.attendanceLabel);
```

### Pattern 2: Complex UI State (Freezed State + Extensions)

When you need to combine multiple entities or track complex UI state:

```dart
// presentation/states/ranking_ui_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/ranking.dart';

part 'ranking_ui_state.freezed.dart';

enum RankingFilter { all, highAttendance, selected }
enum RankingSortOrder { byTime, byAttendance }

@freezed
class RankingUIState with _$RankingUIState {
  const factory RankingUIState({
    @Default([]) List<Ranking> rankings,
    @Default({}) Set<String> selectedIds,
    @Default({}) Map<String, bool> expandedStates,
    @Default(RankingFilter.all) RankingFilter filter,
    @Default(RankingSortOrder.byTime) RankingSortOrder sortOrder,
  }) = _RankingUIState;
}

// Computed properties in extension
extension RankingUIStateX on RankingUIState {
  List<Ranking> get filteredRankings {
    var result = rankings;

    switch (filter) {
      case RankingFilter.highAttendance:
        result = result.where((r) => r.isHighAttendance).toList();
        break;
      case RankingFilter.selected:
        result = result.where((r) => selectedIds.contains(r.id)).toList();
        break;
      default:
        break;
    }

    return _sortRankings(result);
  }

  List<Ranking> get selectedRankings =>
      rankings.where((r) => selectedIds.contains(r.id)).toList();

  int get totalSelectedAttendees =>
      selectedRankings.fold(0, (sum, r) => sum + r.attendeeCount);

  bool isSelected(String id) => selectedIds.contains(id);

  bool isExpanded(String id) => expandedStates[id] ?? false;

  List<Ranking> _sortRankings(List<Ranking> rankings) {
    final sorted = List<Ranking>.from(rankings);
    switch (sortOrder) {
      case RankingSortOrder.byTime:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case RankingSortOrder.byAttendance:
        sorted.sort((a, b) => b.attendeeCount.compareTo(a.attendeeCount));
        break;
    }
    return sorted;
  }
}
```

### Pattern 3: UI-Specific State (Use State, Not Presentation Models)

When you need UI-specific data like selection or validation, use State classes that contain Entities:

```dart
// presentation/states/ranking_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/ranking.dart';

part 'ranking_state.freezed.dart';

@freezed
class RankingState with _$RankingState {
  const factory RankingState({
    @Default([]) List<Ranking> rankings,  // Domain Entities
    @Default({}) Set<String> selectedIds,  // UI state
    @Default({}) Map<String, String> validationErrors,  // UI validation
  }) = _RankingState;
}

// UI logic via extensions
extension RankingStateX on RankingState {
  List<Ranking> get selectedRankings =>
      rankings.where((r) => selectedIds.contains(r.id)).toList();

  bool isSelected(String id) => selectedIds.contains(id);

  String? validationError(String id) => validationErrors[id];

  bool canSelect(String id) => validationErrors[id] == null;

  // Computed UI properties using Entity extensions
  Color getStatusColor(Ranking ranking) {
    if (validationErrors[ranking.id] != null) return Colors.red;
    if (isSelected(ranking.id)) return Colors.blue;
    if (ranking.isHighAttendance) return Colors.green;  // From Entity extension
    return Colors.grey;
  }
}

// Usage in Widget
final state = ref.watch(rankingNotifierProvider);
final ranking = state.rankings[0];
final color = state.getStatusColor(ranking);  // Use State extension
final label = ranking.formattedTimeRange;  // Use Entity extension
```

**Key Principle**: NO separate Presentation Models. State contains Entities + UI-specific fields.

## Examples

### Complete Feature Structure

```
lib/features/rankings/
├── data/
│   ├── datasources/
│   │   ├── ranking_local_datasource.dart
│   │   └── ranking_remote_datasource.dart
│   ├── models/
│   │   └── ranking_model.dart              # Freezed + extensions
│   └── repositories/
│       └── ranking_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── ranking.dart                    # Freezed + extensions
│   ├── repositories/
│   │   └── ranking_repository.dart
│   └── usecases/
│       ├── get_rankings_usecase.dart
│       ├── create_ranking_usecase.dart
│       └── delete_ranking_usecase.dart
└── presentation/
    ├── providers/
    │   └── ranking_provider.dart           # riverpod_generator (Notifier)
    ├── states/
    │   └── ranking_state.dart              # Freezed State (uses Domain Entities)
    ├── extensions/
    │   └── ranking_ui_extensions.dart      # UI-specific extensions on Entities
    ├── pages/
    │   └── ranking_page.dart
    └── widgets/
        ├── ranking_list.dart
        └── ranking_item.dart
    # NOTE: No models/ directory - State uses Domain Entities directly
    # NOTE: No viewmodels/ directory - we use State pattern, not ViewModel pattern
```

### Decision Tree: Which Pattern to Use?

```
Need UI-specific data?
├─ Simple formatting/calculation on Entity?
│  └─ ✅ Use Extension Methods on Entity
│
├─ Complex UI state (selection, filters, sorting, validation)?
│  └─ ✅ Use Freezed State (contains Entities) + Extensions
│
├─ Just displaying entity data?
│  └─ ✅ Use Entity directly
│
└─ Need Presentation Model?
   └─ ❌ NO - Use State with Entities instead
```

**Key Decision**:
- **Entity Extension**: For UI formatting/calculations on single Entity
- **State Extension**: For UI logic involving multiple Entities or UI-specific state
- **NO Presentation Models**: State already contains Entities + UI fields

## Best Practices

### DO ✅

- **Use Freezed Models in Data Layer** - Model contains Entity + API fields
- **Use Freezed Entities in Domain Layer** for business objects
- **Use Extensions for functions** - keep Freezed classes pure data
- **Use riverpod_generator** for state management providers
- **Use Freezed State in Presentation** for UI state management
- **Models contain Entities** - `RankingModel` has `entity` field
- **Extract Entities from Models** using `model.toEntity()` (returns `model.entity`)
- **Keep business logic** in Domain entity extensions
- **Keep UI logic** in Presentation extensions

### DON'T ❌

- **Don't use Data Models in Presentation** layer - use Domain Entities
- **Don't use Data Models in Domain** layer
- **Don't create Presentation Models** - State contains Entities directly
- **Don't use ViewModels** - use State pattern with Riverpod instead
- **Don't use ChangeNotifier** - use Freezed State + Notifier instead
- **Don't put methods inside Freezed classes** - use extensions instead
- **Don't put business logic** in Presentation layer
- **Don't put UI logic** in Domain layer
- **Don't mix layers** - respect dependency boundaries
- **Don't use Equatable** - use Freezed for value equality
- **Don't create presentation/models/ directory** - use states/ with Entities
- **Don't create presentation/viewmodels/ directory** - use states/ + providers/

### When in Doubt

- If it's about **external data format** (JSON, DB) → **Freezed Model** (Data Layer)
- If it's about **business rules** → **Freezed Entity + Extension** (Domain Layer)
- If it's about **UI state or formatting** → **Freezed State + Extension** (Presentation Layer)
- If it's **any function/method** → **Extension**, not inside Freezed class

## Summary

| Layer | What to Use | Purpose | Example |
|-------|-------------|---------|---------|
| **Data** | Freezed Models (contains Entity) + Extensions | JSON/DB serialization | `RankingModel.fromJson()`, `model.toEntity()` (returns `model.entity`) |
| **Domain** | Freezed Entities + Extensions | Business logic | `Ranking`, `ranking.isHighAttendance` |
| **Presentation** | Freezed State + riverpod_generator + Extensions | UI state & interactions | `RankingState`, `RankingNotifier` |

**Tech Stack:**
- **State Management**: Riverpod with `riverpod_generator`
- **Immutability**: Freezed for all data classes (Models, Entities, States)
- **Functions**: Extensions (never inside Freezed classes)
- **JSON**: Custom `fromJson`/`toJson` in Models
- **Model Structure**: Model contains Entity + API-specific fields

**Key Pattern:**
```dart
// Data Model contains Entity
@freezed
sealed class RankingModel with _$RankingModel {
  const factory RankingModel({
    required Ranking entity,  // Domain Entity inside
    required String startTime,  // API field
  }) = _RankingModel;
}

// Simple extraction
Ranking entity = model.toEntity();  // Returns model.entity
```

Remember: **Models contain Entities**, **Extensions for functions**, **Riverpod for state**.
