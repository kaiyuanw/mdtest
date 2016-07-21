// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:intl/intl.dart';
import 'package:dlog/dlog.dart' show Table;

import '../mobile/device.dart' show Device;
import '../mobile/device_spec.dart' show DeviceSpec;
import '../util.dart';

class GroupInfo {
  Map<String, List<Device>> _deviceClusters;
  Map<String, List<DeviceSpec>> _deviceSpecClusters;
  List<String> _deviceClustersOrder;
  List<String> _deviceSpecClustersOrder;

  GroupInfo(
    Map<String, List<Device>> deviceClusters,
    Map<String, List<DeviceSpec>> deviceSpecClusters
  ) {
    _deviceClusters = deviceClusters;
    _deviceSpecClusters = deviceSpecClusters;
    _deviceClustersOrder = new List.from(_deviceClusters.keys);
    _deviceSpecClustersOrder = new List.from(_deviceSpecClusters.keys);
  }

  Map<String, List<Device>> get deviceClusters => _deviceClusters;
  Map<String, List<DeviceSpec>> get deviceSpecClusters => _deviceSpecClusters;
  List<String> get deviceClustersOrder => _deviceClustersOrder;
  List<String> get deviceSpecClustersOrder => _deviceSpecClustersOrder;
}

// indicate that an app-device path can never be covered given the available
// devices
const int cannotBeCovered = -1;

// indicate that an app-device path can be covered, but not covered yet.  No
// test script is run under this setting
const int isNotCovered = 0;

// indicate that an app-device path is covered, but some test script fails under
// this setting
const int isCoveredFailed = 1;

// indicate that an app-device path is covered, and all test scripts pass under
// this setting
const int isCoveredPassed = 2;

class CoverageMatrix {

  CoverageMatrix(this.groupInfo) {
    this.matrix = new List<List<int>>(groupInfo.deviceSpecClusters.length);
    for (int i = 0; i < matrix.length; i++) {
      matrix[i] = new List<int>.filled(groupInfo.deviceClusters.length, -1);
    }
  }

  GroupInfo groupInfo;
  // Coverage matrix, where a row indicats an app group and a column
  // indicates a device group
  List<List<int>> matrix;

  void fill(Map<DeviceSpec, Device> match, int value) {
    match.forEach((DeviceSpec spec, Device device) {
      int rowNum = groupInfo.deviceSpecClustersOrder
                              .indexOf(spec.groupKey());
      int colNum = groupInfo.deviceClustersOrder
                              .indexOf(device.groupKey());
      matrix[rowNum][colNum] = value;
    });
  }

  void union(CoverageMatrix newCoverage) {
    for (int i = 0; i < matrix.length; i++) {
      List<int> row = matrix[i];
      for (int j = 0; j < row.length; j++) {
        matrix[i][j] |= newCoverage.matrix[i][j];
      }
    }
  }

  /// Compute and print the app-device coverage.
  static void computeAndReportCoverage(CoverageMatrix coverageMatrix) {
    if (coverageMatrix == null) {
      return;
    }
    int countNumberInCoverageMatrix(List<List<int>> matrix, bool test(int e)) {
      int result = 0;
      matrix.forEach((List<int> row) {
        result += row.where((int element) => test(element)).length;
      });
      return result;
    }
    List<List<int>> matrix = coverageMatrix.matrix;
    int rowNum = matrix.length;
    int colNum = matrix[0].length;
    int totalPathNum = rowNum * colNum;
    int reachableCombinationNum
      = countNumberInCoverageMatrix(matrix, (int e) => e != cannotBeCovered);
    int coveredFailedCombinationNum
      = countNumberInCoverageMatrix(matrix, (int e) => e == isCoveredFailed);
    int coveredPassedCombinationNum
      = countNumberInCoverageMatrix(matrix, (int e) => e == isCoveredPassed);
    int coveredCombinationNum
      = coveredFailedCombinationNum + coveredPassedCombinationNum;
    NumberFormat percentFormat = new NumberFormat('%##.0#', 'en_US');
    print('App-Device Path Coverage = ADPC');
    double reachableCoverageScore = reachableCombinationNum / totalPathNum;
    print('Reachable ADPC score: ${percentFormat.format(reachableCoverageScore)}');
    double coveredCoverageScore
      = coveredCombinationNum / reachableCombinationNum;
    print('Covered ADPC score: ${percentFormat.format(coveredCoverageScore)}');
    double coveredSuccessCovergeScore
      = coveredPassedCombinationNum / coveredCombinationNum;
    print('Passed ADPC score: ${percentFormat.format(coveredSuccessCovergeScore)}');
  }

