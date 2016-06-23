import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../globals.dart';
import 'multi_drive_command_runner.dart';

typedef bool Validator();

abstract class MultiDriveCommand extends Command {

  MultiDriveCommand() {
    commandValidator = _commandValidator;
  }

  @override
  MultiDriveCommandRunner get runner => super.runner;

  bool _usesSpecsOption = false;

  void usesSpecsOption() {
    argParser.addOption(
      'specs',
      defaultsTo: null,
      allowMultiple: false,
      help:
        'Path to the config file that specifies the devices, '
        'apps and debug-ports for testing.'
    );
    _usesSpecsOption = true;
  }

  @override
  Future<int> run() {
    Stopwatch stopwatch = new Stopwatch()..start();
    return _run().then((int exitCode) {
      int ms = stopwatch.elapsedMilliseconds;
      printInfo('"multi-drive $name" took ${ms}ms; exiting with code $exitCode.');
      return exitCode;
    });
  }

  Future<int> _run() async {
    if (!commandValidator())
      return 1;
    return await runCore();
  }

  Future<int> runCore();

  Validator commandValidator;

  bool _commandValidator() {
    if (_usesSpecsOption) {
      String specsPath = argResults['specs'];
      if (specsPath == null) {
        printError('Specs file is not set.');
        return false;
      }
      if (!FileSystemEntity.isFileSync(specsPath)) {
        printError('Specs file "$specsPath" not found.');
        return false;
      }
    }
    return true;
  }
}
