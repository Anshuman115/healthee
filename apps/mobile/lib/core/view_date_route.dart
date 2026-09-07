/// The selected day, kept in the route — one redirect, in both directions.
///
/// `data/store/view_date.dart` already owns *what day is being read*, and this
/// file does not duplicate any of it. It owns the much smaller question of how
/// that selection reaches, and survives in, the URL:
///
/// ```text
///   a link in  →  ?date=2026-07-29  →  ViewDate.select      (route wins once)
///   the control →  ViewDate.state   →  ?date=2026-07-29     (state wins after)
/// ```
///
/// ## Why a redirect rather than a listener per screen
///
/// The day is global view state — the prototype's parameter survives a tab
/// switch (`docs/V02_CONNECTIVITY.md` section 0) — so every navigation has to
/// carry it, including the ones nobody wrote for it: the tab bar's five `go`s,
/// every `push` from a panel's Details link, a restored stack, a deep link.
/// Threading a day through those call sites would be a rule enforced by memory,
/// and the first caller to forget it would drop the day silently.
///
/// `GoRouter.redirect` runs on **every** navigation, before anything is built,
/// and it is allowed to answer with a different location. So one function
/// rewrites the URL from the selection, and `buildRouter` bumps its refresh
/// listenable when the selection moves — which makes the control's tap a
/// navigation, and the URL correct without any screen knowing it exists.
///
/// ## The route may name a day; it may not name one this phone has pruned
///
/// A day inside the retention window is adopted. A day outside it — a bookmark
/// kept past the horizon, a hand-typed link, a notification built from a stale
/// payload — is **not**: the URL is rewritten back to the day actually on
/// screen, so the address bar and the header cannot disagree. Clamping was the
/// alternative and it is worse in the same way `ViewDate.select` says: it
/// answers a request for one day with a different day, under a date nobody
/// chose.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/routes.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/store/view_date.dart';

/// Where [state] should actually go, so the URL and the selection agree.
///
/// Null means "as asked". Non-null is the corrected location, which go_router
/// then re-runs this against — the second pass finds nothing to change and
/// stops, so the redirect never loops.
String? viewDateRedirect(WidgetRef ref, GoRouterState state) {
  final String location = state.uri.toString();
  if (!isDateAwareRoute(state.uri.path)) {
    return null;
  }
  final String latest = ref.read(todayProvider);
  final String selected = ref.read(viewDateProvider);
  final String? requested = viewDateOf(state.uri);
  // The link chose a day this phone can still answer for, so the link wins —
  // once. Applied off the routing pass, because a provider written while
  // go_router is resolving a location is a state change during a build.
  if (requested != null &&
      requested != selected &&
      isViewableDay(requested, latest)) {
    scheduleMicrotask(
      () => ref.read(viewDateProvider.notifier).select(requested),
    );
    return null;
  }
  final String wanted = dateLocation(location, selected, latest);
  return wanted == location ? null : wanted;
}