  static void printLegend() {
    StringBuffer sb = new StringBuffer();
    sb.writeln('Meaning of the number in the coverage matrix:');
    sb.writeln('$cannotBeCovered: an app-device path is not reachable');
    sb.writeln('$isNotCovered: an app-device path is reachable but not covered');
    sb.writeln('$isCoveredFailed: an app-device path is covered, but some test fails');
    sb.writeln('$isCoveredPassed: an app-device path is covered, and all tests pass');
    print(sb.toString());
  }

  static void printMatrix(CoverageMatrix coverageMatrix) {
    if (coverageMatrix == null) {
      return;
    }
    GroupInfo groupInfo = coverageMatrix.groupInfo;
    List<List<int>> matrix = coverageMatrix.matrix;
    Table prettyMatrix = new Table(1);
    prettyMatrix.columns.add('app key \\ device key');
    prettyMatrix.columns.addAll(groupInfo.deviceClustersOrder);
    int startIndx = beginOfDiff(groupInfo.deviceSpecClustersOrder);
    for (int i = 0; i < matrix.length; i++) {
      prettyMatrix.data.add(groupInfo.deviceSpecClustersOrder[i].substring(startIndx));
      prettyMatrix.data.addAll(matrix[i]);
    }
    print(prettyMatrix);
  }
}

Map<CoverageMatrix, Map<DeviceSpec, Device>> buildCoverage2MatchMapping(
  List<Map<DeviceSpec, Device>> allMatches,
  GroupInfo groupInfo
) {
  Map<CoverageMatrix, Map<DeviceSpec, Device>> cov2match
    = <CoverageMatrix, Map<DeviceSpec, Device>>{};
  for (Map<DeviceSpec, Device> match in allMatches) {
    CoverageMatrix cov = new CoverageMatrix(groupInfo);
    cov.fill(match, isNotCovered);
    cov2match[cov] = match;
  }
  return cov2match;
}

/// Find a small number of mappings which cover the maximum app-device coverage
/// feasible in given the available devices and specs.  The problem can be
/// treated as a set cover problem which is NP-complete and the implementation
/// follow the spirit of greedy algorithm which is O(log(n)).
/// [ref link]: https://en.wikipedia.org/wiki/Set_cover_problem
Set<Map<DeviceSpec, Device>> findMinimumMappings(
  Map<CoverageMatrix, Map<DeviceSpec, Device>> cov2match,
  CoverageMatrix base
) {
  Set<CoverageMatrix> minSet = new Set<CoverageMatrix>();
  while (true) {
    CoverageMatrix currentBestCoverage = null;
    int maxReward = 0;
    for (CoverageMatrix coverage in cov2match.keys) {
      if (minSet.contains(coverage)) continue;
      int reward = computeReward(base, coverage);
      if (maxReward < reward) {
        maxReward = reward;
        currentBestCoverage = coverage;
      }
    }
    if (currentBestCoverage == null) break;
    minSet.add(currentBestCoverage);
    base.union(currentBestCoverage);
  }
  print('Best coverage matrix:');
  CoverageMatrix.printMatrix(base);
  Set<Map<DeviceSpec, Device>> bestMatches = new Set<Map<DeviceSpec, Device>>();
  for (CoverageMatrix coverage in minSet) {
    bestMatches.add(cov2match[coverage]);
  }
  return bestMatches;
}

int computeReward(CoverageMatrix base, CoverageMatrix newCoverage) {
  int reward = 0;
  for (int i = 0; i < base.matrix.length; i++) {
    List<int> row = base.matrix[i];
    for (int j = 0; j < row.length; j++) {
      if (base.matrix[i][j] == cannotBeCovered
          &&
          newCoverage.matrix[i][j] == isNotCovered)
        reward++;
    }
  }
  return reward;
}
