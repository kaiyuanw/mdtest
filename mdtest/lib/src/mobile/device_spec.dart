import 'device.dart';

class DeviceSpecs {
  DeviceSpecs(
    {
      this.nickName,
      this.deviceID,
      this.deviceModelName,
      this.appRootPath,
      this.appPath
    }
  );

  final String nickName;
  final String deviceID;
  final String deviceModelName;
  final String appRootPath;
  final String appPath;

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
  String toString() => 'Nickname: $nickName, Target ID: $deviceID, '
                       'Target Model Name: $deviceModelName';
}
