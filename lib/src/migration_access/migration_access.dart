abstract class IMigrationAccess {
  Future<String> getMigrationData(String version, String input);
}
