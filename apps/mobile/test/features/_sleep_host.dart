/// What the four Sleep suites share: a section list, and a phone to draw on.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_sections.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../_sleep_stubs.dart';

/// The widths a phone actually is. **Never 800**, which is `flutter test`'s
/// default and wider than any handset — this project has already shipped a card
/// that overflowed by 110 px behind exactly that default.
const List<double> kSleepWidths = <double>[320, 360, 390, 414];

/// The section list, built the way the screen builds it.
List<PageSection> sleepList({
  SleepPage? page,
  SleepConsistency? consistency,
  DateTime? now,
}) => sleepSections(
  page: page ?? sleepPageFixture(),
  consistency: consistency ?? consistencyFixture(),
  now: now ?? kSleepNow,
  reveals: RevealRegistry(),
);

/// The index of the first section whose child is a [T], or -1.
int indexOfSection<T>(List<PageSection> list) =>
    list.indexWhere((section) => section.child is T);

/// Every section's child type, as a set.
Set<Type> sectionTypes(List<PageSection> list) =>
    <Type>{for (final section in list) section.child.runtimeType};

/// One panel on a phone-width host, in the light theme.
///
/// Scrollable, because several of these panels are taller than a test's 600 px
/// viewport and a vertical overflow is not what any of them is about.
Widget sleepPanelHost(Widget panel, {double width = 390, ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: width, child: panel)),
        ),
      ),
    );

/// Loads the app's own typeface.
///
/// `flutter test` renders every glyph in a placeholder font whose characters are
/// all one em wide, so text measures about twice its real width and any claim
/// about a laid-out box would be a claim about the wrong box.
Future<void> loadSleepFont() async {
  final loader = FontLoader('Manrope');
  for (final weight in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Manrope-$weight.ttf').readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
