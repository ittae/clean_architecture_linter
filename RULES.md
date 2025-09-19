# Clean Architecture Linter Rules Guide

This document provides a comprehensive guide to all 39 lint rules in the Clean Architecture Linter, organized by their role in Uncle Bob's Clean Architecture.

## 🏗️ Understanding the Rules Organization

The rules are organized into **6 main categories** that map to Clean Architecture principles:

### 1. 🎯 Domain Layer Rules (11 rules)
**Purpose**: Enforce business logic purity and proper abstractions in the core
**Location**: `lib/src/rules/domain_rules/`
**Uncle Bob Quote**: *"Entities encapsulate Enterprise wide business rules."*

### 2. 💾 Data Layer Rules (7 rules)
**Purpose**: Validate repository implementations and data access patterns
**Includes**: Repository patterns + Boundary data rules
**Uncle Bob Quote**: *"Simple data structures are passed across the boundaries."*

### 3. 🎨 Presentation Layer Rules (3 rules)
**Purpose**: Enforce UI and delivery mechanism separation
**Location**: `lib/src/rules/presentation_rules/`
**Uncle Bob Quote**: *"Controllers, Presenters, and Gateways are all in the Interface Adapters layer."*

### 4. 🔗 Interface Adapter Rules (3 rules)
**Purpose**: Validate data format conversion patterns
**Location**: `lib/src/rules/adapter_rules/`
**Uncle Bob Quote**: *"Convert data from the format most convenient for entities and use cases."*

### 5. ⚙️ Framework & Driver Rules (4 rules)
**Purpose**: Isolate framework details in the outermost layer
**Location**: `lib/src/rules/framework_rules/`
**Uncle Bob Quote**: *"The outermost layer is generally composed of frameworks and tools."*

### 6. 🌐 Architectural Boundary Rules (11 rules)
**Purpose**: Enforce cross-cutting concerns and Uncle Bob's core principles
**Location**: `lib/src/rules/` (root level)
**Uncle Bob Quote**: *"Source code dependencies can only point inwards."*

---

## 📋 Detailed Rules Reference

### 🎯 Domain Layer Rules (11 rules)

#### Entity & Business Rules
- **`entity_business_rules`** - Ensures entities contain only enterprise business rules
- **`entity_stability`** - Validates entity stability and minimal change frequency
- **`entity_immutability`** - Enforces immutable domain entities (final fields, no setters)
- **`business_logic_isolation`** - Prevents business logic leakage to outer layers

#### Use Case & Application Rules
- **`usecase_orchestration`** - Validates use case orchestration of entities
- **`usecase_application_rules`** - Ensures use cases contain application-specific rules
- **`usecase_independence`** - Enforces use case independence from external concerns
- **`usecase_single_responsibility`** - Validates single responsibility principle in use cases

#### Domain Interfaces & Abstractions
- **`repository_interface`** - Validates proper repository abstractions in domain
- **`domain_model_validation`** - Ensures proper validation logic in domain models
- **`domain_purity`** - Prevents external framework dependencies in domain
- **`dependency_inversion`** - Validates dependency direction in domain layer

### 💾 Data Layer Rules (7 rules)

#### Repository & Data Source Implementation
- **`repository_implementation`** - Validates repository implementation patterns
- **`datasource_naming`** - Enforces proper naming conventions for data sources
- **`model_structure`** - Ensures data models have proper serialization methods

#### Boundary Data Management
- **`data_boundary_crossing`** - Validates proper data crossing boundaries (DTOs vs Entities)
- **`database_row_boundary`** - Prevents database row structures crossing inward
- **`dto_boundary_pattern`** - Enforces DTO patterns for boundary crossing
- **`entity_boundary_isolation`** - Isolates entities from outer layers

### 🎨 Presentation Layer Rules (3 rules)

- **`ui_dependency_injection`** - Prevents direct business logic instantiation in UI
- **`state_management`** - Validates proper state management patterns (BLoC, Provider, etc.)
- **`presentation_logic_separation`** - Enforces separation of presentation logic from UI widgets

