// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'device.dart';
import 'key_provider.dart';
import '../globals.dart';
import '../util.dart';

class DeviceSpec implements ClusterKeyProvider {
  DeviceSpec(String nickname, { this.deviceSpec }) {
    deviceSpec['nickname'] = nickname;
  }

  Map<String, String> deviceSpec;

  String get nickName => deviceSpec['nickname'];
  String get deviceID => deviceSpec['device-id'];
  String get deviceModelName => deviceSpec['model-name'];
  String get deviceScreenSize => deviceSpec['screen-size'];
  String get appRootPath => deviceSpec['app-root'];
  String get appPath => deviceSpec['app-path'];
  String get observatoryUrl => deviceSpec['observatory-url'];
  void set observatoryUrl(String url) {
    deviceSpec['observatory-url'] = url;
  }

  /// Match if property names are not specified or equal to the device property.
  /// Checked property names includes: device-id, model-name, screen-size
  bool matches(Device device) {
    return isNullOrEqual('device-id', device)
           &&
           isNullOrEqual('model-name', device)
           &&
           isNullOrEqual('screen-size', device);
  }

  bool isNullOrEqual(String propertyName, Device device) {
    return deviceSpec[propertyName] == null
           ||
           deviceSpec[propertyName] == device.properties[propertyName];
  }

  @override
  String clusterKey() {
    return appPath;
  }

  @override
  String toString() => '<nickname: $nickName, '
                       'id: $deviceID, '
                       'model name: $deviceModelName, '
                       'screen size: $deviceScreenSize, '
                       'port: $observatoryUrl, '
                       'app path: $appPath>';
}

Future<dynamic> loadSpecs(String specsPath) async {
  try {
    // Read specs file into json format
    dynamic newSpecs = JSON.decode(await new File(specsPath).readAsString());
    // Get the parent directory of the specs file
    String rootPath = new File(specsPath).parent.absolute.path;
    // Normalize the 'test-path' in the specs file
    newSpecs['test-path'] = normalizePath(rootPath, newSpecs['test-path']);
    // Normalize the 'app-path' in the specs file
    newSpecs['devices'].forEach((String name, Map<String, String> map) {
      map['app-path'] = normalizePath(rootPath, map['app-path']);
      map['app-root'] = normalizePath(rootPath, map['app-root']);
    });
    return newSpecs;
  } on FileSystemException {
    printError('File $specsPath does not exist.');
    exit(1);
  } on FormatException {
    printError('File $specsPath is not in JSON format.');
    exit(1);
  } catch (e) {
    print('Unknown Exception details:\n $e');
    exit(1);
  }
}

/// Build a list of device specs from mappings loaded from JSON .spec file
Future<List<DeviceSpec>> constructAllDeviceSpecs(dynamic allSpecs) async {
  List<DeviceSpec> deviceSpecs = <DeviceSpec>[];
  for(String name in allSpecs.keys) {
    Map<String, String> spec = allSpecs[name];
    deviceSpecs.add(
      new DeviceSpec(
        name,
        deviceSpec: spec
      )
    );
  }
  return deviceSpecs;
}
