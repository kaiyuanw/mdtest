// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../mobile/device.dart';
import '../globals.dart';

const String lockProp = 'mHoldingWakeLockSuspendBlocker';

/// Check if the device is locked
Future<bool> _deviceIsLocked(Device device) async {
  Process process = await Process.start(
    'bash',
    ['-c', 'adb -s ${device.id} shell dumpsys power | grep \'$lockProp\'']
  );
  bool isLocked;
  RegExp lockStatusPattern = new RegExp(r'mHoldingWakeLockSuspendBlocker=(.*)');
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
Future<int> wakeUp(Device device) async {

  bool isLocked = await _deviceIsLocked(device);

  if (isLocked == null) {
    printError('adb error: cannot find device $lockProp property');
    return 1;
  }

  if (!isLocked) return 0;

  Process wakeUpProcess = await Process.start(
    'bash',
    ['-c', 'adb -s ${device.id} shell input keyevent 82']
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
        ['-c', 'adb -s ${device.id} uninstall $package']
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
