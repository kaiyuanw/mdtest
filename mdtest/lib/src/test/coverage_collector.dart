// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:coverage/coverage.dart';
import 'package:path/path.dart' as path;

import '../globals.dart';

class CoverageCollector {
  List<Future<Null>> _jobs = <Future<Null>>[];
  Map<String, dynamic> _globalHitmap;

  void collectCoverage(String observatoryUrl) {
    RegExp urlPattern = new RegExp(r'http://(.*):(\d+)');
    Match urlMatcher = urlPattern.firstMatch(observatoryUrl);
    if (urlMatcher == null) {
      printError('Cannot parse host name and port '
                 'from observatory url $observatoryUrl');
      return;
    }
    String host = urlMatcher.group(1);
    int port = int.parse(urlMatcher.group(2));
    print('XXXX: Host $host, port $port');
    _jobs.add(_startJob(
      host: host,
      port: port
    ));
  }

  Future<Null> _startJob({
    String host,
    int port
  }) async {
    print('XXXX: Collect data from dart vm');
    Map<String, dynamic> data = await collect(host, port, false, false);
    print('XXXX: Create hitmap');
    Map<String, dynamic> hitmap = createHitmap(data['coverage']);
    if (_globalHitmap == null) {
      print('XXXX: No hitmap before, assign it to global hitmap');
      _globalHitmap = hitmap;
      print(_globalHitmap);
    } else {
      print('XXXX: Merge hitmap to global hitmap');
      mergeHitmaps(hitmap, _globalHitmap);
    }
  }

  Future<Null> finishPendingJobs() async {
    await Future.wait(_jobs.toList(), eagerError: true).catchError((e) {
      print('Error: ${e.error}');
    });
  }

  Future<String> finalizeCoverage(String appRootPath) async {
    if (_globalHitmap == null)
      return null;
    Resolver resolver
    = new Resolver(packagesPath: path.join(appRootPath, '.packages'));
    LcovFormatter formatter = new LcovFormatter(resolver);
    List<String> reportOn = <String>[path.join(appRootPath, 'lib')];
    return await formatter.format(
      _globalHitmap,
      reportOn: reportOn,
      basePath: appRootPath
    );
  }
}
