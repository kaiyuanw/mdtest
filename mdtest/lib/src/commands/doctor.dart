// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../runner/mdtest_command.dart';
import '../globals.dart';
import '../util.dart';

class DoctorCommand extends MDTestCommand {

  @override
  final String name = 'doctor';

  @override
  final String description = 'Check if all dependent tools are installed.';

  @override
  Future<int> runCore() async {
    printInfo('Running "mdtest doctor command" ...');
    if (os.isWindows) {
      printInfo('Windows platform is not supported.');
      return 1;
    }
    if (os.which('adb') == null) {
      
    }
    if (os.isMacOS) {

    }
    return 0;
  }
}
