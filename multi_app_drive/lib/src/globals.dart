import 'base/logger.dart';

final Logger defaultLogger = new StdoutLogger();
Logger get logger => defaultLogger;

void printInfo(String message) => logger.info(message);

void printError(String message) => logger.error(message);
