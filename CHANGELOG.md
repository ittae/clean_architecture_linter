# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0](https://github.com/ittae/clean_architecture_linter/compare/clean_architecture_linter-v2.1.1...clean_architecture_linter-v3.0.0) (2026-07-20)


### ⚠ BREAKING CHANGES

* analysis_server_plugin + analyzer 13 전환 (v2.0.0-dev.1, ITT-307) ([#61](https://github.com/ittae/clean_architecture_linter/issues/61))
* Removed entity_business_logic rule

### Features

* add 'id' as an allowed metadata field in ModelFieldDuplicationRule ([14f335b](https://github.com/ittae/clean_architecture_linter/commit/14f335b516738693f5ac8d0af8c5d01f2e40e7a3))
* add check for Dart built-in types in concrete type validation ([0968f3f](https://github.com/ittae/clean_architecture_linter/commit/0968f3ff2a36c13d5937954960621a1cb7c677d6))
* add checks for missing data models corresponding to domain entities ([b450812](https://github.com/ittae/clean_architecture_linter/commit/b4508126445538c6ee75b6b7db53cb341a9bea16))
* add checks for unnecessary presentation models to prevent duplication of domain entities ([2e72a8d](https://github.com/ittae/clean_architecture_linter/commit/2e72a8db6f5804262fefb99a6ea27a68f4c46aab))
* add CI and publish workflows for automated testing and deployment ([3f8e847](https://github.com/ittae/clean_architecture_linter/commit/3f8e847e19ca3a84d7bf236a7cd3afe3295ece95))
* add CLAUDE.md for project guidance and development instructions ([e25fe9a](https://github.com/ittae/clean_architecture_linter/commit/e25fe9a262a7e7d53bedb287ed5b4d9f65bf4f7b))
* add comprehensive Clean Architecture guide for Flutter/Dart projects ([f64c312](https://github.com/ittae/clean_architecture_linter/commit/f64c31202bd8d3b1cd90953e6bd89e6a42d37f1f))
* add comprehensive configuration guides for Clean Architecture Linter ([a31de5b](https://github.com/ittae/clean_architecture_linter/commit/a31de5bb4f32b9a480b241b72d2e17b66dc85bba))
* Add comprehensive Rule Development Guide and Testing Guide ([e490b56](https://github.com/ittae/clean_architecture_linter/commit/e490b56db55610fe829e6eeef663d8cb6e1c677f))
* add comprehensive rules guide for Clean Architecture Linter in English and Korean ([6cfb659](https://github.com/ittae/clean_architecture_linter/commit/6cfb6599dee6e9ed7efa93441efda2fd6b6e3e93))
* Add comprehensive task management commands and workflows ([35f7240](https://github.com/ittae/clean_architecture_linter/commit/35f72402a747b4756fe48795e1a63d068b7089f7))
* Add comprehensive TaskMaster documentation and examples for Clean Architecture compliance ([fc52af5](https://github.com/ittae/clean_architecture_linter/commit/fc52af5300214dfad640b5d5d4916c13d8ed587a))
* add Core Dependency Rule and Flexible Layer Detection Rule for Clean Architecture enforcement ([3abf126](https://github.com/ittae/clean_architecture_linter/commit/3abf126b861c01bc6576fd2542624a053abca780))
* add DataSource abstraction rule and examples for Clean Architecture compliance ([8db7950](https://github.com/ittae/clean_architecture_linter/commit/8db79504d0e30ab592a335786fe15c5d9f878fd1))
* Add domain exceptions with feature prefixes and enhance exception naming conventions ([cba4cec](https://github.com/ittae/clean_architecture_linter/commit/cba4cecc87687a387d620af3cb2bc28921da83ed))
* add EntityBoundaryIsolationRule to enforce architectural boundaries ([0d46b7b](https://github.com/ittae/clean_architecture_linter/commit/0d46b7b7a0403b318b5b3ed0e4f7fb9c37a8519d))
* Add EntityBusinessLogicRule to enforce business logic in domain entities ([826c8f3](https://github.com/ittae/clean_architecture_linter/commit/826c8f3e6dc3fa4e7d5832784f5f775b2ccff095))
* Add error severity to various lint rules for improved error handling ([2cad6fd](https://github.com/ittae/clean_architecture_linter/commit/2cad6fd472ce240a5cab0dbbe04112a642c85fd6))
* add instance variables validation and improve domain layer rules ([f7c8485](https://github.com/ittae/clean_architecture_linter/commit/f7c8485c6ef57a57a6b0c2c5617aecf44fab8583))
* Add lint rules for Clean Architecture enforcement ([0e3ae77](https://github.com/ittae/clean_architecture_linter/commit/0e3ae77bbd5acbd9cfc264dd8ae46043d50ed43b))
* Add mixins for standardized validation in Clean Architecture lint rules ([06ebf10](https://github.com/ittae/clean_architecture_linter/commit/06ebf10c5b96d283340406e525ccdfd2333ce1fb))
* Add ModelConversionMethodsRule to enforce conversion methods in data models ([efcb482](https://github.com/ittae/clean_architecture_linter/commit/efcb4829410b05920a16cb0d873075cd8c7af40f))
* Add ModelEntityDirectAccessRule to enforce using toEntity() method instead of direct .entity access in Data layer ([a74b907](https://github.com/ittae/clean_architecture_linter/commit/a74b907325dc74e8102fd5035b422a83ad740c6b))
* Add ModelNamingConventionRule to enforce naming conventions for Models in Clean Architecture ([661ca35](https://github.com/ittae/clean_architecture_linter/commit/661ca35bafc4a871560e144dd1c0fe4069e7f1d3))
* Add ModelNamingConventionRule to enforce naming conventions for Models in Data Layer ([20feb70](https://github.com/ittae/clean_architecture_linter/commit/20feb7027d202dbc820ca7fb00fa696f79ce56ec))
* add naming convention validation utilities for exceptions and failures ([02832d1](https://github.com/ittae/clean_architecture_linter/commit/02832d170c3ba5c2bd31f4b319cd9481fa959bca))
* add new lint rules for ref.mounted usage and riverpod keep alive ([0c2185f](https://github.com/ittae/clean_architecture_linter/commit/0c2185ff59c9df811e48b26b4e86c2c8e2f7dcf1))
* Add PresentationNoThrowRule to enforce no exception throwing in Presentation layer ([44beb0d](https://github.com/ittae/clean_architecture_linter/commit/44beb0dc70263ae9378f8c25972b75cd1c3416f1))
* add ref_mounted_usage and riverpod_keep_alive rules (v1.2.0) ([086aee8](https://github.com/ittae/clean_architecture_linter/commit/086aee839f17dc7e83ceee90a9c3b7c61b10a2ef))
* add release-please pilot for versioned releases ([#89](https://github.com/ittae/clean_architecture_linter/issues/89)) ([968d3f3](https://github.com/ittae/clean_architecture_linter/commit/968d3f34a5ac3fd2ba2a73827a2e44d57d212360))
* Add repository interface and implementation checks in RuleUtils ([f2e02d4](https://github.com/ittae/clean_architecture_linter/commit/f2e02d46c1fd73156db726cb7be70b412e63f024))
* Add RepositoryImplementationRule to enforce repository patterns in data layer ([182b8c6](https://github.com/ittae/clean_architecture_linter/commit/182b8c6f8ad094adb5e68787fa09d89d14e5c636))
* Add Riverpod provider usage and naming validation rules ([323da35](https://github.com/ittae/clean_architecture_linter/commit/323da35fcd3935501609a6b2c7c99e96689af0bb))
* Add Riverpod state management patterns documentation and examples ([4a668a8](https://github.com/ittae/clean_architecture_linter/commit/4a668a8e04689f50aa3641d9352eaad0aa928ff2))
* add rule to enforce no JSON serialization in domain entities and implement corresponding tests ([4b21231](https://github.com/ittae/clean_architecture_linter/commit/4b21231f820b767b7229f557d3940defabbb05ff))
* add setup and entry point documentation for Clean Architecture Linter ([147a6e7](https://github.com/ittae/clean_architecture_linter/commit/147a6e76ff90857df1bc08e858ccc4e5fe0f49dd))
* add test coverage and datasource abstraction rules ([ad55827](https://github.com/ittae/clean_architecture_linter/commit/ad558279bbf6936a626b2bcc5b054fd24db0aa68))
* Add utility usage analysis and validation PRD documentation ([d9f0854](https://github.com/ittae/clean_architecture_linter/commit/d9f08540beeb5d837f1cd8ca4d1e918e5f07181a))
* allow cross-cutting concerns in all layers by adding checks for utility, logging, configuration, and constant imports ([3b3729d](https://github.com/ittae/clean_architecture_linter/commit/3b3729dd523fe72519296d59086d9338472dd04a))
* Allow mutable instance variables for infrastructure SDK types including Google Mobile Ads and In-App Purchase. ([8db1ba4](https://github.com/ittae/clean_architecture_linter/commit/8db1ba48dd4adc903e4052b205761c121370db68))
* analysis_server_plugin + analyzer 13 전환 (v2.0.0-dev.1, ITT-307) ([#61](https://github.com/ittae/clean_architecture_linter/issues/61)) ([ecc1477](https://github.com/ittae/clean_architecture_linter/commit/ecc14776b570679f4d8a2bcfd9a6fc16e0c147cc))
* consolidate entity rules by replacing entity immutability, business rules, and stability rules with a single ConsolidatedEntityRule ([963eedc](https://github.com/ittae/clean_architecture_linter/commit/963eedc987888430ae592db3b3014eee050f1b66))
* enhance abstraction level rule to allow specific Flutter UI imports in presentation layer ([77e187f](https://github.com/ittae/clean_architecture_linter/commit/77e187fb6166790c75ee2e106890826f46752b32))
* enhance abstraction progression and flexible layer detection rules to support additional abstract indicators and improve external package detection ([a55289a](https://github.com/ittae/clean_architecture_linter/commit/a55289a71c20359a490ad360682f48366b8d7127))
* enhance business logic detection by refining checks for UI utility classes and methods ([889f268](https://github.com/ittae/clean_architecture_linter/commit/889f268aa68f9a23b5cffc48740e4415f5f84e85))
* Enhance documentation with Riverpod state management patterns and examples ([f872394](https://github.com/ittae/clean_architecture_linter/commit/f872394aea13aa56a4d0e47b6bf6f2f45dd59128))
* enhance exception validation with additional Data layer exceptions and update tests ([335a29d](https://github.com/ittae/clean_architecture_linter/commit/335a29df81f1ec880c3aa4baeacf4790ed73a42b))
* enhance framework rules to skip test and migration files, allowing for more flexible linting ([34ecc32](https://github.com/ittae/clean_architecture_linter/commit/34ecc321cb8833331bddd1048d99417c32ed270f))
* enhance HTTP operation checks to allow repository interfaces and domain-oriented get methods ([d21978c](https://github.com/ittae/clean_architecture_linter/commit/d21978c032ead5c0b22fdf0de810343bcaf4c794))
* enhance immutability rule to support Freezed and sealed classes ([6165902](https://github.com/ittae/clean_architecture_linter/commit/6165902b9abe44c748ba03cf93e8f529530f280d))
* enhance internal package detection by adding infrastructure package restrictions ([8a5d1d8](https://github.com/ittae/clean_architecture_linter/commit/8a5d1d872208ceb7208fba28d03dc58db667769f))
* enhance layer dependency rule to skip DI/provider files and add checks for simple UI components in state management ([12d1f38](https://github.com/ittae/clean_architecture_linter/commit/12d1f389958e79c5a4204c72bb4e8a9968e8971d))
* Enhance lint rules by integrating ReturnTypeValidationMixin for improved return type checks ([48858bb](https://github.com/ittae/clean_architecture_linter/commit/48858bb463d1603e2ffff05df1f74179b8fd7136))
* enhance lint rules to automatically exclude test files and improve dependency checks ([687c6d3](https://github.com/ittae/clean_architecture_linter/commit/687c6d3c6b0bd1f170f317e7f38ce246fe5df0fb))
* enhance linter by excluding test and generated files from analysis ([1a7a5fb](https://github.com/ittae/clean_architecture_linter/commit/1a7a5fb5c7d805f7aae2066269c2c0e66733f682))
* enhance ModelStructureRule to enforce data model integrity and prevent business logic contamination ([66e88d4](https://github.com/ittae/clean_architecture_linter/commit/66e88d4aa02b3cefdc87883df42be22e85d0ef21))
* Enhance Riverpod provider naming rule to handle casing variations for UseCase types ([02c6e40](https://github.com/ittae/clean_architecture_linter/commit/02c6e402efab478496e43a3ba7b1e2defd0706ed))
* enhance StateManagementRule and UiDependencyInjectionRule to enforce proper state management and dependency injection patterns ([0415b53](https://github.com/ittae/clean_architecture_linter/commit/0415b53800e47a9f8e7132f93b46983a3b3c8b6d))
* implement consolidated entity rule for improved domain entity validation ([6a91a53](https://github.com/ittae/clean_architecture_linter/commit/6a91a530e84733479f6e53593c195e0136fc1684))
* improve lint rules for repository interfaces and state management detection ([47afd87](https://github.com/ittae/clean_architecture_linter/commit/47afd871fdd1d7383899563537a2df53e875364c))
* improve RiverpodGeneratorRule to check for manual provider usage more efficiently ([e6c012b](https://github.com/ittae/clean_architecture_linter/commit/e6c012b2d284d24e8eaea3d5af43f0f328d553a8))
* initial implementation of Clean Architecture Linter for Dart ([feed5d0](https://github.com/ittae/clean_architecture_linter/commit/feed5d02c922c04055ff850c047f479b3faeb8c9))
* Integrate ExceptionValidationMixin into DataSource, ExceptionNaming, and Presentation rules for enhanced exception handling ([61ea2bb](https://github.com/ittae/clean_architecture_linter/commit/61ea2bb3c0d8b87865ac19c67b6aba5b213dc357))
* Introduce RiverpodGeneratorRule for enforcing riverpod_generator usage ([0023eca](https://github.com/ittae/clean_architecture_linter/commit/0023ecad3845feb8db8e716fcb11ef7c87ba939f))
* ITT-48 analyzer 진단 코드 호환성 정리 ([e27b50f](https://github.com/ittae/clean_architecture_linter/commit/e27b50f0e53726165354bc3e931dd117bd1b34b7))
* ITT-837 Riverpod async gap advisory lint 추가 ([#73](https://github.com/ittae/clean_architecture_linter/issues/73)) ([94c419c](https://github.com/ittae/clean_architecture_linter/commit/94c419c3245ed6752682428931518aec0b80dfc2))
* migrate extension_location v2 rule ([#47](https://github.com/ittae/clean_architecture_linter/issues/47)) ([5d16c29](https://github.com/ittae/clean_architecture_linter/commit/5d16c293813f8a5fbb2d2fc0f7e9713a36a67e37))
* migrate freezed_usage v2 rule ([#48](https://github.com/ittae/clean_architecture_linter/issues/48)) ([8dc26b3](https://github.com/ittae/clean_architecture_linter/commit/8dc26b3d721c8a5b89dcbacccc7a07924c282797))
* migrate no_presentation_models v2 rule ([#49](https://github.com/ittae/clean_architecture_linter/issues/49)) ([dbb8733](https://github.com/ittae/clean_architecture_linter/commit/dbb8733982dd579d0b658080043e0cdb19e0444a))
* migrate presentation_no_data_exceptions v2 rule ([#50](https://github.com/ittae/clean_architecture_linter/issues/50)) ([582fe9b](https://github.com/ittae/clean_architecture_linter/commit/582fe9bf56322003fe2cc2e5a9f4ec3e8f6a052e))
* migrate presentation_use_async_value v2 rule ([#51](https://github.com/ittae/clean_architecture_linter/issues/51)) ([2753e9d](https://github.com/ittae/clean_architecture_linter/commit/2753e9d207af6f9df77451157ef71bdef433253c))
* migrate ref_mounted_usage v2 rule ([#52](https://github.com/ittae/clean_architecture_linter/issues/52)) ([35153d8](https://github.com/ittae/clean_architecture_linter/commit/35153d8402ab5e4b7be542b80a0b451f28e94a4f))
* migrate riverpod_generator v2 rule ([#53](https://github.com/ittae/clean_architecture_linter/issues/53)) ([83e8b22](https://github.com/ittae/clean_architecture_linter/commit/83e8b2203a2b5890704560dd2f29c77726d81e29))
* migrate riverpod_keep_alive v2 rule ([#54](https://github.com/ittae/clean_architecture_linter/issues/54)) ([16ad6dd](https://github.com/ittae/clean_architecture_linter/commit/16ad6dddde88d14d0ce48de91c1b996df5bd4c66))
* migrate riverpod_provider_naming v2 rule ([#55](https://github.com/ittae/clean_architecture_linter/issues/55)) ([8c35689](https://github.com/ittae/clean_architecture_linter/commit/8c35689ea759615c75621c6ed9677e6e8cc46c5c))
* migrate riverpod_ref_usage v2 rule ([#56](https://github.com/ittae/clean_architecture_linter/issues/56)) ([0a38b25](https://github.com/ittae/clean_architecture_linter/commit/0a38b257b4e5c8d0ef4cd9e74834c4488cb8a975))
* migrate widget_no_usecase_call v2 rule ([#57](https://github.com/ittae/clean_architecture_linter/issues/57)) ([edec23b](https://github.com/ittae/clean_architecture_linter/commit/edec23b7bc7ba585c14e0ab232410909d4a8f773))
* migrate widget_ref_read_then_when v2 rule ([#58](https://github.com/ittae/clean_architecture_linter/issues/58)) ([85e02cf](https://github.com/ittae/clean_architecture_linter/commit/85e02cf2db782d9155d25fd1a089734596df1eb3))
* pass-through + AsyncValue 정책 P0 규칙 강화 ([8f77d5d](https://github.com/ittae/clean_architecture_linter/commit/8f77d5dfa7cc09f85130a5019ea89f3fd74443c0))
* prepare v1.0.0 for pub.dev release ([fbe5f39](https://github.com/ittae/clean_architecture_linter/commit/fbe5f39b4260fa7c299a56dee809ab4c942d7ed7))
* refactor lint rules to utilize RuleUtils for common checks and reduce code duplication ([cd3a900](https://github.com/ittae/clean_architecture_linter/commit/cd3a900a19a268580955d8fede9a9065fb01ca01))
* refactor models to use sealed classes for better type safety and immutability ([61dd1b7](https://github.com/ittae/clean_architecture_linter/commit/61dd1b7e560fcc0ba0a91e8224f1719fe7260603))
* refine business logic isolation rule to accurately identify repository and utility class calls ([8b7009e](https://github.com/ittae/clean_architecture_linter/commit/8b7009e7b7d5e73111b42e523e5fa7eeb440ad70))
* refine lint rules for Clean Architecture by simplifying boundary crossing and dependency direction checks, and enhancing core dependency validation ([f3f2079](https://github.com/ittae/clean_architecture_linter/commit/f3f2079a249a4fc6a8fd73795eb9a4786f30a962))
* register presentation v2 rules ([#59](https://github.com/ittae/clean_architecture_linter/issues/59)) ([886593b](https://github.com/ittae/clean_architecture_linter/commit/886593bdfe4afe8fff200ee8b5922fb9fe8be10c))
* remove EntityNoJsonSerializationRule and its tests to streamline domain entity validation ([f2e5dcd](https://github.com/ittae/clean_architecture_linter/commit/f2e5dcdf179ea18c9786047175ff819e1d421423))
* streamline RankingModel and enhance metadata handling in Clean Architecture guide ([dfd46cc](https://github.com/ittae/clean_architecture_linter/commit/dfd46cc186ca92060e0ef922a71a74ab1a9e6695))
* Update ModelConversionMethodsRule to enforce toEntity() method presence in Model extensions ([86b7275](https://github.com/ittae/clean_architecture_linter/commit/86b727579dd1a11299b5173da6768dccc60215e3))
* update test coverage rules for Clean Architecture compliance ([0e93d2f](https://github.com/ittae/clean_architecture_linter/commit/0e93d2f395f21836149a365114fa11f0a9faa019))


### Bug Fixes

* 2.1.1 릴리즈 소스 동기화 ([c926c7d](https://github.com/ittae/clean_architecture_linter/commit/c926c7d85ddd4cd6c0fff52a14bf219795b00a61))
* Add test coverage files to .gitignore ([de776f1](https://github.com/ittae/clean_architecture_linter/commit/de776f10423c149560faaef7a2afd36bf866060c))
* Align publish workflow with CI configuration ([6cfb903](https://github.com/ittae/clean_architecture_linter/commit/6cfb903de120be15546121f87926848b1859efc8))
* analyzer 최신 deprecation 대응으로 flutter analyze 174건 해결 ([50b228b](https://github.com/ittae/clean_architecture_linter/commit/50b228bf5ecb7a71cf350e6b0c16b256c8739e8e))
* AsyncValue.guard 내부 throw는 presentation_no_throw 예외 처리 ([af6e65f](https://github.com/ittae/clean_architecture_linter/commit/af6e65f829d8bb8d83941491c5dda8f6266f4e32))
* avoid model field duplication false positives for structural types ([#68](https://github.com/ittae/clean_architecture_linter/issues/68)) ([3f5b7d5](https://github.com/ittae/clean_architecture_linter/commit/3f5b7d5e22d238ab86996d75d30cdabe97e80619))
* avoid unrelated circular dependency reports ([#63](https://github.com/ittae/clean_architecture_linter/issues/63)) ([6aa7683](https://github.com/ittae/clean_architecture_linter/commit/6aa768348548cc923cdfc92f2f806f41f34d995d))
* cap asp &lt;0.3.15 / analyzer &lt;13 to avoid plugin-host hang (2.0.1) ([#71](https://github.com/ittae/clean_architecture_linter/issues/71)) ([99a1c5d](https://github.com/ittae/clean_architecture_linter/commit/99a1c5dda136d4b264c12e626f6df54140b6b2ab))
* correct path for running example project in CI workflow ([865b58d](https://github.com/ittae/clean_architecture_linter/commit/865b58dd3f575559449e61961e1e6433c16c8522))
* correct release date from 2025-01-30 to 2025-10-30 ([ac4241f](https://github.com/ittae/clean_architecture_linter/commit/ac4241f07710aa34c703cc01fa48ebc9ff599451))
* detect nested repository model types ([#65](https://github.com/ittae/clean_architecture_linter/issues/65)) ([390acb7](https://github.com/ittae/clean_architecture_linter/commit/390acb70fc40c209c7293b778cf6f2d8b1fec10d))
* Downgrade analyzer dependency version to ^7.3.0 for compatibility; update test dependency version to ^1.25.8 ([9e545a6](https://github.com/ittae/clean_architecture_linter/commit/9e545a650c0bb6119401fb0be0ff468ddfb9544f))
* Downgrade lints dependency version to ^4.0.0 for compatibility ([f0502e0](https://github.com/ittae/clean_architecture_linter/commit/f0502e080ac74f5e8db402c04ed199baeb4fd460))
* Downgrade test dependency version to ^1.25.7 for compatibility ([e92e2b2](https://github.com/ittae/clean_architecture_linter/commit/e92e2b2e808f69a8d892809e6157ab0a8bf6a207))
* harden ITT-165 analyzer lint bridge ([#9](https://github.com/ittae/clean_architecture_linter/issues/9)) ([a3c8b3f](https://github.com/ittae/clean_architecture_linter/commit/a3c8b3fa029ea7d06e6b2dd6f6706b2932bb5d9f))
* harden model field entity type detection ([#66](https://github.com/ittae/clean_architecture_linter/issues/66)) ([fd17461](https://github.com/ittae/clean_architecture_linter/commit/fd17461001a1cd5e3dbcba831e922a448b3dd605))
* harden presentation lint rule edge cases ([#67](https://github.com/ittae/clean_architecture_linter/issues/67)) ([30d9e1a](https://github.com/ittae/clean_architecture_linter/commit/30d9e1ad38451e4295e7c1039debebf14b166871))
* harden repository_pass_through analysis ([#62](https://github.com/ittae/clean_architecture_linter/issues/62)) ([0b03122](https://github.com/ittae/clean_architecture_linter/commit/0b03122c94bb6d53bbdfb60512b7d5169a261ce9))
* Improve DataSource abstraction checks by validating interface implementation and abstract status ([06a31c5](https://github.com/ittae/clean_architecture_linter/commit/06a31c5ed255f8462d4f8f11546b69fb5e021497))
* Improve formatting and readability of problem messages in lint rules ([d564a53](https://github.com/ittae/clean_architecture_linter/commit/d564a53ff9ab12b4ced88d65b3fb0ac17d44dcfd))
* ITT-1266 Future continuation callback ref 접근 진단 ([#79](https://github.com/ittae/clean_architecture_linter/issues/79)) ([96de2c6](https://github.com/ittae/clean_architecture_linter/commit/96de2c6f7244ace2ca2c27ce8d93f773ac5daa0b))
* ITT-338 clean linter ASP diagnostics ([#64](https://github.com/ittae/clean_architecture_linter/issues/64)) ([3ffbaa9](https://github.com/ittae/clean_architecture_linter/commit/3ffbaa9fa576338a42788b640ff39d4571947d83))
* ITT-837 async gap 규칙 제어흐름 false positive 제거 ([bb94e86](https://github.com/ittae/clean_architecture_linter/commit/bb94e869741c0c93415a3642894f8ee0bc60716d))
* light 리뷰 caller issues:write 승격 (reusable harden [#30](https://github.com/ittae/clean_architecture_linter/issues/30) 이후 startup_failure 복구) ([#82](https://github.com/ittae/clean_architecture_linter/issues/82)) ([649c984](https://github.com/ittae/clean_architecture_linter/commit/649c98409d6a8b875878b267d0a560e64e72043d))
* move analyzer, custom_lint_builder, path to dependencies ([831e5cb](https://github.com/ittae/clean_architecture_linter/commit/831e5cb431b235f1f985ee985d4c263e34deabbc))
* resolve CI workflow issues ([3880754](https://github.com/ittae/clean_architecture_linter/commit/3880754938dbc0570f0a79f4c74844d63de06266))
* resolve datasource test path fallback ([#69](https://github.com/ittae/clean_architecture_linter/issues/69)) ([598de5b](https://github.com/ittae/clean_architecture_linter/commit/598de5be1a99bff3d80bfa94cb781c509edca9a5))
* resolve regex pattern errors in lint rules ([32afec3](https://github.com/ittae/clean_architecture_linter/commit/32afec3e913aecf5724ed84551b6d4859c435271))
* restore cross-layer v2 parity ([#24](https://github.com/ittae/clean_architecture_linter/issues/24)) ([2181305](https://github.com/ittae/clean_architecture_linter/commit/2181305d79e99a0890e5db7d1b8f816bfe5238e8))
* Skip core directory in exception naming convention rule ([422782b](https://github.com/ittae/clean_architecture_linter/commit/422782b8403061165d234bc9873052bdaa00a45e))
* update CI workflow to handle example structure and SDK compatibility ([e71c043](https://github.com/ittae/clean_architecture_linter/commit/e71c043dfae063cee759efe24fd5f35522dea73c))
* Update CI workflow to install dependencies without recursion and add .pubignore for example directory ([58ac322](https://github.com/ittae/clean_architecture_linter/commit/58ac3225c7fdbf8a87664ee04df0d250e0ff8748))
* update CI workflow to use Flutter SDK and improve example project testing ([d0a6690](https://github.com/ittae/clean_architecture_linter/commit/d0a66902f8b0dcc72531dd893c9423f69a9608f3))
* update custom_lint dependency version and remove outdated setup documentation ([c949b79](https://github.com/ittae/clean_architecture_linter/commit/c949b793fe57415cbd978b69833988ffacb26f4b))
* Update Dart SDK requirement to ^3.6.0; upgrade analyzer to ^7.6.0 and test dependency to ^1.26.3; modify path dependency to ^1.9.1; update custom_lint version to ^0.7.6 ([c967f67](https://github.com/ittae/clean_architecture_linter/commit/c967f67fda407fd5cf1bc1a9020e41ec4b1008ef))
* Update data file detection to exclude domain repositories ([d3305b3](https://github.com/ittae/clean_architecture_linter/commit/d3305b3b0d17897b6923afdaf8acef126ba8a81f))
* Update failure naming convention rule to skip core directory ([82130cc](https://github.com/ittae/clean_architecture_linter/commit/82130cc5ffc7d8f7ec2d051d23b9c2f92911c613))
* Update formatting command to specify line length in documentation ([8b8f41f](https://github.com/ittae/clean_architecture_linter/commit/8b8f41fa13f632672cf5525f838c59d90aa3ea13))
* Update path dependency version to ^1.9.0 for compatibility; modify analyzer command to use fatal-warnings ([f72b655](https://github.com/ittae/clean_architecture_linter/commit/f72b655635f677d5b12ed572fdeea534049ddb43))
* Update validation checks and improve lint rules for domain layer consistency ([cd86c3a](https://github.com/ittae/clean_architecture_linter/commit/cd86c3a4f8134972c603b896f7185471d9139b90))


### Code Refactoring

* Remove entity_business_logic rule (v1.0.2) ([743d708](https://github.com/ittae/clean_architecture_linter/commit/743d7086fd670a88fdd9ef2aa537aa54c3bec3b7))

## [Unreleased]

## [2.1.1] - 2026-06-25

### Fixed

- `riverpod_ref_after_async_gap`: removed control-flow false positives. The previous implementation collected every `await` in a function body into a flat offset list and flagged any tracked `ref` call positioned after it, which incorrectly reported `ref` usage in mutually exclusive sibling branches (an `else` branch flagged because of an `await` in the `if` branch, or a `switch` case flagged because of an `await` in another case). Detection now walks the ref call's ancestor blocks and only counts `await`s that sequentially precede it on its own execution path; `await`s in a `try` body are still counted for `ref` usage in the matching `catch`/`finally`, and nested function bodies are treated as separate scopes.

## [2.1.0] - 2026-06-24

### Added

- `riverpod_ref_after_async_gap`: advisory INFO lint for `ref.read`, `ref.watch`, `ref.listen`, `ref.invalidate`, and `ref.refresh` after `await` in public Riverpod provider/notifier methods and async callbacks. The first version is intentionally narrow to reduce false positives: it only scans `lib/**/presentation/**/providers/**`, skips generated/test files and private helpers, and does not report `state = ...` after `await`.
- Package-named public library entrypoint `lib/clean_architecture_linter.dart` exporting `CleanArchitectureUtils`, so the package keeps a conventional importable library alongside the analyzer plugin `lib/main.dart` entrypoint.

## [2.0.1] - 2026-06-06

### Fixed

- **Consumer CI hang (`flutter analyze` never returns).** Capped `analysis_server_plugin` to `>=0.3.4 <0.3.15` and `analyzer` to `>=9.0.0 <13.0.0`. Root-caused via a controlled experiment: a consumer resolving the plugin against **asp 0.3.16 / analyzer 13.1** intermittently **hangs during plugin-isolate load/analysis** (shard never completes, 20 min+), while the same code on **asp 0.3.14 / analyzer 12.1** completes in ~5 min. The hang is in the upstream asp/analyzer-13.x plugin host, not in this package's rules (all rule visitors are loop-safe; a larger consumer on 12.1 passes). Consumers that also use `riverpod_lint` were already unaffected (it caps them at asp 0.3.14/analyzer 12.1). Consumers on `^2.0.0` pick this up automatically. The analyzer-13 range will be restored once the upstream host issue is resolved.

## [2.0.0] - 2026-06-05

> **Stable v2.0 release.** First stable release on the official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin), validated against consumer projects (`ittae`, `flutter_boilerplate`) which fully migrated off `custom_lint`. See [2.0.0-dev.1] below for the full breaking-change list.

### Added

- **analyzer 9–13 compatibility.** Widened the analyzer constraint to `>=9.0.0 <14.0.0` and introduced a runtime AST compatibility layer (`analyzer_ast_compat`) bridging renamed analyzer APIs (formal parameter / named argument / class & extension members). This lets the plugin load across analyzer 9–13 and **coexist with other analysis_server_plugin plugins such as `riverpod_lint`** in a single consumer (ITT-338).

### Fixed (since `2.0.0-dev.1`)

- `repository_pass_through`: false report on non-`Future` `Result` returns and over-flagging of nested try-catch blocks (ITT-301).
- `circular_dependency`: false positive reporting cycles that do not contain the analyzed file (ITT-290).
- `repository_interface`: now detects data-layer models exposed inside nested generics (e.g. `Future<Result<UserModel>>`, `Future<List<UserModel>>`) via recursive type-argument inspection (ITT-291).
- `model_field_duplication`: replaced `startsWith`-based primitive detection with exact base-type matching (fixes false negatives for `Settings`/`Interval`/`MapLocation`/`Boolean`), added missing SDK types (`num`/`Object`/`dynamic`/`Iterable`), and stopped flagging record / function / structural-typed fields (ITT-295, ITT-380).
- `datasource_abstraction`: correct `lib/`→`test/` resolution for relative paths so a present test file is no longer missed (ITT-296).
- presentation rules: detect `try { } on X catch` data-exception handling (`CatchClause`), narrow over-broad `state = AsyncValue` matching, de-duplicate `!ref.mounted` reports, and fix the `extension_location` correction message (ITT-304).

## [2.0.0-dev.1] - 2026-05-31

> **v2.0 first dev release (analysis_server_plugin migration).** Pre-release; the stable `2.0.0` follows once the v2 contract is validated against consumer projects.

### 💥 Breaking Changes

- **Migrated from `custom_lint` to the official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin)**, following the archival of upstream [invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) and the original author's migration recommendation.
- **`analysis_options.yaml` format change**: lint activation moves from `analyzer: plugins: - custom_lint` to the top-level `plugins: clean_architecture_linter: <version>` map. The `analyzer: exclude:` block is unchanged.
- **`custom_lint` dependency removed**: consumers no longer add `custom_lint` as a dev_dependency, and the analyzer 9 / Riverpod 3+ `pubspec_overrides.yaml` workaround is no longer required.
- **CLI change**: lint runs via `dart analyze` / `flutter analyze` instead of `dart run custom_lint`.
- **Minimum Dart SDK raised to `^3.10.0`** (`analysis_server_plugin` requires Dart 3.10+).
- **Dependencies pinned to `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`** so the plugin loads in-process under the analyzer shipped with current Dart/Flutter SDKs (Dart 3.12 / analyzer 13).

### 🔧 Changed

- All **33 rules** are registered in the v2 `analysis_server_plugin` plugin entrypoint (`lib/main.dart`) as default-enabled rules; per-rule severity is preserved from v1 (most WARNING, 7 INFO). Rule names and diagnostic messages remain equivalent to v1.
- Migrated all rule + helper AST traversal to the **analyzer 13 AST API** (`ClassDeclaration.namePart.typeName` / `ClassBody.members`, `RegularFormalParameter`, `NamedArgument`). Detection logic, messages, and severities are unchanged — only the AST accessors were updated.

### 🗑️ Removed

- Removed the v1 `custom_lint` entrypoint (`lib/clean_architecture_linter.dart`), all 34 `*_custom_lint_rule.dart` implementations, the `CleanArchitectureLintRule extends DartLintRule` base class, and the corresponding v1 tests. `CleanArchitectureUtils`, the shared mixins, the v2 rules, and the v2 test harness are retained.

### 📖 Docs

- Added [MIGRATION.md](MIGRATION.md) — v1 → v2.0 consumer migration guide (change table, step-by-step procedure, known differences).
- Flipped `README.md` / `README_KO.md` install guides to the v2 `plugins:` + `dart analyze` workflow and removed the v1 analyzer-9 compatibility workaround section.

## [1.3.2] - 2026-05-29

### 🔧 Changed

- Widened the direct `analyzer` constraint to `>=8.4.0 <10.0.0` so consumers on the analyzer 9 line (freezed 3.x, riverpod_generator 4.x, riverpod_lint 3.1.x) no longer need to override `clean_architecture_linter` itself in `pubspec_overrides.yaml`.
- Hardened the `DiagnosticReporter` compatibility layer with a typed `LintCode` bridge, severity-name mapping, and cached analyzer lint codes.

### 📖 Docs

- Added **Compatibility — analyzer 9 / Riverpod 3+** sections to `README.md` and `README_KO.md` covering: the archived `invertase/dart_custom_lint` upstream, a verified `pubspec_overrides.yaml` workaround for `custom_lint*`, a CI gitignore caveat for Flutter projects, and cleanup checkpoints leading up to v2.0 (analysis_server_plugin migration).

### 🧪 Tests

- Added unit coverage for analyzer lint code bridging, including metadata preservation, default severity handling, and cache reuse.

## [1.3.1] - 2026-05-05

### 🛠 Maintenance

- D 방향 reusable 워크플로우 적용 (Claude Code Review + mention responder)
- `karpathy-guidelines` 스킬 준수 줄을 CLAUDE.md에 추가
- `dart format` 미적용 파일 정리 (CI 통과 위함)

코드 로직 변경 없음 — 의존성/콘텐츠 안정. 1.3.0과 동등하게 사용 가능.

## [1.3.0] - 2026-02-15

### ✨ Added

- **P0 error-handling policy tightening** for pass-through + AsyncValue architecture
  - `repository_pass_through`: detects unnecessary `try-catch` rewrapping in Repository public methods
  - `usecase_no_result_return`: stronger Result/Either detection including typedef alias cases
  - `presentation_use_async_value` / `presentation_no_throw`: stronger detection for swallowed exceptions and direct business exception branching in presentation
- **Lint profiles**
  - `docs/config/lint_profile_balanced.yaml`
  - `docs/config/lint_profile_strict.yaml`

### 🔧 Changed

- Analyzer compatibility updates (DiagnosticReporter/DiagnosticSeverity/name/diagnosticCode)
- Documentation/messages aligned to **pass-through + AsyncValue** policy (removed stale Result-centric guidance)

### 🧪 Tests

- Added real AST-based tests for typedef alias Result detection in `return_type_validation_mixin_test.dart`
- `flutter analyze` and `dart test` pass

## [1.2.0] - 2026-01-19

### ✨ Added (2 new rules)

- **ref_mounted_usage** - Detects `ref.mounted` usage in Riverpod providers
  - Using `ref.mounted` to guard async operations masks design problems
  - Encourages proper patterns: AsyncValue, ref.listen, or completing async work before navigation
  - Only checks in `/presentation/` and `/providers/` directories
  - Severity: WARNING

- **riverpod_keep_alive** - Warns against unnecessary `@Riverpod(keepAlive: true)`
  - `keepAlive: true` should only be used for truly global state (auth, settings, cache)
  - Warns when used on feature-specific providers (e.g., TodoListNotifier)
  - Skips infrastructure providers (DataSource, Repository, UseCase, Service, Client, API)
  - Valid patterns: auth, user, session, settings, preferences, config, theme, locale, cache, analytics, notification, connectivity, permission
  - Severity: WARNING

### 📊 Statistics

- **Total rules: 33** (was 31 in v1.1.0)
  - Presentation layer rules: 13 (was 11)

## [1.1.0] - 2026-01-09

### 🚀 Breaking Changes

- **Pass-through Repository Pattern** - Result 패턴 제거, pass-through 패턴으로 전환
  - Repository는 이제 `Future<Entity>`를 직접 반환 (권장)
  - `Future<Result<Entity, Failure>>` 사용 시 경고 표시
  - 에러는 DataSource에서 발생하여 Presentation까지 pass-through
  - `AsyncValue.guard()`로 에러 자동 캐치

### ✨ Added

- **AppException 타입 인식** - `exception_validation_mixin`에 AppException 타입 세트 추가
  - 표준 AppException 타입: `AppException`, `NetworkException`, `TimeoutException`, `ServerException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InvalidInputException`, `ConflictException`, `CacheException`, `UnknownException`
  - `isAppExceptionType()` 메서드 추가
  - `isAllowedWithoutPrefix()`가 AppException 타입 인식

- **Loading 필드 감지** - `presentation_use_async_value` 규칙 강화
  - `isLoading`, `loading`, `isSubmitting`, `submitting`, `isFetching`, `fetching`, `isProcessing`, `processing` 필드 감지
  - Freezed State에서 수동 로딩 상태 관리 금지 (AsyncValue가 자동 관리)

### 🔄 Changed

- **repository_must_return_result** - Result 패턴 사용 시 경고
  - 이전: `Future<Entity>` 또는 `Future<Result<Entity, Failure>>` 모두 허용
  - 이후: `Future<Entity>` 권장, Result 사용 시 WARNING

- **repository_must_return_result** → **repository_pass_through** (이름 변경)
  - 규칙 이름이 pass-through 패턴을 더 명확하게 반영

- **repository_no_throw** - 문서 업데이트
  - Pass-through 패턴 중심으로 문서 재작성
  - AppException 타입 throw 허용
  - 비표준 예외 throw 시 INFO 레벨 경고

- **datasource_exception_types** - AppException 타입 체크 추가
  - `isAppExceptionType()` 체크 추가
  - DataSource에서 AppException 타입만 throw 허용

### ⚠️ Deprecated

- **usecase_must_convert_failure** - Pass-through 패턴으로 인해 더 이상 필요 없음
  - UseCase에서 Failure→Exception 변환 불필요
  - 에러가 DataSource에서 Presentation까지 직접 전달됨
  - 규칙은 유지되지만 no-op (아무 동작 안함)

- **failure_naming_convention** - Failure 클래스 사용 자체를 경고
  - Result 패턴 제거로 Failure 클래스 불필요
  - 규칙이 Failure 클래스 정의 시 경고 표시
  - AppException 사용 권장

### 📝 Documentation

- **CLAUDE.md** - Pass-through 패턴 중심으로 업데이트
  - Result 패턴 예제 제거
  - STATE_MANAGEMENT_GUIDE.md 참조 추가

- **doc/UNIFIED_ERROR_GUIDE.md** - 통합 에러 핸들링 가이드 추가
- **doc/STATE_MANAGEMENT_GUIDE.md** - 상태 관리 가이드 추가

### 🧪 Tests

- 모든 테스트 업데이트 (568개 테스트 통과)
  - `exception_validation_mixin_test.dart` - AppException 타입 테스트 추가
  - `repository_no_throw_rule_test.dart` - Pass-through 패턴 테스트로 변경
  - `exception_handling_integration_test.dart` - 전체 리팩토링

## [1.0.11] - 2025-12-31

### 🔧 Fixed

- **layer_dependency_rule** - DI Provider 파일에서 Data Models import 금지 추가
  - DI/Provider 파일(`*_providers.dart`, `providers.dart`)에서 DataSource/Repository 구현체 import는 허용
  - 하지만 **Data Models(`/data/models/`)** import는 DI 파일에서도 **금지**
  - Data Models는 Data 레이어 내부용이며, Presentation 레이어(DI 포함)에서 사용하면 안됨
  - 새로운 `_isDataModelImport()` 헬퍼 메서드 추가

## [1.0.10] - 2025-12-10

### ✨ Added

- **allowed_instance_variables_rule** - Extended infrastructure SDK type support
  - Google Mobile Ads SDK: `BannerAd`, `InterstitialAd`, `RewardedAd`, `NativeAd`, `AppOpenAd`, `AdWidget`
  - In-App Purchase SDK: `InAppPurchase`, `ProductDetails`, `PurchaseDetails`
  - `Subscription` type (StreamSubscription, etc.)
  - These SDK types require mutable state for lifecycle management

### 🎨 Improved

- **Correction messages** - Made all rule correction messages more concise for better VS Code PROBLEMS panel display
  - Removed verbose examples from correction messages
  - Focused on brief, actionable fix instructions
  - Affected rules: `failure_naming_convention`, `model_naming_convention`, `exception_message_localization`, `presentation_no_data_exceptions`, `presentation_use_async_value`, `riverpod_provider_naming`, `riverpod_ref_usage`, `widget_no_usecase_call`, `widget_ref_read_then_when`

## [1.0.9] - 2025-11-12

### ✨ Added (1 new rule)

- **allowed_instance_variables_rule** - Enforce stateless architecture in UseCase, Repository, and DataSource classes
  - **UseCase**: Only `final`/`const` Repository and Service dependencies allowed
  - **Repository**: Only `final`/`const` DataSource and infrastructure dependencies (primitives, Stream, HTTP, Firebase, Database) allowed
  - **DataSource**: Only `final`/`const` primitives and infrastructure dependencies allowed
  - Mock/Fake classes can have mutable state for testing purposes
  - Prevents hidden state bugs and enables testability
  - Comprehensive validation with clear error messages
  - Total rules: **34** (was 33)
  - Cross-layer rules: 3 (was 2)

### 🔧 Fixed

- **Domain Layer dart:io Support** - Fixed false positive for `dart:io` imports in domain layer
  - `domain_purity_rule`: Now allows `dart:io` imports for type references (File, Directory) in domain layer method signatures
  - Actual I/O operations should still be implemented in data layer
  - Addresses legitimate use cases where domain repositories need File type parameters

- **Database Library Support** - Added proper exceptions for database libraries (ObjectBox, Realm, Isar, Drift)
  - `layer_dependency_rule`: Data layer can now import `package:objectbox/`, `package:realm/`, `package:isar/`, `package:drift/`
  - `datasource_abstraction_rule`:
    - Private methods/getters (starting with `_`) are now skipped from validation
    - Database entity types (Box<*Entity>, *ObjectBoxEntity, *RealmEntity, etc.) are allowed in return types
  - `model_structure_rule`: Models with database annotations (@Entity, @RealmModel, @collection, etc.) are exempt from @freezed requirement
  - These libraries require mutable classes with their own code generation, incompatible with Freezed

### 📝 Documentation

- **CLAUDE.md**
  - Added "Instance Variables & Stateless Architecture" section with comprehensive examples
  - Added "Domain Layer with dart:io Types" example showing allowed usage of File type in repository signatures
  - Updated Layer Dependencies section to clarify dart:io is allowed for type references
  - Documented allowed infrastructure types for each layer
  - Explained Mock/Fake exception for testing
  - Added "Database Library Exceptions" section with comprehensive examples
  - Explained why database Models don't use @freezed (mutability requirement)
  - Listed all allowed database imports and annotations

- **README.md**
  - Updated rule count from 33 to 34
  - Added allowed_instance_variables_rule to Core Clean Architecture Principles section
  - Added ObjectBox example in "Good Examples" section
  - Documented database library exceptions with clear note

- **README_KO.md**
  - Updated rule count from 29 to 34
  - Synchronized with English README structure

### 🎨 Improved

- **exception_naming_convention_rule** - More concise error messages for better VS Code PROBLEMS panel display

## [1.0.8] - 2025-10-30

### 🔧 Changed

- **Minimum Dart SDK updated to 3.7.0**
  - Updated from ^3.6.0 to ^3.7.0 for better compatibility
  - Downgraded lints from ^6.0.0 to ^5.1.1 for Dart 3.7.0 compatibility
  - All existing features and tests remain compatible
  - No breaking changes to API or functionality

## [1.0.6] - 2025-10-28

### 🔧 Fixed

- **Fixed package dependencies structure**
  - Moved `analyzer`, `custom_lint_builder`, and `path` back to `dependencies`
  - These packages are used in `lib/` code and must be runtime dependencies
  - `custom_lint`, `lints`, and `test` remain in `dev_dependencies`
  - Note: End users still add this package to `dev_dependencies` in their projects

### 📦 Dependencies

- Runtime dependencies (used in lib/): `analyzer`, `custom_lint_builder`, `path`
- Dev dependencies (development only): `custom_lint`, `lints`, `test`

## [1.0.5] - 2025-10-28

### 🔧 Changed

- **Upgraded custom_lint_builder** from `0.7.6` to `0.8.0`
  - Ensures compatibility with riverpod_generator 3.0.0
  - Upgraded custom_lint dev dependency to `0.8.0`
  - All 527 tests pass successfully
  - No breaking API changes required
  - Maintains backward compatibility

### 📦 Dependencies

- `custom_lint_builder`: ^0.7.6 → ^0.8.0
- `custom_lint`: ^0.7.6 → ^0.8.0 (dev dependency)

## [1.0.4] - 2025-10-22

### ✨ Added (2 new rules)

- **widget_no_usecase_call rule** - Enforce proper Riverpod architecture: Widget → Provider → UseCase
  - Prevents widgets from directly importing or calling UseCases
  - Enforces proper separation: Widgets should only interact with Providers
  - Detects UseCase imports in widget/page files
  - Detects direct UseCase provider calls via `ref.read()` or `ref.watch()`
  - Provides comprehensive correction messages with proper Riverpod patterns
  - Severity: WARNING

- **widget_ref_read_then_when rule** - Prevent anti-pattern of using `.when()` after `ref.read()`
  - Detects `ref.read()` followed by `.when()` in the same function
  - Enforces proper patterns: `ref.watch()` + `.when()` for UI, `ref.listen()` for side effects
  - Prevents misuse of AsyncValue state management
  - Explains why this pattern is incorrect (state is already settled after operation)
  - Provides three correct alternatives based on use case
  - Severity: WARNING

### 🔄 Changed

- **presentation_no_throw rule** - Enhanced detection capabilities
  - Now checks `/providers/` directory in addition to `/states/` and `/state/`
  - Improved State/Notifier class detection with three methods:
    1. Detects `@riverpod` annotation (Riverpod Generator pattern)
    2. Detects `extends AsyncNotifier/Notifier/StateNotifier/ChangeNotifier`
    3. Detects generated classes with `_$` prefix
  - More robust validation of Riverpod-based state management classes
  - Better coverage of modern Riverpod code generation patterns

- **Total rules: 31** (was 29 in v1.0.3)
  - Added: 2 new presentation layer rules
  - Modified: 1 rule (presentation_no_throw)

### 📝 Documentation

- Enhanced CLAUDE.md with comprehensive Riverpod state management patterns
  - Added 3-tier provider architecture documentation
  - Documented Entity Providers (AsyncNotifier), UI State Providers (Notifier), and Computed Logic Providers
  - Added detailed examples of AsyncValue.when() pattern usage
  - Included common violations and their solutions
  - Comprehensive Widget usage examples with proper error handling

### 📊 Statistics

- **Files changed**: 5 files
  - 2 new rule implementations
  - 1 rule enhancement
  - 1 test file
  - 1 main registration file
- **Lines added**: ~600+ lines
  - widget_no_usecase_call_rule.dart: 265 lines
  - widget_ref_read_then_when_rule.dart: 301 lines
  - Enhanced presentation_no_throw_rule.dart
- **Test coverage**: Comprehensive unit tests for widget_no_usecase_call rule

## [1.0.3] - 2025-10-17

### ✨ Added (3 new rules)

- **model_entity_direct_access rule** - Enforce `.toEntity()` method usage instead of direct `.entity` property access in Data layer
  - Prevents direct `.entity` access in Repository and DataSource implementations
  - Allows direct access inside extension methods (where conversion logic is implemented)
  - Allows direct access in test files
  - Provides clear architectural boundaries for Model → Entity conversion

- **model_naming_convention rule** - Enforce naming conventions for Models in Data layer
  - Models must end with `Model` suffix
  - Validates proper naming in `data/models/` directories
  - Helps maintain consistent codebase structure

- **presentation_no_throw rule** - Enforce no exception throwing in Presentation layer
  - Presentation layer should use AsyncValue for error handling
  - No direct exception throws in widgets, states, or notifiers
  - Aligns with Riverpod best practices

### 🔄 Changed

- **model_conversion_methods rule** - Updated to align with Dart/Freezed best practices
  - Now only requires `toEntity()` method in extensions (mandatory)
  - `fromEntity()` implementation is optional and should use factory constructors in the Model class
  - Removed extension static method pattern (not idiomatic in Dart)
  - Updated error messages to guide users toward factory constructor pattern

- **Total rules: 29** (was 26 in v1.0.2)
  - Added: 3 new rules
  - Modified: 1 rule (model_conversion_methods)

### 🐛 Bug Fixes

- Fixed `exception_naming_convention` rule to skip `core/` directory (framework-level exceptions)
- Fixed `failure_naming_convention` rule to skip `core/` directory
- Fixed data file detection to correctly exclude `domain/repositories/` from data layer
- Fixed `model_conversion_methods` rule incorrectly requiring extension static methods
- Improved error severity levels across multiple rules

### 📝 Documentation

- Updated CLAUDE.md with comprehensive `.entity` access control guidelines
- Updated Data Layer rules README with all 3 new rules documentation
- Enhanced Model conversion pattern examples with factory constructor approach
- Added 48 new lines of documentation in CLAUDE.md
- Added 55 new lines in Data Layer README
- Updated README.md with accurate rule count

### 📊 Statistics

- **Files changed**: 23 files
- **Lines added**: ~1,237 lines
- **New test coverage**: 398+ lines of new tests for new rules
- **Documentation improvements**: 100+ lines across multiple files

## [1.0.2] - 2025-10-09

### 🗑️ Removed

- **entity_business_logic rule** - Removed overly strict rule requiring all entities to have business logic methods
  - Not all entities need business logic (e.g., events, DTOs, value objects)
  - Users reported this as too restrictive for practical use cases
  - Total rules: 27 → 26

### 📝 Documentation

- Fixed incomplete code snippet in README.md examples section
- Synchronized README_KO.md structure with README.md (removed inconsistent sections)
- Updated rule count from 27 to 26 in both English and Korean READMEs

## [1.0.1] - 2025-10-09

### 📝 Documentation

- Updated README.md with accurate rule count (27 rules instead of 16+)
- Updated README_KO.md with accurate rule count and simplified structure
- Simplified configuration section, removed non-existent Core/Strict modes
- Reorganized rules documentation with clear categorization
- Removed unnecessary documentation files (VALIDATION_REPORT.md, ERROR_HANDLING_RULES_TODO.md)

### 🔧 CI/CD

- Improved publish workflow to use official OIDC-based authentication
- Added quality checks (tests, analyzer, format) before publishing
- Aligned publish workflow with CI workflow for consistency

## [1.0.0] - 2025-10-09

### 🎉 Initial Release

A comprehensive custom lint package that automatically enforces Clean Architecture principles in Flutter/Dart projects.

### ✨ Added

#### New Utility Infrastructure
- **CleanArchitectureUtils** - Centralized utility class for common Clean Architecture validations
  - File path detection (isDomainFile, isDataFile, isPresentationFile)
  - Component detection (isUseCaseFile, isDataSourceFile, isRepositoryFile)
  - Class name validation (isUseCaseClass, isDataSourceClass, isRepositoryClass)
  - Type checking (isVoidType, isResultType)
  - Exception pattern recognition (isDataException, isDomainException)
  - AST utilities (findParentClass, isPrivateMethod, isRethrow)
  - Feature extraction (extractFeatureName)

#### New Mixin System
- **ExceptionValidationMixin** - Exception naming and validation logic
- **ReturnTypeValidationMixin** - Return type validation for methods
- **RepositoryRuleVisitor** - Repository-specific validation

### 🔄 Changed

#### Code Organization
- **170 lines removed** (13.6% code reduction) through deduplication
- Consolidated 13 rules to use shared mixins and utilities
- Improved consistency across all validation logic
- Enhanced test coverage with **76 comprehensive tests**

#### Refactored All 24 Rules
All lint rules were refactored to leverage the new utility and mixin infrastructure:

**Cross-Layer Rules (4)**
- LayerDependencyRule
- CircularDependencyRule
- BoundaryCrossingRule
- TestCoverageRule

**Domain Layer Rules (4)**
- DomainPurityRule
- DependencyInversionRule
- RepositoryInterfaceRule
- UseCaseNoResultReturnRule
- UseCaseMustConvertFailureRule
- ExceptionNamingConventionRule
- ExceptionMessageLocalizationRule

**Data Layer Rules (7)**
- ModelStructureRule
- DataSourceAbstractionRule
- DataSourceNoResultReturnRule
- RepositoryMustReturnResultRule
- RepositoryNoThrowRule
- DataSourceExceptionTypesRule
- FailureNamingConventionRule

**Presentation Layer Rules (6)**
- NoPresentationModelsRule
- ExtensionLocationRule
- FreezedUsageRule
- RiverpodGeneratorRule
- PresentationNoDataExceptionsRule
- PresentationUseAsyncValueRule

### 📈 Improved

#### Documentation
- Added comprehensive ARCHITECTURE.md with system overview
- Created CONTRIBUTING.md with development guidelines
- Added RULE_DEVELOPMENT_GUIDE.md for contributors
- Enhanced inline documentation across all files

#### Testing
- **76 comprehensive tests** covering all utilities and mixins
- 100% coverage of utility methods
- Extensive mixin behavior validation

#### Code Quality
- Eliminated 170 lines of duplicate code
- Consistent validation patterns across all rules
- Improved error messages with better context
- Enhanced maintainability through shared components

### 🔧 Technical Details

#### Dependencies
- Dart SDK: ^3.6.0
- analyzer: ^7.6.0
- custom_lint_builder: ^0.7.6
- path: ^1.9.1
