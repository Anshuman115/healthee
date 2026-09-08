/// `#route` — one recorded track, on the v02 detail frame.
///
/// `screens-explore.js::H.screens.route`, in order: the detail header, the
/// schematic map, a card of Distance · Duration · Avg. pace over its source
/// line, `Elevation along the way` (a scrubbable profile with gain and loss
/// under it), the heart-rate-coverage notice, `Record another route`, and the
/// footer.
///
/// Composition and wiring only; `route_detail_sections.dart` decides what is
/// shown and carries the argument for it, the way `workout_detail_screen.dart`
/// and `history_screen.dart` are split.
///
/// **Stateful for one field.** `RevealRegistry` must outlive the widget that
/// reads it, or the elevation chart replays its reveal every time it scrolls
/// back into view — `CLAUDE.md` names that failure and `reveal_once.dart` is the
/// fix. The registry belongs to the screen, not to the card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/data/gps/recorded_route.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/features/gps/route_detail_sections.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/v02/detail_page.dart';

/// `H.header('Your recorded route.','31 July · saved workout',true)`.
const String kRouteTitle = 'Your recorded route.';

/// One recorded track.
class RouteDetailScreen extends ConsumerStatefulWidget {
  /// [id] is the track id, as it came in on the route.
  const RouteDetailScreen({required this.id, super.key});

  /// The route's `id` parameter, passed to the provider unchanged.
  final String id;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  /// The screen's own registry — see the library docstring.
  final RevealRegistry _reveals = RevealRegistry();

  @override
  Widget build(BuildContext context) {
    final provider = recordedRouteProvider(widget.id);
    final view = ref.watch(provider);
    final RecordedRoute? loaded = view.value;
    // `panels.js:3` files `route` under movement with the workout group.
    return ToneScope(
      tone: Tone.movement,
      child: DetailPage(
        title: kRouteTitle,
        // The track's own day, once it is known. Until then the frame still
        // opens with a back control and a heading rather than a bare spinner on
        // a page with no way off it.
        eyebrow: loaded == null
            ? null
            : '${shortDate(loaded.start.toLocal().toIso8601String())} · '
                  'saved workout',
        children: <Widget>[
          AccountAsyncView<RecordedRoute>(
            value: view,
            onRetry: () => ref.invalidate(provider),
            builder: (context, route) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: routeDetailSections(context, route, _reveals),
            ),
          ),
        ],
      ),
    );
  }
}
