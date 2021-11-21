import 'package:args/command_runner.dart';
import 'package:migent/src/migrate_command.dart';

void main(List<String> args) {
  CommandRunner("migent", "Migration runner for Dart")
    ..addCommand(MigrateCommand())
    ..run(args);
}
