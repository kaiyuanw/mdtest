// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'coverage_test.dart' as coverage_test;
import 'device_spec_test.dart' as device_spec_test;
import 'group_test.dart' as group_test;
import 'matching_test.dart' as matching_test;

void main() {
  coverage_test.main();
  device_spec_test.main();
  group_test.main();
  matching_test.main();
}
