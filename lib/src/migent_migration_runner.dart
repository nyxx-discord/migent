import 'dart:async';

import 'package:logging/logging.dart';
import 'package:migent/src/migration_access/migration_access.dart';
import 'package:postgres/postgres.dart';

const _migrationsTableName = 'run_migrations';

class MigentMigrationRunner {
  final Connection connection;
  final String databaseName;
  final MigrationAccess migrationAccess;
  final Map<String, String> enqueuedMigrations = {};

  final _logger = Logger('Migrations');

  MigentMigrationRunner({required this.connection, required this.databaseName, required this.migrationAccess});

  void enqueueMigration(String version, String migrationString) => enqueuedMigrations[version] = migrationString;

  FutureOr<void> runMigrations() async {
    for (final queueEntry in enqueuedMigrations.entries) {
      try {
        final migrationData = await migrationAccess.getMigrationData(queueEntry.key, queueEntry.value);
        final executed = await _runMigration(queueEntry.key, migrationData);

        if (executed) {
          await connection.execute(Sql.named('INSERT INTO run_migrations(version) VALUES (@version)'), parameters: {'version': queueEntry.key});

          _logger.info('Migration with version: `${queueEntry.key}` executed successfully');
        } else {
          _logger.info('Migration with version: `${queueEntry.key}` already executed');
        }
      } on PgException catch (e) {
        _logger.severe('Exception occurred when executing migrations: [${e.message}]');
        break;
      }
    }

    _logger.info('Migrations done!');
  }

  FutureOr<bool> _runMigration(String version, String migrationString) async {
    final shouldRunMigration = await _checkIfMigrationShouldBeExecuted(version);

    if (!shouldRunMigration) {
      return false;
    }

    _logger.info('Migration with version: `$version` not present in migration log. Running migration');

    await connection.execute(migrationString);

    return true;
  }

  /// Returns if this version should be execute
  Future<bool> _checkIfMigrationShouldBeExecuted(String version) async {
    final tableExistsQuery = """
      SELECT to_regclass('$_migrationsTableName');
    """;

    final tableExistsResult = await connection.execute(tableExistsQuery);

    if (tableExistsResult.first[0] == null) {
      const createQuery = '''
        CREATE TABLE $_migrationsTableName (
          id SERIAL PRIMARY KEY,
          version VARCHAR(100) NOT NULL
        );
      ''';
      await connection.execute(createQuery);

      return true;
    }

    final checkQuery = Sql.named('''
      SELECT version FROM $_migrationsTableName WHERE version = @version; 
    ''');

    final lastVersionResult = await connection.execute(checkQuery, parameters: {'version': version});

    return lastVersionResult.isEmpty;
  }
}
