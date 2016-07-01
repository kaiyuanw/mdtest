// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

int minLength(List<String> elements) {
  if (elements == null || elements.isEmpty) return -1;
  int minLength = elements[0].length;
  for (String element in elements) {
    if (minLength > element.length)
      minLength = element.length;
  }
  return minLength;
}

int beginOfDiff(List<String> elements) {
  int minL = minLength(elements);
  for (int i = 0; i <  minL; i++) {
    String letter = elements[0][i];
    for (String element in elements) {
      if (letter != element[i]) {
        return i;
      }
    }
  }
  return minL;
}
