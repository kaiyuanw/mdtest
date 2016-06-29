
import '../mobile/device.dart' show Device;
import '../mobile/device_spec.dart' show DeviceSpec;

Map<String, List<Device>> _deviceClusters;
Map<String, List<DeviceSpec>> _deviceSpecClusters;
List<String> _deviceClustersOrder;
List<String> _deviceSpecClustersOrder;

void init(Map<String, List<Device>> deviceClusters, Map<String, List<DeviceSpec>> deviceSpecClusters) {
  _deviceClusters = deviceClusters;
  _deviceSpecClusters = deviceSpecClusters;
  _deviceClustersOrder = new List.from(_deviceClusters.keys);
  _deviceSpecClustersOrder = new List.from(_deviceSpecClusters.keys);
}

void destroy() {
  _deviceClusters = null;
  _deviceSpecClusters = null;
  _deviceClustersOrder = null;
  _deviceSpecClustersOrder = null;
}

class Coverage {

  Coverage() {
    this.net = new List<List<int>>(_deviceSpecClusters.length);
    for (int i = 0; i < net.length; i++) {
      net[i] = new List<int>.filled(_deviceClusters.length, 0);
    }
  }

  List<List<int>> net;

  void fill(Map<DeviceSpec, Device> match) {
    match.forEach((DeviceSpec spec, Device device) {
      int rowNum = _deviceSpecClustersOrder.indexOf(spec.clusterKey());
      int colNum = _deviceClustersOrder.indexOf(device.clusterKey());
      net[rowNum][colNum] = 1;
    });
  }

  void union(Coverage newCoverage) {
    for (int i = 0; i < net.length; i++) {
      List<int> row = net[i];
      for (int j = 0; j < row.length; j++) {
        net[i][j] |= newCoverage.net[i][j];
      }
    }
  }

  void printNet() {
    StringBuffer sb = new StringBuffer();
    sb.writeln('==========');
    for (List<int> row in net) {
      String prefix = '';
      for (int col in row) {
        sb.write('$prefix $col');
        prefix = ',';
      }
      sb.writeln();
    }
    sb.write('==========');
    print(sb.toString());
  }
}

Map<Coverage, Map<DeviceSpec, Device>> buildCoverage2MatchMapping(
  List<Map<DeviceSpec, Device>> allMatches
) {
  Map<Coverage, Map<DeviceSpec, Device>> cov2match
    = <Coverage, Map<DeviceSpec, Device>>{};
  for (Map<DeviceSpec, Device> match in allMatches) {
    Coverage cov = new Coverage();
    cov.fill(match);
    cov2match[cov] = match;
  }
  return cov2match;
}

Set<Map<DeviceSpec, Device>> findMinimumMappings(
  Map<Coverage, Map<DeviceSpec, Device>> cov2match
) {
  Set<Coverage> minSet = new Set<Coverage>();
  Coverage base = new Coverage();
  while (true) {
    Coverage currentBestCoverage = null;
    int maxReward = 0;
    for (Coverage coverage in cov2match.keys) {
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
  print('Best Net:');
  base.printNet();
  Set<Map<DeviceSpec, Device>> bestMatches = new Set<Map<DeviceSpec, Device>>();
  for (Coverage coverage in minSet) {
    bestMatches.add(cov2match[coverage]);
  }
  return bestMatches;
}

int computeReward(Coverage base, Coverage newCoverage) {
  int reward = 0;
  for (int i = 0; i < base.net.length; i++) {
    List<int> row = base.net[i];
    for (int j = 0; j < row.length; j++) {
      if (base.net[i][j] == 0 && newCoverage.net[i][j] == 1)
        reward++;
    }
  }
  return reward;
}
