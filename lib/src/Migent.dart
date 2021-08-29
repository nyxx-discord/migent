import 'dart:async';

import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

const _migrationsTableName = 'run_migrations';

class Migent {
  final PostgreSQLConnection connection;
  final String dbName;

  final _logger = Logger('Migrations');

  final Map<String, String> enqueuedMigrations = {};

  Migent(this.connection, this.dbName);

  void enqueueMigration(String version, String migrationString) =>
      enqueuedMigrations[version] = migrationString;

  FutureOr<void> runMigrations() async {
    for (final queueEntry in enqueuedMigrations.entries) {
      try {
        await _runMigration(queueEntry.key, queueEntry.value);

        await connection.execute(
            'INSERT INTO run_migrations(version) VALUES (@version)',
            substitutionValues: {'version': queueEntry.key}
        );

        _logger.info('Migration with version: `${queueEntry.key}` executed successfully');
      } on PostgreSQLException catch (e) {
        _logger.severe('Exception occurred when executing migrations: [${e.message}]');
        break;
      }
    }

    _logger.info('Migrations done!');
  }

  FutureOr<void> _runMigration(String version, String migrationString) async {
    final shouldRunMigration = await _checkIfMigrationShouldBeExecuted(version);

    if (!shouldRunMigration) {
      return;
    }

    _logger.info('Migration with version: `$version` not present in migration log. Running migration');

    await connection.execute(migrationString);
  }

  /// Returns if this version should be execute
  Future<bool> _checkIfMigrationShouldBeExecuted(String version) async {
    final tableExistsQuery = """
      SELECT to_regclass('$_migrationsTableName');
    """;

    final tableExistsResult = await connection.query(tableExistsQuery);

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

    const checkQuery = '''
      SELECT version FROM $_migrationsTableName WHERE version = @version; 
    ''';

    final lastVersionResult = await connection.query(checkQuery, substitutionValues: {
      "version": version
    });

    return lastVersionResult.first[0] != version;
  }
}
