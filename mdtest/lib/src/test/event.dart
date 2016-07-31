// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

import '../util.dart';


abstract class Event {
  String name;
  bool skip;
  String skipReason;

  Event(this.name, this.skip, this.skipReason);

  Map toJson();

  int skipNum();
  int failNum();
  int passNum();

  @override
  String toString() {
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

class TestEvent extends Event {
  // // Known at TestStartEvent
  int directParentGroupID;
  // Known at ErrorEvent
  bool error;
  String errorReason;
  // Known at TestDoneEvents
  String result;
  bool hidden;

  TestEvent(String name, this.directParentGroupID, bool skip, String skipReason)
    : super(name, skip, skipReason) {
    this.error = false;
  }

  void fillError(String errorReason) {
    this.error = true;
    this.errorReason = errorReason;
  }

  @override
  int skipNum() {
    return skip ? 1 : 0;
  }

  @override
  int failNum() {
    if (skip) {
      return 0;
    }
    return error ? 1 : 0;
  }

  @override
  int passNum() {
    if (skip) {
      return 0;
    }
    return error ? 0 : 1;
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
  List<TestEvent> testsInGroup;

  GroupEvent(String name, bool skip, String skipReason)
    : super(name, skip, skipReason) {
    this.testsInGroup = <TestEvent>[];
  }

  void addTestEvent(TestEvent testEvent) {
    testsInGroup.add(testEvent);
  }

  @override
  int skipNum() {
    return skip ? 0 : sum(testsInGroup.map((TestEvent e) => e.skipNum()));
  }

  @override
  int failNum() {
    return skip ? 0 : sum(testsInGroup.map((TestEvent e) => e.failNum()));
  }

  @override
  int passNum() {
    return skip ? 0 : sum(testsInGroup.map((TestEvent e) => e.passNum()));
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = <String, dynamic>{};
    map['name'] = name;
    if (skip) {
      map['status'] = 'skip';
      map['reason'] = skipReason;
      return map;
    }
    int failures = failNum();
    if (failures > 0) {
      map['status'] = 'fail';
    } else {
      map['status'] = 'pass';
    }
    map['skip-num'] = skipNum();
    map['fail-num'] = failures;
    map['pass-num'] = passNum();
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

  int skipNum() {
    return sum(events.map((Event e) => e.skipNum()));
  }

  int failNum() {
    return sum(events.map((Event e) => e.failNum()));
  }

  int passNum() {
    return sum(events.map((Event e) => e.passNum()));
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = <String, dynamic>{};
    map['name'] = name;
    map['skip-num'] = skipNum();
    map['fail-num'] = failNum();
    map['pass-num'] = passNum();
    map['status'] = map['fail-num'] > 0 ? 'fail' : 'pass';
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
