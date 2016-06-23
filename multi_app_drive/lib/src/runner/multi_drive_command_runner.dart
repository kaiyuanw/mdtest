import 'dart:async';
import 'package:args/command_runner.dart';

class MultiDriveCommandRunner extends CommandRunner {
  MultiDriveCommandRunner() : super(
    'multi-drive',
    'Run multi-device app tests'
  ) {
  }

  @override
  Future<dynamic> run(Iterable<String> args) {
    return super.run(args).then((dynamic result) {
      return result;
    });
  }
}
