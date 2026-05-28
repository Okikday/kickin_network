import 'dart:developer' as dev;

import 'package:logger/logger.dart';

class _DevLogOutput extends LogOutput {
  final String name;

  _DevLogOutput({this.name = 'KApi'});

  @override
  void output(OutputEvent event) => dev.log(event.lines.join('\n'), name: name);
}

class NetworkLog {
  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      printEmojis: true,
      colors: true,
      lineLength: 80,
      levelColors: const {
        Level.info: AnsiColor.fg(6), // Cyan for Requests
        Level.debug: AnsiColor.fg(2), // Green for Success Responses
        Level.error: AnsiColor.fg(1), // Red for Error Responses
      },
    ),
    output: _DevLogOutput(name: 'kickin.network'),
  );

  // Expose basic methods
  static void request(String message) => _logger.i(message);
  static void success(String message) => _logger.d(message);
  static void error(String message, [dynamic error, StackTrace? st]) =>
      _logger.e(message, error: error, stackTrace: st);
}
