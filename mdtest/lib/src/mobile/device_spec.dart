// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'device.dart';

class DeviceSpecs {
  DeviceSpecs(
    {
      this.nickName,
      this.deviceID,
      this.deviceModelName,
      this.appRootPath,
      this.appPath,
      this.observatoryPort
    }
  );

  final String nickName;
  final String deviceID;
  final String deviceModelName;
  final String appRootPath;
  final String appPath;
  String observatoryPort;

  bool matches(Device device) {
    if(deviceID == device.id) {
      return deviceModelName == null ?
               true : deviceModelName == device.modelName;
    } else {
      return deviceID == null ?
               (deviceModelName == null ?
                 true : deviceModelName == device.modelName)
               : false;
    }
  }

  @override
  String toString() => '<nickname: $nickName, iD: $deviceID, '
                       'model name: $deviceModelName, port: $observatoryPort>';
}
