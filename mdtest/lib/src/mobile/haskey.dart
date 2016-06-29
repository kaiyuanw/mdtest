// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

abstract class HasKey {
  String clusterKey();
}

Map<String, List<dynamic>> buildCluster(List<dynamic> elements) {
  Map<String, List<dynamic>> clusters = <String, List<dynamic>>{};
  for (dynamic element in elements) {
    String key = element.clusterKey();
    if (!clusters.containsKey(key)) {
      List<dynamic> cluster = <dynamic>[];
      cluster.add(element);
      clusters[key] = cluster;
    } else {
      clusters[key].add(element);
    }
  }
  return clusters;
}
