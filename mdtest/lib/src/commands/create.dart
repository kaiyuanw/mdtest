// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../runner/mdtest_command.dart';
import '../globals.dart';
import '../util.dart';

const String template =
'''
{
  "devices": {
    "{nickname}": {
      "device-id": "{optional}",
      "model-name": "{optional}",
      "os-version": "{optional}",
      "api-level": "{optional}",
      "screen-size": "{optional}",
      "app-root": "{required}",
      "app-path": "{required}"
    },
    "{nickname}": {
      "app-root": "{required}",
      "app-path": "{required}"
    }
  }
}
''';

const String guide =
'Everything in the curly braces can be replaced with your own value.\n'
'"device-id", "model-name", "os-version", "api-level" and "screem-size" '
'are optional.\n'
'"app-root" and "app-path" are required.\n'
'An example spec would be\n'
'''
{
  "devices": {
    "Alice": {
      "device-id": "HT4CWJT03204",
      "model-name": "Nexus 9",
      "os-version": "6.0",
      "api-level": "23",
      "screen-size": "xlarge",
      "app-root": "/path/to/flutter-app",
      "app-path": "/path/to/main.dart"
    },
    "Bob": {
      ...
    }
    ...
  }
}
'''
'"nickname" will refer to the device that runs your flutter app with the '
'device properties you provide in the test spec.\n'
'"device-id" is the unique id of your device.\n'
'"model-name" is the device model name.\n'
'"os-version" is the operating system version of your device.\n'
'"api-level" is Android specific and refers to the API level of your device.\n'
'"screen-size" is the screen diagonal size measured in inches.  The candidate '
'values are "small"(<3.5"), "normal"(>=3.5" && <5"), "large"(>=5" && <8") '
'and "xlarge"(>=8").\n'
'"app-root" is the path of your flutter application directory.\n'
'"app-path" is the path of the instrumented version of your app main function.\n'
;

class CreateCommand extends MDTestCommand {

  @override
  final String name = 'create';

  @override
  final String description = 'create a test spec template for the user to fill in';

  @override
  Future<int> runCore() async {
    printInfo('Running "mdtest create command" ...');
    String targetPath = argResults['target'];
    assert(!FileSystemEntity.isDirectorySync(targetPath));

    File file = createNewFile('$targetPath');
    file.writeAsStringSync(template);
    String absolutePath = normalizePath(Directory.current.path, targetPath);
    printInfo('Template test spec written to $absolutePath');

    printSpecGuide();
    return 0;
  }

  void printSpecGuide() {
    guide.split('\n').forEach((String line) => printInfo(line));
  }

  CreateCommand() {
    usesTargetOption();
  }
}
