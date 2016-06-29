// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../base/common.dart';
import '../mobile/device.dart';
import '../mobile/device_spec.dart';

/// Find all matched devices for each device spec
Map<DeviceSpec, Set<Device>> findIndividualMatches(
  List<DeviceSpec> deviceSpecs,
  List<Device> devices) {
  Map<DeviceSpec, Set<Device>> individualMatches
    = new Map<DeviceSpec, Set<Device>>();
  for(DeviceSpec deviceSpecs in deviceSpecs) {
    Set<Device> matchedDevices = new Set<Device>();
    for(Device device in devices) {
      if(deviceSpecs.matches(device))
        matchedDevices.add(device);
    }
    individualMatches[deviceSpecs] = matchedDevices;
  }
  return individualMatches;
}

/// Return the first device spec to device matching, null if no such matching
Map<DeviceSpec, Device> findMatchingDeviceMapping(
  List<DeviceSpec> deviceSpecs,
  Map<DeviceSpec, Set<Device>> individualMatches) {
  Map<DeviceSpec, Device> deviceMapping = <DeviceSpec, Device>{};
  Set<Device> visited = new Set<Device>();
  if (!_findMatchingDeviceMapping(0, deviceSpecs, individualMatches,
                                  visited, deviceMapping)) {
    return null;
  }
  return deviceMapping;
}

/// Find a mapping that matches every device spec to a device. If such
/// mapping is not found, return false, otherwise return true.
bool _findMatchingDeviceMapping(
  int order,
  List<DeviceSpec> deviceSpecs,
  Map<DeviceSpec, Set<Device>> individualMatches,
  Set<Device> visited,
  Map<DeviceSpec, Device> deviceMapping
) {
  if(order == deviceSpecs.length) return true;
  DeviceSpec deviceSpec = deviceSpecs[order];
  Set<Device> matchedDevices = individualMatches[deviceSpec];
  for(Device candidate in matchedDevices) {
    if(visited.add(candidate)) {
      deviceMapping[deviceSpec] = candidate;
      if(_findMatchingDeviceMapping(order + 1, deviceSpecs, individualMatches,
                                    visited, deviceMapping))
        return true;
      else {
        visited.remove(candidate);
        deviceMapping.remove(deviceSpec);
      }
    }
  }
  return false;
}

/// Store the specs to device mapping as a system temporary file.  The file
/// stores device nickname as well as device id and observatory port for
/// each device
Future<Null> storeMatches(Map<DeviceSpec, Device> deviceMapping) async {
  Map<String, dynamic> matchesData = new Map<String, dynamic>();
  deviceMapping.forEach((DeviceSpec specs, Device device) {
    Map<String, String> idAndPort = new Map<String, String>();
    idAndPort['device-id'] = device.id;
    idAndPort['observatory-port'] = specs.observatoryPort;
    matchesData[specs.nickName] =
    {
      'device-id': device.id,
      'observatory-port': specs.observatoryPort
    };
  });
  Directory systemTempDir = Directory.systemTemp;
  File tempFile = new File('${systemTempDir.path}/$defaultTempSpecsName');
  if(await tempFile.exists())
    await tempFile.delete();
  File file = await tempFile.create();
  await file.writeAsString(JSON.encode(matchesData));
}

List<Map<DeviceSpec, Device>> findAllMatchingDeviceMappings(
  List<DeviceSpec> deviceSpecs,
  Map<DeviceSpec, Set<Device>> individualMatches) {
  Map<DeviceSpec, Device> deviceMapping = <DeviceSpec, Device>{};
  Set<Device> visited = new Set<Device>();
  bool foundAllMatches = false;
  List<Map<DeviceSpec, Device>> allMatches = <Map<DeviceSpec, Device>>[];
  _findAllMatchingDeviceMappings(
    0, deviceSpecs, individualMatches,
    visited, deviceMapping, foundAllMatches, allMatches
  );
  if (!foundAllMatches) {
    return null;
  }
  return allMatches;
}

bool _findAllMatchingDeviceMappings(
  int order,
  List<DeviceSpec> deviceSpecs,
  Map<DeviceSpec, Set<Device>> individualMatches,
  Set<Device> visited,
  Map<DeviceSpec, Device> deviceMapping,
  bool foundAllMatches,
  List<Map<DeviceSpec, Device>> allMatches
) {
  if(order == deviceSpecs.length) {
    foundAllMatches = true;
    return true;
  }
  DeviceSpec deviceSpec = deviceSpecs[order];
  Set<Device> matchedDevices = individualMatches[deviceSpec];
  for(Device candidate in matchedDevices) {
    if(visited.add(candidate)) {
      deviceMapping[deviceSpec] = candidate;
      if(_findAllMatchingDeviceMappings(
        order + 1, deviceSpecs, individualMatches,
        visited, deviceMapping, foundAllMatches, allMatches)) {
        allMatches.add(mappingCopy(deviceMapping));
      }
      visited.remove(candidate);
      deviceMapping.remove(deviceSpec);
    }
  }
  return false;
}

Map<DeviceSpec, Device> mappingCopy(Map<DeviceSpec, Device> original) {
  Map<DeviceSpec, Device> copy = <DeviceSpec, Device>{};
  original.forEach((DeviceSpec spec, Device device) {
    copy[spec] = device;
  });
  return copy;
}

void printMatches(Iterable<Map<DeviceSpec, Device>> matches) {
  StringBuffer sb = new StringBuffer();
  int roundNum = 0;
  sb.writeln('**********');
  for (Map<DeviceSpec, Device> match in matches) {
    sb.writeln('Round $roundNum:');
    match.forEach((DeviceSpec spec, Device device) {
      sb.writeln('$spec -> $device');
    });
  }
  sb.write('**********');
  print(sb.toString());
}
