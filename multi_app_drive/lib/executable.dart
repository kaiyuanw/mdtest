import 'dart:async';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

import 'src/commands/run.dart';
import 'src/runner/multi_drive_command_runner.dart';

Future<Null> main(List<String> args) async {
  MultiDriveCommandRunner runner = new MultiDriveCommandRunner()
    ..addCommand(new RunCommand());

    return Chain.capture(() async {
      dynamic result = await runner.run(args);
      exit(result is int ? result : 0);
    }, onError: (dynamic error, Chain chain) {
      print(error);
    });
}
