// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';

import 'globals.dart';

class OperatingSystemUtil {
  String _os;
  static OperatingSystemUtil instance;

  factory OperatingSystemUtil() {
    if (instance == null) {
      instance = new OperatingSystemUtil._internal(Platform.operatingSystem);
    }
    return instance;
  }

  bool get isMacOS => _os == 'macos';
  bool get isWindows => _os == 'windows';
  bool get isLinux => _os == 'linux';

  OperatingSystemUtil._internal(this._os);
}

// '=' * 20
const String doubleLineSeparator = '====================';
// '-' * 20
const String singleLineSeparator = '--------------------';

int sum(Iterable<num> nums) {
  if (nums.isEmpty) {
    return 0;
  }
  return nums.reduce((num x, num y) => x + y);
}

String directoryName(String filePath) {
  return path.dirname(filePath);
}

String fileBaseName(String filePath) {
  return path.basename(filePath);
}

int minLength(List<String> elements) {
  if (elements == null || elements.isEmpty) return -1;
  return elements.map((String e) => e.length).reduce(min);
}

bool isSystemSeparator(String letter) {
  return letter == Platform.pathSeparator;
}

int beginOfDiff(List<String> elements) {
  if (elements.length == 1)
    return elements[0].lastIndexOf(Platform.pathSeparator) + 1;
  int minL = minLength(elements);
  int lastSlash = 0;
  for (int i = 0; i < minL; i++) {
    String letter = elements[0][i];
    if (isSystemSeparator(letter)) {
      lastSlash = i;
    }
    for (String element in elements) {
      if (letter != element[i]) {
        return lastSlash + 1;
      }
    }
  }
  return minL;
}

String normalizePath(String rootPath, String relativePath) {
  if (rootPath == null || relativePath == null) {
    return null;
  }
  return path.normalize(
    path.join(rootPath, relativePath)
  );
}

String generateTimeStamp() {
  return new DateTime.now().toIso8601String();
}

bool deleteDirectories(Iterable<String> dirPaths) {
  for (String dirPath in dirPaths) {
    try {
      new Directory(dirPath).deleteSync(recursive: true);
    } on FileSystemException {
      printError('Cannot delete directory $dirPath');
      return false;
    }
  }
  return true;
}

/// Get a file with unique name under the given directory.
File getUniqueFile(Directory dir, String baseName, String ext) {
  int i = 1;
  while (true) {
    String name = '${baseName}_${i.toString().padLeft(2, '0')}.$ext';
    File file = new File(path.join(dir.path, name));
    if (!file.existsSync())
      return file;
    i++;
  }
}

/// Create a file if it does not exist.  If the path points to a file, delete
/// it and create a new file.  Otherwise, report error
File createNewFile(String path) {
  File file = new File('$path');;
  if(file.existsSync())
    file.deleteSync();
  return file..createSync(recursive: true);
}

/// Create a directory if it does not exist.  If the path points to a directory,
/// delete it and create a new directory.  Otherwise, report error
Directory createNewDirectory(String path) {
  Directory directory = new Directory('$path');;
  if(directory.existsSync())
    directory.deleteSync(recursive: true);
  return directory..createSync(recursive: true);
}

/// Return the absolute paths of a list of files based on a list of glob
/// patterns.  The order of the result follow the order of the given glob
/// patterns, but the order of file paths corresponding to the same glob
/// pattern is not guranteed.
List<String> listFilePathsFromGlobPatterns(
  String rootPath,
  Iterable<String> globPatterns
) {
  List<String> result = <String>[];
  if (globPatterns == null) {
    return result;
  }
  Set<String> seen = new Set<String>();
  for (String globPattern in globPatterns) {
    Glob fileGlob = new Glob(globPattern);
    Iterable<String> filePaths = fileGlob.listSync().map(
      (FileSystemEntity file) => normalizePath(rootPath, file.path)
    );
    Set<String> neverSeen = new Set.from(filePaths).difference(seen);
    result.addAll(neverSeen);
    seen.addAll(neverSeen);
  }
  return result;
}

/// Merge two iterables into a list and remove duplicates.  The order is kept
/// where elements in [first] appear before elements in [second] and the order
/// inside each iterable is also kept.  [first] and [second] must not contain
/// any duplicate item.
List<String> mergeWithoutDuplicate(
  Iterable<String> first,
  Iterable<String> second
) {
  List<String> result = new List.from(first);
  result.addAll(second.where((String e) => !first.contains(e)));
  return result;
}

String dumpToJSONString(dynamic jsonObject) {
  JsonEncoder encoder = const JsonEncoder.withIndent('  ');
  return encoder.convert(jsonObject);
}

void copyPathToDirectory(String fPath, String dirPath) {
  Process.runSync('cp', ['-r', fPath, dirPath]);
}

String escapeStringForHTML(String content) {
  HtmlEscape escaper = new HtmlEscape();
  return escaper.convert(content);
}
