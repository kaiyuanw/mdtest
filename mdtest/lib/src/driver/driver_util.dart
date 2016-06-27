// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert' show JSON;

import 'package:flutter_driver/flutter_driver.dart';

import '../base/common.dart';
import '../globals.dart';

class DriverUtil {
  static Future<FlutterDriver> connectByName({String deviceNickname}) async {
    Directory systemTempDir = Directory.systemTemp;
    File tempFile = new File('${systemTempDir.path}/$defaultTempSpecsName');
    if(!await tempFile.exists()) {
      printError('Multi-Drive temporary specs file not found.');
      exit(1);
    }
    dynamic configs = JSON.decode(await tempFile.readAsString());
    if(!configs.containsKey(deviceNickname)) {
      printError('Device nickname $deviceNickname not found.');
      exit(1);
    }
    String deviceID = configs[deviceNickname]['device-id'];
    String observatoryPort = configs[deviceNickname]['observatory-port'];
    printInfo('$deviceNickname refers to device $deviceID running on port $observatoryPort');
    return await FlutterDriver.connect(dartVmServiceUrl: '$observatoryPort');
  }
}
