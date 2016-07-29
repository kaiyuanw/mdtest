// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import '../globals.dart';

class TAPReporter {
  int currentTestNum;
  int passingTestsNum;
  Map<int, TestEvent> testEventMapping;
  String currentTestPath;
  List<TestSuite> suites;

  TAPReporter() {
    this.currentTestNum = 0;
    this.passingTestsNum = 0;
    this.testEventMapping = <int, TestEvent>{};
    this.suites = <TestSuite>[];
  }

  void printHeader() {
    print(
      '\n'
      'TAP version 13'
    );
  }

  Future<bool> report(String testScriptPath, Stream jsonOutput) async {
    currentTestPath = testScriptPath;
    suites.add(new TestSuite(testScriptPath));
    bool hasTestOutput = false;
    await for (var line in jsonOutput) {
      convertToTAPFormat(line.toString().trim());
      hasTestOutput = true;
    }
    suites.last.events.where(
      (Event e) => e is GroupEvent
    ).forEach(
      (GroupEvent e) => e.detectError()
    );
    return hasTestOutput;
  }

  void printSummary() {
    print(
      '\n'
      '1..$currentTestNum\n'
      '# tests $currentTestNum\n'
      '# pass $passingTestsNum\n'
    );
  }

  void convertToTAPFormat(var jsonLine) {
    if (jsonLine == null)
      return;
    dynamic event;
    try {
      event = JSON.decode(jsonLine);
    } on FormatException {
      printError('File ${jsonLine.toString()} is not in JSON format.');
      return;
    }

    TestSuite lastSuite = suites.last;

    if (_isGroupEvent(event) && !_isGroupRootEvent(event)) {
      dynamic groupInfo = event['group'];
      String name = groupInfo['name'];
      bool skip = groupInfo['metadata']['skip'];
      String skipReason = groupInfo['metadata']['skipReason'] ?? '';
      if (skip) {
        print('# skip ${groupInfo['name']} $skipReason');
      } else {
        print('# ${groupInfo['name']}');
      }
      lastSuite.addEvent(new GroupEvent(name, skip, skipReason));
    } else if (_isTestStartEvent(event)) {
      dynamic testInfo = event['test'];
      int testID = testInfo['id'];
      String name = testInfo['name'];
      bool skip = testInfo['metadata']['skip'];
      String skipReason = testInfo['metadata']['skipReason'] ?? '';
      testEventMapping[testID] = new TestEvent(name, skip, skipReason);
    } else if (_isErrorEvent(event)) {
      int testID = event['testID'];
      TestEvent testEvent = testEventMapping[testID];
      String errorReason = event['error'];
      testEvent.fillError(errorReason);
    } else if (_isTestDoneEvent(event)) {
      int testID = event['testID'];
      TestEvent testEvent = testEventMapping[testID];
      testEvent.hidden = event['hidden'];
      testEvent.result = event['result'];
      printTestResult(testEvent);
      if (testEvent.hidden) {
        return;
      }
      if (lastSuite.events.isEmpty) {
        lastSuite.addEvent(testEvent);
      } else {
        Event lastEvent = lastSuite.events.last;
        if (lastEvent is TestEvent) {
          lastSuite.addEvent(testEvent);
        } else if (lastEvent is GroupEvent) {
          GroupEvent lastGroupEvent = lastEvent;
          lastGroupEvent.addTestEvent(testEvent);
        } else {
          printError(
            'Unrecognized event type ${lastEvent.runtimeType} in ${lastSuite.events}'
          );
        }
      }
    }
  }

  bool _isGroupEvent(dynamic event) {
    return event['type'] == 'group';
  }

  bool _isGroupRootEvent(dynamic event) {
    dynamic groupInfo = event['group'];
    return _isGroupEvent(event)
           &&
           groupInfo['name'] == null
           &&
           groupInfo['parentID'] == null;
  }

  bool _isTestStartEvent(dynamic event) {
    return event['type'] == 'testStart';
  }

  bool _isErrorEvent(dynamic event) {
    return event['type'] == 'error';
  }

  bool _isTestDoneEvent(dynamic event) {
    return event['type'] == 'testDone';
  }

  void printTestResult(TestEvent event) {
    if (event.hidden)
      return;
    if (event.result != 'success') {
      if (event.error) {
        print('not ok ${++currentTestNum} - ${event.name}');
        String tab = '${' ' * 2}';
        // Print error message
        event.errorReason.split('\n').forEach((String line) {
          print('$tab$line');
        });
        return;
      }
      print('not ok ${++currentTestNum} - ${event.name}');
      return;
    }
    if (event.skip) {
      print('ok ${++currentTestNum} - # SKIP ${event.skipReason}');
    }
    print('ok ${++currentTestNum} - ${event.name}');
    passingTestsNum++;
  }

  String dumpToJSONString() {
    dynamic map = suites.map((TestSuite suite) => suite.toJson()).toList();
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }
}

abstract class Event {
  String name;
  bool skip;
  String skipReason;
  bool error;

  Event(this.name, this.skip, this.skipReason);

  Map toJson();

  @override
  String toString() {
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

class TestEvent extends Event {
  // // Known at TestStartEvent
  // String name;
  // bool skip;
  // String skipReason;
  // // Known at ErrorEvent
  // bool error;
  String errorReason;
  // Known at TestDoneEvents
  String result;
  bool hidden;

  TestEvent(String name, bool skip, String skipReason)
    : super(name, skip, skipReason) {
    this.error = false;
  }

  void fillError(String errorReason) {
    this.error = true;
    this.errorReason = errorReason;
  }

  @override
  Map<String, String> toJson() {
    Map<String, String> map = <String, String>{};
    map['name'] = name;
    if (skip) {
      map['status'] = 'skip';
      map['reason'] = skipReason;
    } else {
      if (error) {
        map['status'] = 'error';
        map['reason'] = errorReason;
      } else {
        map['status'] = 'pass';
      }
    }
    map['result'] = result;
    return map;
  }
}


class GroupEvent extends Event {
  // // Known at GroupEvent
  // String name;
  // bool skip;
  // String skipReason;
  // // Known after all TestDoneEvents in this group are emitted
  // bool error;

  List<TestEvent> testsInGroup;

  GroupEvent(String name, bool skip, String skipReason)
    : super(name, skip, skipReason) {
    this.testsInGroup = <TestEvent>[];
  }

  void addTestEvent(TestEvent testEvent) {
    testsInGroup.add(testEvent);
  }

  void detectError() {
    for (TestEvent testInGroup in testsInGroup) {
      if (testInGroup.error) {
        this.error = true;
        return;
      }
    }
    this.error = false;
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = <String, dynamic>{};
    map['name'] = name;
    if (skip) {
      map['status'] = 'skip';
      map['reason'] = skipReason;
    } else {
      if (error) {
        map['status'] = 'error';
      } else {
        map['status'] = 'pass';
      }
    }
    map['tests'] = testsInGroup.map(
      (TestEvent e) => e.toJson()
    ).toList();
    return map;
  }
}

class TestSuite {
  String name;
  List<Event> events;

  TestSuite(this.name) {
    this.events = <Event>[];
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = <String, dynamic>{};
    map['name'] = name;
    map['details'] = events.map((Event e) => e.toJson()).toList();
    return map;
  }

  void addEvent(Event event) {
    events.add(event);
  }

  @override
  String toString() {
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
