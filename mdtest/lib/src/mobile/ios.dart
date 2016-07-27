// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import '../mobile/device.dart';
import '../mobile/device_spec.dart';
import '../globals.dart';
import '../util.dart';

Future<List<String>> getIOSDeviceIDs() async {
  List<String> iosIDs = <String>[];
  if (!os.isMacOS) {
    return iosIDs;
  }
  Process process = await Process.start('mobiledevice', ['list_devices']);
  RegExp iosIDPattern = new RegExp(r'.*');
  Stream lineStream = process.stdout
                             .transform(new Utf8Decoder())
                             .transform(new LineSplitter());

  await for (var line in lineStream) {
    Match iosIDMatcher = iosIDPattern.firstMatch(line.toString());
    if (iosIDMatcher != null) {
      String iosID = iosIDMatcher.group(1);
      iosIDs.add(iosID);
    }
  }
  return iosIDs;
}
