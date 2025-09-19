// BAD: Framework layer with multiple Clean Architecture violations

// Mock framework types for demonstration
class Database {
  Future<Map<String, dynamic>?> query(String sql) async => {};
  Future<void> execute(String sql) async {}
}

class HttpServer {
  void listen(int port) {}
}

class HttpRequest {
  Map<String, String> get headers => {};
  String get method => 'GET';
  String get path => '/';
}

class HttpResponse {
  void write(String content) {}
  void setHeader(String name, String value) {}
}

// BAD: Framework class with business logic
class BadDatabaseUserRepository {
  final Database _database;

  BadDatabaseUserRepository(this._database);

  Future<Map<String, dynamic>?> getUser(String userId) async {
    // BAD: Business validation in framework layer
    if (userId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    // BAD: Business rule - only active users
    if (!_isUserActive(userId)) {
      return null;
    }

    final result = await _database.query('SELECT * FROM users WHERE id = "$userId"');

    // BAD: Business logic for user data processing
    if (result != null) {
      result['display_name'] = _formatUserDisplayName(result);
      result['is_premium'] = _calculatePremiumStatus(result);
    }

    return result;
  }

  // BAD: Business logic in framework layer
  bool _isUserActive(String userId) {
    // Business rule: users with certain patterns are inactive
    return !userId.startsWith('inactive_');
  }

  // BAD: Business logic for formatting
  String _formatUserDisplayName(Map<String, dynamic> userData) {
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    return '$firstName $lastName'.trim();
  }

  // BAD: Complex business calculation in framework
  bool _calculatePremiumStatus(Map<String, dynamic> userData) {
    final registrationDate = DateTime.parse(userData['created_at']);
    final daysSinceRegistration = DateTime.now().difference(registrationDate).inDays;
    final orderCount = userData['order_count'] ?? 0;

    // Complex business logic that should be in domain
    return daysSinceRegistration > 30 && orderCount > 5;
  }

  // BAD: Validation logic in framework
  Future<bool> validateAndSaveUser(Map<String, dynamic> userData) async {
    // Business validation
    if (userData['email'] == null || !userData['email'].contains('@')) {
      return false;
    }

    // Business rule: users must have minimum age
    if (userData['age'] < 18) {
      return false;
    }

    // Framework concern mixed with business logic
    await _database.execute(
      'INSERT INTO users (name, email, age) VALUES ("${userData['name']}", "${userData['email']}", ${userData['age']})'
    );

    return true;
  }
}

// BAD: Web framework with business logic
class BadWebServer {
  final HttpServer _server;
  final Database _database;

  BadWebServer(this._server, this._database);

  void start() {
    _server.listen(8080);
  }

  // BAD: HTTP handler with business logic
  Future<void> handleCreateUser(HttpRequest request, HttpResponse response) async {
    // BAD: Data processing in web framework
    final userData = _parseUserData(request);

    // BAD: Business validation in web layer
    if (!_validateUserBusinessRules(userData)) {
      response.write('Invalid user data');
      return;
    }

    // BAD: Business logic for user creation
    final userId = _generateUserId(userData);
    final hashedPassword = _hashPassword(userData['password']);

    // BAD: Direct database access in web handler
    await _database.execute(
      'INSERT INTO users (id, name, email, password) VALUES ("$userId", "${userData['name']}", "${userData['email']}", "$hashedPassword")'
    );

    // BAD: Business logic for welcome message
    final welcomeMessage = _createWelcomeMessage(userData);
    response.write(welcomeMessage);
  }

  // BAD: Data processing logic in web framework
  Map<String, dynamic> _parseUserData(HttpRequest request) {
    // Complex parsing logic that should be in adapter
    return {
      'name': request.headers['name'] ?? '',
      'email': request.headers['email'] ?? '',
      'password': request.headers['password'] ?? '',
    };
  }

  // BAD: Business validation in web framework
  bool _validateUserBusinessRules(Map<String, dynamic> userData) {
    // Business rules that should be in domain
    if (userData['name'].length < 2) return false;
    if (!userData['email'].contains('@')) return false;
    if (userData['password'].length < 8) return false;
    return true;
  }

  // BAD: Business logic for ID generation
  String _generateUserId(Map<String, dynamic> userData) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final emailPrefix = userData['email'].split('@')[0];
    return '${emailPrefix}_$timestamp';
  }

  // BAD: Security logic in web framework
  String _hashPassword(String password) {
    // Password hashing logic should be in security service
    return password.split('').reversed.join(); // Dummy implementation
  }

  // BAD: Business logic for messaging
  String _createWelcomeMessage(Map<String, dynamic> userData) {
    final name = userData['name'];
    final isPremiumEligible = userData['email'].endsWith('.com');

    if (isPremiumEligible) {
      return 'Welcome $name! You are eligible for premium features.';
    } else {
      return 'Welcome $name!';
    }
  }
}

// BAD: Main function with complex business logic
void badMain() {
  // BAD: Business configuration in main
  final maxUsers = 1000;
  final premiumThreshold = 100.0;

  // BAD: Business logic in main
  if (DateTime.now().weekday == DateTime.monday) {
    print('Monday special offers enabled');
  }

  // BAD: Complex algorithm in framework layer
  final userPriorities = _calculateUserPriorities();

  // BAD: Database setup with business rules
  final database = Database();
  _setupDatabaseWithBusinessRules(database);

  print('Application started with complex setup');
}

// BAD: Complex algorithm in framework layer
List<String> _calculateUserPriorities() {
  // Complex sorting algorithm that should be in business layer
  final users = ['user1', 'user2', 'user3'];
  users.sort((a, b) => a.length.compareTo(b.length));
  return users;
}

// BAD: Database setup with business constraints
void _setupDatabaseWithBusinessRules(Database database) {
  // BAD: Business rule constraints in database setup
  database.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL CHECK(length(name) >= 2),
      email TEXT NOT NULL CHECK(email LIKE '%@%'),
      age INTEGER CHECK(age >= 18),
      premium_status BOOLEAN DEFAULT FALSE
    )
  ''');

  // BAD: Business data seeding
  database.execute('''
    INSERT INTO users (id, name, email, age, premium_status)
    VALUES ("admin", "Administrator", "admin@example.com", 30, TRUE)
  ''');
}

// BAD: Framework configuration with business logic
class BadApplicationConfig {
  // BAD: Business configuration mixed with framework config
  static const int maxOrdersPerUser = 10;
  static const double discountThreshold = 500.0;
  static const String defaultCurrency = 'USD';

  static void configure() {
    // BAD: Business rule configuration
    if (DateTime.now().month == 12) {
      // Holiday season rules
      _enableHolidayDiscounts();
    }

    // BAD: Complex business configuration
    _setupBusinessRules();
  }

  static void _enableHolidayDiscounts() {
    // Business logic that should be in domain
    print('Holiday discounts enabled');
  }

  static void _setupBusinessRules() {
    // Business rules setup in framework
    print('Business rules configured');
  }
}