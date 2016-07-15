# mdtest: Multi-Device Applicatoin Testing Framework

mdtest is a command line tool built on top of [flutter](https://flutter.io/) for
integration testing.  The tool wraps several flutter commands and implements
algorithms to deliver a robust end to end testing experience for multi-device
applications.  The tool is targeted for flutter apps and provides a public
wrapper of flutter driver API to allow testers write portable test scripts
across platforms.

# Requirements:

* OS
 - Linux (64 bit)
 - Mac OS X (64 bit)
 
* Tools
 - [Dart](https://www.dartlang.org/): must be installed and accessible from
   `PATH`
 - PUB: comes with Dart
 - [Flutter](https://flutter.io/): must be installed and accessible from `PATH`.
   `flutter doctor` should report no error
 - [ADB](http://developer.android.com/tools/help/adb.html): must be installed
   and accessible from `PATH`

# Installing mdtest

## Clone from Github

To get mdtest, use `git` to clone the [baku](https://github.com/vanadium/baku)
repository and then add the `mdtest` tool to `PATH`
```
$ git clone git@github.com:vanadium/baku.git
$ export PATH="$(pwd)/mdtest/bin:$PATH"
```
Open mdtest/pubspec.yaml file and make the following change:
 - replace
 ```
 dlog:
   path: ../../../../third_party/dart/dlog
 ```
 with
 ```
 dlog:
 ```
 - replace
 ```
 flutter_driver:
   path: ../deps/flutter/packages/flutter_driver
 ```
 with
 ```
 flutter_driver:
   path: ${path/to/flutter}/packages/flutter_driver
 ```

The first time you run the `mdtest` command, it will build the tool ifself.  If
you see Build Success, then `mdtest` is ready to go.

# Quick Start

This section introduces main features of `mdtest`.

## Test Spec

`mdtest` uses a test spec to initialize the test runs.  The test spec is in JSON
format and should follow the style below:
```
{
  "test-paths": [
    "${path/to/test_script1.dart}",
    "${path/to/test_script2.dart}",
    ...
  ],
  "devices": {
    "${device_nickname1}": {
      "device-id": "${device_id}",
      "model-name": "${device_model_name}",
      "screen-size": "${screen_size}",
      "app-root": "${path/to/flutter/app}",
      "app-path": "${path/to/instrumented/app.dart}"
    },
    "${device_nickname2}": {
      ...
    }
  }
}
```

All paths in the test spec should either be either absolute paths or paths
relative to the test spec file.  The "test-paths" attribute is optional if you
specify the test script path(s) from the command line when invoking `mdtest`.
But you should at least specify a test path from either the test spec or the
command line, otherwise `mdtest` will complain.  "devices" attribute is required
in the test spec.  You can list a number of device specs inside "devices"
attribute.  Each device spec has a unique "$device_nickname" mapping to several
device/application properties.  The "device-id" property is optional and should
map to the device id if set.  The "model-name" property is optional and should
map to the device model name if set.  The "screen-size" property is optional and
the allowed values are
["small"(<3.5), "normal"(>=3.5 && <5), "large"(>=5 && <8), "xlarge"(>=8)] where
the size is measured by screen diagonal by inch.  The screen size generally
follows
[Android Screen Support](https://developer.android.com/guide/practices/screens_support.html)
but resolve the overlapping confusion.  The "app-root" attribute specifies the
path to the flutter app which you want to run on that device.  The "app-path"
attribute points to the instrumented flutter app that uses flutter driver
plugin.  For more information, please see
[flutter integration testing](https://flutter.io/testing/#integration-testing).
You can always specify more device specs by repeatedly adding more attributes.

## Commands

Currently, `mdtest` supports two commands: `run` and `auto`.

### Run

`mdtest run` command is used to run test suite(s) on devices that mdtest finds
according to the test spec.

To build mdtest in a specific
revision in the git history, simply checkout that revision and run mdtest.
