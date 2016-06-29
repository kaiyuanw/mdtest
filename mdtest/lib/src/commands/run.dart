// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../mobile/device.dart';
import '../mobile/device_spec.dart';
import '../match/match_util.dart';
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

    List<DeviceSpec> allDeviceSpecs
      = await constructAllDeviceSpecs(_specs['devices']);
    Map<DeviceSpec, Set<Device>> individualMatches
      = findIndividualMatches(allDeviceSpecs, _devices);
    Map<DeviceSpec, Device> deviceMapping
      = findMatchingDeviceMapping(allDeviceSpecs, individualMatches);
    if(deviceMapping == null) {
      printError('No device specs to devices mapping is found.');
      return 1;
    }

    if (await runAllApps(deviceMapping) != 0) {
      printError('Error when running applications');
      return 1;
    }

    await storeMatches(deviceMapping);

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

List<Process> appProcesses = <Process>[];

/// Invoke runApp function for each device spec to device mapping in parallel
Future<int> runAllApps(Map<DeviceSpec, Device> deviceMapping) async {
  List<Future<int>> runAppList = <Future<int>>[];
  for (DeviceSpec deviceSpec in deviceMapping.keys) {
    Device device = deviceMapping[deviceSpec];
    runAppList.add(runApp(deviceSpec, device));
  }
  int res = 0;
  List<int> results = await Future.wait(runAppList);
  for (int result in results)
      res += result;
  return res == 0 ? 0 : 1;
}

/// Create a process that runs 'flutter run ...' command which installs and
/// starts the app on the device.  The function finds a observatory port
/// through the process output.  If no observatory port is found, then report
/// error.
Future<int> runApp(DeviceSpec deviceSpec, Device device) async {
  Process process = await Process.start(
    'flutter',
    ['run', '-d', device.id, '--target=${deviceSpec.appPath}'],
    workingDirectory: deviceSpec.appRootPath
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
      deviceSpec.observatoryUrl = portMatch.group(1);
      break;
    }
  }

  process.stderr.drain();

  if (deviceSpec.observatoryUrl == null) {
    printError('No observatory url is found.');
    return 1;
  }

  return 0;
}

/// Create a process and invoke 'dart testPath' to run the test script.  After
/// test result is returned (either pass or fail), kill all app processes and
/// return the current process exit code
Future<int> runTest(String testPath) async {
  Process process = await Process.start('dart', ['$testPath']);
  RegExp testStopPattern = new RegExp(r'All tests passed|Some tests failed');
  Stream stdoutStream = process.stdout
                               .transform(new Utf8Decoder())
                               .transform(new LineSplitter());
  await for (var line in stdoutStream) {
    print(line.toString().trim());
    if (testStopPattern.hasMatch(line.toString())) {
      process.stderr.drain();
      killAllProcesses(appProcesses);
      break;
    }
  }
  return await process.exitCode;
}

/// Kill all given processes
Future<Null> killAllProcesses(List<Process> processes) async {
  for (Process process in processes) {
    process.kill();
  }
}
