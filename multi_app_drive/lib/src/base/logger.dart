import 'dart:io';

abstract class Logger {
  void info(String message);
  void error(String message);
}

class StdoutLogger extends Logger {
  @override
  void info(String message) {
    print('[info] $message');
  }

  @override
  void error(String message) {
    stderr.writeln('[error] $message');
  }
}
