import 'package:flutter_driver/driver_extension.dart';
import 'package:chat/main.dart' as chatapp;

void main() {
  enableFlutterDriverExtension();
  chatapp.start('Alice', 0);
}
