import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../mobile/device.dart';
import '../globals.dart';
import '../runner/multi_drive_command.dart';

class RunCommand extends MultiDriveCommand {

  @override
  final String name = 'run';

  @override
  final String description = 'Run multi-device applicatoin on multiple devices';

  dynamic _specs;

  @override
  Future<int> runCore() async {
    print('Running "multi-drive run command" ...');
    this._specs = await loadSpecs(argResults['specs']);
    print(_specs);
    print(await devices);
    return 0;
  }

  RunCommand() {
    usesSpecsOption();
  }
}

Future<List<Device>> get devices async {
  List<Device> devices = <Device>[];
  await _deviceIDs.then((List<String> ids) async {
    for(String id in ids) {
      devices.add(await collectDeviceProps(id));
    }
  });
  return devices;
}

Future<List<String>> get _deviceIDs async {
  List<String> deviceIDs = <String>[];
  Process process = await Process.start('flutter', ['devices', '-v']);
  Stream lineStream = process.stdout
                             .transform(new Utf8Decoder())
                             .transform(new LineSplitter());
  bool startReading = false;
  RegExp startPattern = new RegExp(r'List of devices attached');
  RegExp deviceIDPattern = new RegExp(r'\s+(\w+)\s+.*');
  RegExp stopPatternWithDevices = new RegExp(r'\d+ connected devices?');
  RegExp stopPatternWithoutDevices = new RegExp(r'No devices detected');
  await for (var line in lineStream) {
    if (!startReading && startPattern.hasMatch(line.toString())) {
      startReading = true;
      continue;
    }
    if (stopPatternWithDevices.hasMatch(line.toString()) || stopPatternWithoutDevices.hasMatch(line.toString())) {
      startReading = false;
      break;
    }
    if (startReading) {
      Match idMatch = deviceIDPattern.firstMatch(line.toString());
      if (idMatch != null) {
        String deviceID = idMatch.group(1);
        deviceIDs.add(deviceID);
      }
    }
  }
  process.stderr.drain();
  // print('exit code: ${await process.exitCode}');
  return deviceIDs;
}

Future<Device> collectDeviceProps(String deviceID) async {
  return new Device(
    id: deviceID,
    modelName: await property(deviceID, 'ro.product.model')
  );
}

Future<String> property(String deviceID, String propName) async {
  ProcessResult results = await Process.run('adb', ['-s', deviceID, 'shell', 'getprop', propName]);
  return results.stdout.toString().trim();
}

Future<dynamic> loadSpecs(String specsPath) async {
  try {
    // Read specs file into json format
    dynamic newSpecs = JSON.decode(await new File(specsPath).readAsString());
    // Get the parent directory of the specs file
    String rootPath = new File(specsPath).parent.absolute.path;
    // Normalize the 'test-path' in the specs file
    newSpecs['test-path'] = normalizePath(rootPath, newSpecs['test-path']);
    // Normalize the 'app-path' in the specs file
    newSpecs['devices'].forEach((String name, Map<String, String> map) {
      map['app-path'] = normalizePath(rootPath, map['app-path']);
      map['app-root'] = normalizePath(rootPath, map['app-root']);
    });
    return newSpecs;
  } on FileSystemException {
    printError('File $specsPath does not exist.');
    exit(1);
  } on FormatException {
    printError('File $specsPath is not in JSON format.');
    exit(1);
  } catch (e) {
    print('Unknown Exception details:\n $e');
    exit(1);
  }
}

String normalizePath(String rootPath, String relativePath) {
  return path.normalize(path.join(rootPath, relativePath));
}
