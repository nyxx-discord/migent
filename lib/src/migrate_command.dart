import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:migent/migent.dart';
import 'package:migent/src/migration_access/file_migration_access.dart';
import 'package:path/path.dart';
import 'package:postgres/postgres.dart';

class MigrateCommand extends Command<void> {
  @override
  String get description => "Runs migrations located in directory";

  @override
  String get name => "migrate";

  MigrateCommand() {
    argParser
      ..addOption("directory", abbr: 'd', defaultsTo: "migrations/", help: "Directory where migrations files are located")
      ..addOption("host", abbr: "h", help: "Host of database")
      ..addOption("port", abbr: "p", help: "Port of database", defaultsTo: "5432")
      ..addOption("user", abbr: "u", help: "Database user")
      ..addOption("password", abbr: "p", help: "Password of user")
      ..addOption("database", abbr: "d", help: "Database name");
  }

  @override
  FutureOr<void> run() async {
    if (argResults == null) {
      throw StateError("Not arguments passed. Read help if you need to understand what options you need to pass");
    }

    final host = argResults!['host'] as String?;
    if (host == null || host.isEmpty) {
      throw StateError("Missing or empty 'host' option");
    }

    final port = int.tryParse(argResults!['port'] as String);
    if (port == null) {
      throw StateError("Invalid int passed to 'port' option");
    }

    final database = argResults!['database'] as String?;
    if (database == null || database.isEmpty) {
      throw StateError("Missing or empty 'database' options");
    }

    final connection = PostgreSQLConnection(host, port, database, username: argResults!['user'] as String?, password: argResults!['password'] as String?);

    final migrationRunner = MigentMigrationRunner(connection, database, FileMigrationAccess());

    final directory = Directory.fromUri(Uri.directory("${Directory.current.absolute.path}/${argResults!['directory']}"));
    final directoryFiles = directory.list().where((entity) => entity is File);

    await for (final file in directoryFiles) {
      migrationRunner.enqueueMigration(basenameWithoutExtension(file.path), file.absolute.path);
    }

    await migrationRunner.runMigrations();
  }
}
