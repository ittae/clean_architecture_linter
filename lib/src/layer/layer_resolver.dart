import 'package:analyzer/dart/element/element.dart';

/// Maps a resolved [Element] or [LibraryElement] to the feature and layer of
/// its declaring library.
///
/// Path folders are read from [LibraryElement.uri], not from import text and
/// not from a part file's own path. Design:
/// https://github.com/ittae/clean_architecture_linter/pull/192
///
/// No lint rule calls this yet.
class LayerResolver {
  /// [packageName] is the pub package under review.
  ///
  /// When it is null, every `package:` URI is [LayerKind.external]. A missing
  /// name must not turn a dependency whose path contains `domain` or `data`
  /// into a local layer.
  LayerResolver({String? packageName}) : _packageName = packageName;

  final String? _packageName;
  final Map<String, LayerLocation> _byUri = {};

  /// Layer of [library], cached by [LibraryElement.uri] on this instance.
  LayerLocation resolveLibrary(LibraryElement library) {
    final key = library.uri.toString();
    final cached = _byUri[key];
    if (cached != null) return cached;

    final location = _classify(library);
    _byUri[key] = location;
    return location;
  }

  /// Layer of [element]'s declaring library.
  ///
  /// Returns null when [Element.library] is null, which is the case for a
  /// [MultiplyDefinedElement] that is not contained in one library.
  LayerLocation? resolveElement(Element element) {
    final library = element.library;
    if (library == null) return null;
    return resolveLibrary(library);
  }

  LayerLocation _classify(LibraryElement library) {
    final uri = library.uri;
    if (library.isInSdk || uri.scheme == 'dart') {
      return _location(uri, LayerKind.external);
    }
    if (_isInfrastructurePackage(uri)) {
      return _location(uri, LayerKind.external, infrastructurePackage: true);
    }
    if (uri.scheme == 'package' && !_inCurrentPackage(uri)) {
      return _location(uri, LayerKind.external);
    }

    final segments = _classifiableSegments(uri);
    final kind = _kindFor(segments);
    final feature = _featureName(segments);
    if (kind == null) {
      return _location(uri, LayerKind.unknown, feature: feature);
    }
    return _location(
      uri,
      kind,
      feature: feature,
      useCaseLibrary: kind == LayerKind.domain && _hasUseCaseSegment(segments),
    );
  }

  bool _inCurrentPackage(Uri uri) {
    final packageName = _packageName;
    if (packageName == null) return false;
    return uri.pathSegments.isNotEmpty && uri.pathSegments.first == packageName;
  }

  List<String> _classifiableSegments(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (uri.scheme == 'package' && segments.isNotEmpty) {
      return segments.sublist(1);
    }
    return segments;
  }

  LayerKind? _kindFor(List<String> segments) {
    var domain = false;
    var data = false;
    var presentation = false;
    var infrastructure = false;
    var useCase = false;
    for (final segment in segments) {
      if (segment == 'domain') domain = true;
      if (segment == 'usecases' || segment == 'use_cases') useCase = true;
      if (segment == 'data' ||
          segment == 'datasources' ||
          segment == 'data_sources') {
        data = true;
      }
      if (_presentationSegments.contains(segment)) presentation = true;
      if (_infrastructureSegments.contains(segment)) infrastructure = true;
    }
    if (domain) return LayerKind.domain;
    if (data) return LayerKind.data;
    if (presentation) return LayerKind.presentation;
    if (infrastructure) return LayerKind.infrastructure;
    if (useCase) return LayerKind.domain;
    return null;
  }

  bool _hasUseCaseSegment(List<String> segments) {
    return segments.any(
      (segment) => segment == 'usecases' || segment == 'use_cases',
    );
  }

  String? _featureName(List<String> segments) {
    for (var index = 0; index < segments.length - 1; index++) {
      if (segments[index] != 'features') continue;
      final name = segments[index + 1];
      if (_featurePattern.hasMatch(name)) return name;
    }
    return null;
  }

  bool _isInfrastructurePackage(Uri uri) {
    final text = uri.toString();
    return _infrastructurePrefixes.any(text.startsWith);
  }

  LayerLocation _location(
    Uri uri,
    LayerKind kind, {
    String? feature,
    bool useCaseLibrary = false,
    bool infrastructurePackage = false,
  }) {
    return LayerLocation(
      kind: kind,
      feature: feature,
      useCaseLibrary: useCaseLibrary,
      infrastructurePackage: infrastructurePackage,
      libraryUri: uri,
    );
  }
}

enum LayerKind { domain, data, presentation, infrastructure, unknown, external }

class LayerLocation {
  const LayerLocation({
    required this.kind,
    required this.feature,
    required this.useCaseLibrary,
    required this.infrastructurePackage,
    required this.libraryUri,
  });

  final LayerKind kind;
  final String? feature;
  final bool useCaseLibrary;
  final bool infrastructurePackage;
  final Uri libraryUri;
}

const _presentationSegments = {
  'presentation',
  'ui',
  'widgets',
  'screens',
  'pages',
  'views',
  'states',
  'providers',
};

const _infrastructureSegments = {'infrastructure', 'services', 'external'};

const _infrastructurePrefixes = [
  'package:http/',
  'package:dio/',
  'package:sqflite/',
  'package:hive/',
  'package:shared_preferences/',
  'package:cloud_firestore/',
  'package:firebase_',
  'package:drift/',
  'package:isar/',
  'package:objectbox/',
  'package:realm/',
];

final _featurePattern = RegExp(r'^\w+$');
