// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of dart.sky;

/// List of predefined filter quality modes. This list comes from Skia's
/// SkFitlerQuality.h and the values (order) should be kept in sync.
enum FilterQuality {
  none,
  low,
  medium,
  high,
}
