// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

abstract class HasKey {
  String clusterKey();
}

Map<String, List<HasKey>> buildCluster(List<HasKey> elements) {
  Map<String, List<HasKey>> clusters = <String, List<HasKey>>{};
  for (HasKey element in elements) {
    String key = element.clusterKey();
    if (!clusters.containsKey(key)) {
      List<HasKey> cluster = <HasKey>[];
      cluster.add(element);
      clusters[key] = cluster;
    } else {
      clusters[key].add(element);
    }
  }
  return clusters;
}
