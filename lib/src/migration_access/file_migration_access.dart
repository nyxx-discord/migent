import 'dart:io';

import 'package:migent/src/migration_access/migration_access.dart';

class FileMigrationAccess implements MigrationAccess {
  @override
  Future<String> getMigrationData(String version, String input) async => File(input).readAsString();
}
