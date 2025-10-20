# PRD: Riverpod State Management Pattern for Clean Architecture Linter

## Overview

Update the Clean Architecture Linter's documentation and rules to enforce best practices for Riverpod state management in Flutter applications following Clean Architecture principles.

## Problem Statement

Current linter documentation shows anti-patterns where:
1. Entity and UI state are mixed in a single State class with manual loading/error management
2. AsyncValue is not properly utilized, leading to manual `isLoading` and `errorMessage` fields
3. Developers are unclear on how to structure Entity Providers vs UI State Providers
4. No guidance on proper use of Riverpod family pattern with entity dependencies

This leads to:
- Linter warnings (`presentation_use_async_value`)
- Increased code complexity
- Poor separation of concerns
- Difficult testing
- Performance issues (unnecessary rebuilds)

## Goals

1. Document the **3-tier Provider architecture**: Entity Providers → UI State Providers → Computed Logic Providers
2. Create lint rules to enforce AsyncValue usage for entity data
3. Provide clear examples of entity-UI state separation
4. Show proper Riverpod family pattern with ID-based dependencies
5. Integrate patterns into CLAUDE.md and CLEAN_ARCHITECTURE_GUIDE.md

## Target Architecture Pattern

### Tier 1: Entity Providers (Data Layer Interface)

```dart
// AsyncNotifier for entity data with AsyncValue
@riverpod
class ScheduleList extends _$ScheduleList {
  @override
  Future<List<Schedule>> build({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Load from UseCase
    final result = await ref.read(getScheduleListUseCaseProvider)(
      startDate: startDate,
      endDate: endDate,
    );

    return result.when(
      success: (schedules) => schedules,
      failure: (failure) => throw failure,
    );
  }
}

@riverpod
class ScheduleDetail extends _$ScheduleDetail {
  @override
  Future<Schedule> build(String scheduleId) async {
    final result = await ref.read(getScheduleDetailUseCaseProvider)(scheduleId);
    return result.when(
      success: (schedule) => schedule,
      failure: (failure) => throw failure,
    );
  }

  Future<void> confirmSchedule(List<String> attendeeIds) async {
    // Update entity
  }
}
```

### Tier 2: UI State Providers (Depends on Entity)

```dart
// UI-only state with entity dependency
@freezed
class ScheduleDetailUIState with _$ScheduleDetailUIState {
  const factory ScheduleDetailUIState({
    @Default([]) List<String> selectedAttendeeIds,
    @Default(false) bool isConfirmationDialogOpen,
    @Default(false) bool isSubmitting,
  }) = _ScheduleDetailUIState;
}

@riverpod
class ScheduleDetailUI extends _$ScheduleDetailUI {
  @override
  ScheduleDetailUIState build(String scheduleId) {
    // Depend on entity provider
    ref.listen(
      scheduleDetailProvider(scheduleId),
      (previous, next) {
        // Reset UI state when entity changes
        next.whenData((_) {
          if (previous?.value?.id != next.value?.id) {
            state = const ScheduleDetailUIState();
          }
        });
      },
    );

    return const ScheduleDetailUIState();
  }

  void toggleAttendee(String attendeeId) {
    // UI state updates only
  }
}
```

### Tier 3: Computed Logic Providers (Entity + UI Combination)

```dart
// Combines entity and UI state for derived values
@riverpod
bool canConfirmSchedule(CanConfirmScheduleRef ref, String scheduleId) {
  final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));
  final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));

  return scheduleAsync.when(
    data: (schedule) =>
        uiState.hasSelection &&
        !schedule.isExpired &&
        uiState.selectedCount <= schedule.maxAttendees,
    loading: () => false,
    error: (_, __) => false,
  );
}
```

### Entity UI Extensions (Formatting Only)

