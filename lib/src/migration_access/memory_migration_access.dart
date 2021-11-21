import 'package:migent/src/migration_access/migration_access.dart';

class MemoryMigrationAccess implements IMigrationAccess {
  @override
  Future<String> getMigrationData(String version, String input) async => input;
}
