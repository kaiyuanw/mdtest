// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import '../mobile/device.dart';
import '../globals.dart';

const String lockProp = 'mHoldingWakeLockSuspendBlocker';

/// Check if the device is locked
Future<bool> _deviceIsLocked(Device device) async {
  Process process = await Process.start(
    'adb',
    ['-s', '${device.id}', 'shell', 'dumpsys', 'power']
  );
  bool isLocked;
  RegExp lockStatusPattern = new RegExp(lockProp + r'=(.*)');
  Stream lineStream = process.stdout
                        .transform(new Utf8Decoder())
                        .transform(new LineSplitter());
  await for (var line in lineStream) {
    Match lockMatcher = lockStatusPattern.firstMatch(line.toString());
    if (lockMatcher != null) {
      isLocked = lockMatcher.group(1) == 'false';
      break;
    }
  }

  process.stderr.drain();
  await process.exitCode;

  return isLocked;
}

/// Wake up devices if the device is locked
Future<int> unlockDevice(Device device) async {

  bool isLocked = await _deviceIsLocked(device);

  if (isLocked == null) {
    printError('adb error: cannot find device $lockProp property');
    return 1;
  }

  if (!isLocked) return 0;

  Process wakeUpProcess = await Process.start(
    'adb',
    ['-s', '${device.id}', 'shell', 'input', 'keyevent', 'KEYCODE_MENU']
  );
  wakeUpProcess.stdout.drain();
  wakeUpProcess.stderr.drain();

  return await wakeUpProcess.exitCode;
}

/// List running third-party apps and uninstall them.  The goal is to uninstall
/// testing apps
Future<int> cleanUp(List<Device> devices) async {
  int result = 0;
  for (Device device in devices) {
    List<String> packages = <String>[];
    Process process = await Process.start(
      'bash',
      [
        '-c',
        'adb -s ${device.id} shell ps|grep -v root|grep -v system|'
        'grep -v NAME|grep -v shell|grep -v smartcard|'
        'grep -v androidshmservice|grep -v bluetooth|grep -v radio|'
        'grep -v nfc|grep -v "com.android."|grep -v "android.process."|'
        'grep -v "com.google.android."|grep -v "com.sec.android."|'
        'grep -v "com.google.process."|grep -v "com.samsung.android."|'
        'grep -v "com.smlds" |awk \'\{print \$9\}\''
      ]
    );
    Stream stdoutStream = process.stdout
                                 .transform(new Utf8Decoder())
                                 .transform(new LineSplitter());
    await for (var line in stdoutStream) {
      packages.add(line.toString().trim());
    }
    process.stderr.drain();
    result += await process.exitCode;

    for (String package in packages) {
      Process p = await Process.start(
        'bash',
        ['-c', 'adb -s ${device.id} shell am force-stop $package']
      );
      Stream lineStream = p.stdout
                           .transform(new Utf8Decoder())
                           .transform(new LineSplitter());
      await for (var line in lineStream) {
        print('Uninstall $package on device ${device.id}: ${line.toString().trim()}');
      }
      p.stderr.drain();
      result += await p.exitCode;
    }
  }
  return result == 0 ? 0 : 1;
}

/// Get device property
Future<String> getProperty(String deviceID, String propName) async {
  ProcessResult results = await Process.run('adb', ['-s', deviceID, 'shell', 'getprop', propName]);
  return results.stdout.toString().trim();
}

/// Get device pixels and dpi to compute screen diagonal size in inches
Future<String> getScreenSize(String deviceID) async {
  Process sizeProcess = await Process.start(
    'bash',
    ['-c', 'adb -s $deviceID shell wm size']
  );
  RegExp sizePattern = new RegExp(r'Physical size:\s*(\d+)x(\d+)');
  Stream sizeLineStream = sizeProcess.stdout
                                     .transform(new Utf8Decoder())
                                    .transform(new LineSplitter());
  int xSize;
  int ySize;
  await for (var line in sizeLineStream) {
    Match sizeMatcher = sizePattern.firstMatch(line.toString());
    if (sizeMatcher != null) {
      xSize = int.parse(sizeMatcher.group(1));
      ySize = int.parse(sizeMatcher.group(2));
      break;
    }
  }

  if (xSize == null || ySize == null) {
    printError('Screen size not found.');
    return null;
  }

  sizeProcess.stderr.drain();

  Process densityProcess = await Process.start(
    'bash',
    ['-c', 'adb -s $deviceID shell wm density']
  );
  RegExp densityPattern = new RegExp(r'Physical density:\s*(\d+)');
  Stream densityLineStream = densityProcess.stdout
                                           .transform(new Utf8Decoder())
                                           .transform(new LineSplitter());
  int density;
  await for (var line in densityLineStream) {
    Match densityMatcher = densityPattern.firstMatch(line.toString());
    if (densityMatcher != null) {
      density = int.parse(densityMatcher.group(1));
      break;
    }
  }

  if (density == null) {
    printError('Density not found.');
    return null;
  }

  densityProcess.stderr.drain();

  double xInch = xSize / density;
  double yInch = ySize / density;
  double diagonalSize = sqrt(xInch * xInch + yInch * yInch);

  if (diagonalSize < 3.5) return 'small';
  else if (diagonalSize < 5) return 'normal';
  else if (diagonalSize < 8) return 'large';
  else return 'xlarge';
}