### 🔗 Interface Adapter Rules (3 rules)

- **`data_conversion_adapter`** - Validates data format conversions between layers
- **`mvc_architecture`** - Enforces MVC patterns in adapter layer
- **`external_service_adapter`** - Validates external service adapter patterns and interfaces

### ⚙️ Framework & Driver Rules (4 rules)

- **`framework_isolation`** - Isolates framework details in outermost layer
- **`database_detail`** - Keeps database implementation details in framework layer
- **`web_framework_detail`** - Isolates web framework specifics (HTTP, routing)
- **`glue_code`** - Validates glue code patterns for dependency injection

### 🌐 Architectural Boundary Rules (11 rules)

#### Core Dependency Management
- **`layer_dependency`** - Enforces The Dependency Rule (dependencies point inward only)
- **`circular_dependency`** - Prevents circular dependencies between components
- **`core_dependency`** - Validates core dependency patterns and abstractions
- **`abstraction_level`** - Ensures proper abstraction levels across layers
- **`flexible_layer_detection`** - Supports flexible layer architectures (more than 4 layers)

#### Boundary Crossing Patterns
- **`boundary_crossing`** - Validates proper boundary crossing mechanisms
- **`dependency_inversion_boundary`** - Enforces dependency inversion at layer boundaries
- **`interface_boundary`** - Validates interface boundary patterns and contracts
- **`polymorphic_flow_control`** - Ensures polymorphic flow control inversion
- **`abstraction_progression`** - Validates abstraction progression from concrete to abstract
- **`clean_architecture_benefits`** - Ensures architecture provides testability and flexibility

---

## 🎯 How Rules Map to Clean Architecture Layers

### Traditional 3-Layer Mapping

| Clean Architecture Layer | Rules Count | Primary Focus |
|-------------------------|-------------|---------------|
| **Domain** (Business Logic) | 11 rules | Entity integrity, Use case patterns, Business rule isolation |
| **Data** (Repository Implementations) | 7 rules | Data access patterns, Boundary data handling |
| **Presentation** (UI & Delivery) | 3 rules | UI separation, State management patterns |

### Extended 4+ Layer Mapping

| Uncle Bob's Layers | Rules Count | Rule Categories |
|-------------------|-------------|-----------------|
| **Entities** | 4 rules | Entity business rules, stability, immutability |
| **Use Cases** | 4 rules | Application business rules, orchestration |
| **Interface Adapters** | 10 rules | Controllers, Presenters, Gateways (Data + Adapter rules) |
| **Frameworks & Drivers** | 4 rules | Framework isolation, external details |
| **Cross-Cutting** | 17 rules | Boundaries, dependencies, architectural integrity |

---

## 💡 Quick Start Guide

### For Domain-Focused Development
Enable these rule groups first:
```yaml
custom_lint:
  rules:
    # Start with core domain rules
    - entity_immutability
    - business_logic_isolation
    - usecase_single_responsibility
    - domain_purity
    - layer_dependency
```

### For Data Layer Development
Focus on these patterns:
```yaml
custom_lint:
  rules:
    # Data layer essentials
    - repository_implementation
    - data_boundary_crossing
    - entity_boundary_isolation
    - dependency_inversion_boundary
```

### For Full Clean Architecture Compliance
Enable all 39 rules for comprehensive validation.

---

## 🔍 Rule Activation Strategy

1. **Phase 1 - Core Rules** (Start here)
   - `layer_dependency`, `domain_purity`, `entity_immutability`

2. **Phase 2 - Boundary Rules** (Add gradually)
   - `data_boundary_crossing`, `dependency_inversion_boundary`

3. **Phase 3 - Pattern Rules** (Comprehensive)
   - All remaining rules for full architectural compliance

This phased approach helps teams adopt Clean Architecture incrementally without overwhelming violation reports.