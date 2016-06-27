// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../base/common.dart';
import '../mobile/device.dart';
import '../mobile/device_spec.dart';
import '../mobile/device_util.dart';
import '../globals.dart';
import '../runner/mdtest_command.dart';

class RunCommand extends MDTestCommand {

  @override
  final String name = 'run';

  @override
  final String description = 'Run multi-device driver tests';

  dynamic _specs;

  List<Device> _devices;

  @override
  Future<int> runCore() async {
    print('Running "mdtest run command" ...');

    this._specs = await loadSpecs(argResults['specs']);
    print(_specs);

    this._devices = await getDevices();
    if (_devices.isEmpty) {
      printError('No device found.');
      return 1;
    }

    List<DeviceSpecs> allDeviceSpecs
      = await constructAllDeviceSpecs(_specs['devices']);
    Map<DeviceSpecs, Device> anyMatch = <DeviceSpecs, Device>{};
    Map<DeviceSpecs, Set<Device>> individualMatches
      = findIndividualMatches(allDeviceSpecs, _devices);
    if(!findAllMatches(0, allDeviceSpecs, individualMatches,
                     new Set<Device>(), anyMatch)) {
      printError('No device specs to devices mapping is found.');
      return 1;
    }

    if (await runAllApps(anyMatch) != 0) {
      printError('Error when running applications');
      return 1;
    }

    await storeMatches(anyMatch);

    if (await runTest(_specs['test-path']) != 0) {
      printError('Test execution exit with error.');
      return 1;
    }

    return 0;
  }

  RunCommand() {
    usesSpecsOption();
  }
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

Future<List<DeviceSpecs>> constructAllDeviceSpecs(dynamic allSpecs) async {
  List<DeviceSpecs> devicesSpecs = <DeviceSpecs>[];
  for(String name in allSpecs.keys) {
    Map<String, String> specs = allSpecs[name];
    devicesSpecs.add(
      new DeviceSpecs(
        nickName: name,
        deviceID: specs['device-id'],
        deviceModelName: specs['model-name'],
        appRootPath: specs['app-root'],
        appPath: specs['app-path']
      )
    );
  }
  return devicesSpecs;
}

Map<DeviceSpecs, Set<Device>> findIndividualMatches(
  List<DeviceSpecs> devicesSpecs,
  List<Device> devices) {
  Map<DeviceSpecs, Set<Device>> individualMatches
    = new Map<DeviceSpecs, Set<Device>>();
  for(DeviceSpecs deviceSpecs in devicesSpecs) {
    Set<Device> matchedDevices = new Set<Device>();
    for(Device device in devices) {
      if(deviceSpecs.matches(device))
        matchedDevices.add(device);
    }
    individualMatches[deviceSpecs] = matchedDevices;
  }
  return individualMatches;
}

bool findAllMatches(
  int order,
  List<DeviceSpecs> devicesSpecs,
  Map<DeviceSpecs, Set<Device>> individualMatches,
  Set<Device> visited,
  Map<DeviceSpecs, Device> anyMatch
) {
  if(order == devicesSpecs.length) return true;
  DeviceSpecs deviceSpecs = devicesSpecs[order];
  Set<Device> matchedDevices = individualMatches[deviceSpecs];
  for(Device candidate in matchedDevices) {
    if(visited.add(candidate)) {
      anyMatch[deviceSpecs] = candidate;
      if(findAllMatches(order + 1, devicesSpecs, individualMatches,
                        visited, anyMatch))
        return true;
      else {
        visited.remove(candidate);
        anyMatch.remove(deviceSpecs);
      }
    }
  }
  return false;
}

List<Process> appProcesses = <Process>[];

Future<int> runAllApps(Map<DeviceSpecs, Device> anyMatch) async {
  int result = 0;
  for (DeviceSpecs deviceSpecs in anyMatch.keys) {
    Device device = anyMatch[deviceSpecs];
    result += await runApp(deviceSpecs, device);
  }
  return result == 0 ? 0 : 1;
}

Future<int> runApp(DeviceSpecs deviceSpecs,  Device device) async {
  Process process = await Process.start(
    'flutter',
    ['run', '-d', device.id, '--target=${deviceSpecs.appPath}'],
    workingDirectory: deviceSpecs.appRootPath
  );
  appProcesses.add(process);
  Stream lineStream = process.stdout
                             .transform(new Utf8Decoder())
                             .transform(new LineSplitter());
  RegExp portPattern = new RegExp(r'Observatory listening on (http.*)');
  await for (var line in lineStream) {
    print(line.toString().trim());
    Match portMatch = portPattern.firstMatch(line.toString());
    if (portMatch != null) {
      deviceSpecs.observatoryPort = portMatch.group(1);
      break;
    }
  }

  process.stderr.drain();

  if (deviceSpecs.observatoryPort == null) {
    printError('No observatory port is found.');
    return 1;
  }

  return 0;
}

Future<Null> storeMatches(Map<DeviceSpecs, Device> anyMatch) async {
  Map<String, dynamic> matchesData = new Map<String, dynamic>();
  anyMatch.forEach((DeviceSpecs specs, Device device) {
    Map<String, String> idAndPort = new Map<String, String>();
    idAndPort['device-id'] = device.id;
    idAndPort['observatory-port'] = specs.observatoryPort;
    matchesData[specs.nickName] = idAndPort;
  });
  Directory systemTempDir = Directory.systemTemp;
  File tempFile = new File('${systemTempDir.path}/$defaultTempSpecsName');
  if(await tempFile.exists())
    await tempFile.delete();
  File file = await tempFile.create();
  await file.writeAsString(JSON.encode(matchesData));
}

Future<int> runTest(String testPath) async {
  Process process = await Process.start('dart', ['$testPath']);
  RegExp testPassPattern = new RegExp(r'All tests passed');
  RegExp testFailPattern = new RegExp(r'Some tests failed');
  Stream stdoutStream = process.stdout
                               .transform(new Utf8Decoder())
                               .transform(new LineSplitter());
  await for (var line in stdoutStream) {
    print(line.toString().trim());
    if (testPassPattern.hasMatch(line.toString()) || testFailPattern.hasMatch(line.toString())) {
      process.stderr.drain();
      killAllProcesses(appProcesses);
      break;
    }
  }

  return await process.exitCode;
}

Future<Null> killAllProcesses(List<Process> processes) async {
  for (Process process in processes) {
    print(process.kill());
    print(await process.exitCode);
  }
}
