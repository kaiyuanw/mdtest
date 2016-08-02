// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';

import '../src/util.dart';

String binPath = directoryName(Platform.script.toFilePath());
String mdtestRootPath = directoryName(binPath);
String libPath = '$mdtestRootPath/lib';
String assetsPath = '$libPath/assets';

List<String> get relatedPaths => <String>[
  normalizePath(assetsPath, 'emerald.png'),
  normalizePath(assetsPath, 'ruby.png'),
  normalizePath(assetsPath, 'report.css')
];
