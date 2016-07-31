// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import '../util.dart';

abstract class Report {
  Directory outputDirectory;

  Report(String outputPath) {
    outputDirectory = createNewDirectory(outputPath);
  }
}
