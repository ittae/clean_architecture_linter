// GOOD: Database framework implementation with proper isolation

// Mock database framework types
class Database {
  Future<void> connect() async {}
  Future<void> disconnect() async {}
  Future<Map<String, dynamic>?> query(String sql, List<dynamic> params) async => {};
  Future<void> execute(String sql, List<dynamic> params) async {}
}

class Connection {}
class Transaction {}

// GOOD: Database framework adapter implementing repository interface
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user.dart';

class DatabaseUserRepository implements UserRepository {
  final Database _database;

  DatabaseUserRepository(this._database);

  @override
  Future<User?> getUser(String userId) async {
    // GOOD: SQL is contained in framework layer
    final result = await _database.query(
      'SELECT id, name, email, created_at FROM users WHERE id = ?',
      [userId],
    );

    if (result == null) return null;

    // GOOD: Convert database format to domain format
    return User(
      id: result['id'],
      name: result['name'],
      email: result['email'],
      createdAt: DateTime.parse(result['created_at']),
    );
  }

  @override
  Future<List<User>> getAllUsers() async {
    // GOOD: Database-specific query in framework layer
    final results = await _database.query('SELECT * FROM users', []);

    if (results == null) return [];

    // GOOD: Simple data conversion without business logic
    return [
      User(
        id: results['id'],
        name: results['name'],
        email: results['email'],
        createdAt: DateTime.parse(results['created_at']),
      )
    ];
  }

  @override
  Future<bool> saveUser(User user) async {
    try {
      // GOOD: SQL operations confined to framework layer
      await _database.execute(
        'INSERT INTO users (id, name, email, created_at) VALUES (?, ?, ?, ?)',
        [user.id, user.name, user.email, user.createdAt.toIso8601String()],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteUser(String userId) async {
    try {
      await _database.execute('DELETE FROM users WHERE id = ?', [userId]);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// GOOD: Database migration management in framework layer
class DatabaseMigrations {
  final Database _database;

  DatabaseMigrations(this._database);

  Future<void> runMigrations() async {
    // GOOD: Schema management in framework layer
    await _createUsersTable();
    await _createOrdersTable();
  }

  Future<void> _createUsersTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''';

    await _database.execute(sql, []);
  }

  Future<void> _createOrdersTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        total REAL NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES users (id)
      )
    ''';

    await _database.execute(sql, []);
  }
}

// GOOD: Database connection management in framework layer
class DatabaseConnection {
  static Database? _instance;

  static Future<Database> getInstance() async {
    if (_instance == null) {
      _instance = Database();
      await _instance!.connect();
    }
    return _instance!;
  }

  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.disconnect();
      _instance = null;
    }
  }
}