```dart
extension ScheduleUIX on Schedule {
  String get formattedDate => DateFormat('MMM dd, yyyy').format(startDate);
  Color get statusColor => isExpired ? Colors.grey : Colors.green;
  IconData get statusIcon => isExpired ? Icons.event_busy : Icons.check_circle;
}
```

## Requirements

### Documentation Updates

1. **CLAUDE.md Updates**
   - Add "Riverpod State Management Patterns" section
   - Document 3-tier provider architecture
   - Show entity provider examples with AsyncNotifier
   - Show UI state provider examples with entity dependencies
   - Show computed logic provider examples
   - Add common violations and solutions

2. **CLEAN_ARCHITECTURE_GUIDE.md Updates**
   - Replace anti-pattern examples with proper patterns
   - Add comprehensive Riverpod state management section
   - Show entity list + detail provider patterns
   - Document family pattern best practices (ID-based, not entity-based)
   - Add widget usage examples with AsyncValue.when()

3. **README.md Updates**
   - Add Riverpod state management to feature list
   - Link to detailed guide sections

### New Lint Rules (Optional - Future Enhancement)

Consider creating rules to enforce:

1. **presentation_state_use_async_notifier**
   - Detect entity providers not using AsyncNotifier
   - Suggest converting to AsyncNotifier pattern

2. **presentation_ui_state_separation**
   - Detect State classes mixing entity and UI fields
   - Suggest separating into entity provider + UI state provider

3. **presentation_family_id_pattern**
   - Detect family providers receiving entity objects instead of IDs
   - Suggest using ID-based family pattern

## Success Criteria

1. CLAUDE.md contains complete Riverpod state management patterns section
2. CLEAN_ARCHITECTURE_GUIDE.md has entity provider + UI state examples
3. All code examples follow 3-tier provider architecture
4. No manual isLoading/errorMessage fields in examples
5. All entity data uses AsyncNotifier with AsyncValue
6. UI state providers show proper entity dependency with ref.watch/ref.listen
7. Computed logic providers demonstrate entity + UI combination
8. Widget examples use AsyncValue.when() pattern
9. Family pattern examples use ID-based dependencies

## Out of Scope

- Implementation of actual lint rules (documentation only for v1.0.4)
- Migration guide for existing codebases (can be added in future)
- Video tutorials or interactive examples

## Technical Constraints

- Must maintain compatibility with existing lint rules
- Must align with current Clean Architecture principles in the package
- Must use Riverpod 2.x patterns (riverpod_generator, riverpod_annotation)
- Examples must be valid Dart/Flutter code

## Examples to Include

### Example 1: Schedule List (Entity Provider)
- Fetches list of schedules for date range
- AsyncNotifier with AsyncValue
- Entity UI extensions for formatting

### Example 2: Schedule Detail (Entity Provider + UI State)
- Entity provider for single schedule
- UI state provider for selection/dialog state
- Computed providers for validation logic
- Widget with AsyncValue.when()

### Example 3: Multi-Entity Relationship
- Parent entity provider (e.g., User)
- Child entity provider depending on parent (e.g., UserSettings)
- UI state coordinating both
- Demonstrates ref.watch() dependency chain

## Dependencies

- Existing CLAUDE.md structure
- Existing CLEAN_ARCHITECTURE_GUIDE.md structure
- Current lint rule implementations
- Freezed for state classes
- Riverpod 2.x (riverpod_generator, riverpod_annotation)

## Timeline Considerations

This is documentation work primarily, so implementation should be straightforward:

1. Draft new documentation sections
2. Create code examples and verify they compile
3. Update CLAUDE.md with patterns
4. Update CLEAN_ARCHITECTURE_GUIDE.md with comprehensive guide
5. Update README.md with references
6. Review all existing examples in docs for anti-patterns
7. Test documentation with example Flutter project

## Future Enhancements

- Implement lint rules to enforce these patterns
- Add migration guide from anti-patterns to best practices
- Create example project demonstrating all patterns
- Add testing patterns for entity/UI state providers
- Document error handling strategies across provider tiers
