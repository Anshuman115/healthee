/// **The biological-age halo** — the prototype's centrepiece, as a widget.
///
/// A circular emerald particle field: ~1,400 particles flow inward from all four
/// edges of the card, brighten as they merge into a dense rim, drag short trails
/// so their direction is visible, and leave a **still centre** so the figure they
/// surround stays readable. `halo_field.dart` owns where every mark is;
/// `halo_painter.dart` owns what it is painted with; this file owns the one
/// thing that costs battery — **when it moves at all**.
///
/// ## It is decoration, and it is not allowed to become anything else
///
/// The halo takes no reading, no score and no colour parameter. It cannot encode
/// a measurement because it is never handed one, and the figure it surrounds
/// **never animates, counts up, or changes for effect** — `README.md` is
/// explicit, and `halo_motion_test.dart` asserts the age text is identical, to
/// the pixel, across frames in which the halo demonstrably moved.
///
/// ## Four ways it stops, and each one really stops it
///
/// The prototype pauses offscreen, pauses when the tab is hidden, disables
/// itself under the system's reduced-motion setting, and gives the owner a
/// button (`motion_toggle.dart`). All four are here, and all four **stop the
/// ticker** rather than setting a flag the painter consults:
///
///   * **Offscreen** — the render box's screen rect is tested every frame, and
///     the enclosing `ScrollPosition` wakes it again on the way back. A flag
///     would leave Flutter scheduling a frame every vsync for a card nobody can
///     see, which is exactly the battery cost the cap exists to avoid.
///   * **Backgrounded** — any lifecycle state other than `resumed` stops it.
///   * **Reduced motion** — `MediaQuery.disableAnimations`. The field is still
///     painted, once, at time zero: the card keeps its texture and loses its
///     motion, which is what the setting asks for.
///   * **[BioHalo.paused]** — the hero's own control. It is a fourth reason to
///     stop, not a replacement for the other three: resuming by hand cannot
///     start a field that is offscreen, backgrounded, or under reduced motion.
///
/// A route pushed on top is handled for free: `TickerMode` mutes the ticker
/// wherever Flutter already knows the widget is not the current route.
///
/// ## Cost
///
/// 30 fps (`kHaloFrameInterval`), a particle budget scaled to the painted area
/// and capped at the prototype's 1,400 (`halo_field.dart`), no blur filters, no
/// saved layers, and a `RepaintBoundary` so a halo frame never dirties the
/// figure beside it.
///
/// **A screen containing a running halo never settles**, so a widget test that
/// pumps one must use `pump(duration)` rather than `pumpAndSettle()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/v02/bio_display.dart';
import 'package:healthee/shared/v02/instruments/halo_painter.dart';

/// 30 fps, the prototype's cap: `if (now - field.last >= 32)`.
const Duration kHaloFrameInterval = Duration(milliseconds: 33);

/// The largest step the clock will take, so a resumed halo does not jump.
const double kHaloMaxStep = 0.05;

/// The ambient particle field behind the biological-age figure.
class BioHalo extends StatefulWidget {
  /// Builds the halo. It fills its box and takes **no colour**: the inks come
  /// from the bio roles of the active theme.
  const BioHalo({
    this.alignment,
    this.paused = false,
    this.onFrame,
    super.key,
  });

  /// Where the still centre sits inside the box.
  ///
  /// Null takes the enclosing hero's ([BioDisplayScope]), which is what puts the
  /// hole over the figure when the field is stretched across the whole card. A
  /// field pumped with no hero in scope falls back to [Alignment.center].
  final Alignment? alignment;

  /// Stopped by hand. See the library docstring's fourth stop.
  final bool paused;

  /// Called once per advanced frame. Diagnostics and tests only — this is how
  /// `halo_motion_test.dart` proves the halo stopped rather than that a flag
  /// flipped.
  final VoidCallback? onFrame;

  @override
  State<BioHalo> createState() => _BioHaloState();
}

class _BioHaloState extends State<BioHalo>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  bool _foreground = true;
  bool _reducedMotion = false;
  bool _wakeScheduled = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleWake);
      _position = position;
      _position?.addListener(_scheduleWake);
    }
    _scheduleWake();
  }

  @override
  void didUpdateWidget(BioHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleWake);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// True when the box overlaps the screen. The offscreen test, in one place.
  bool _onScreen() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      return false;
    }
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final view = View.of(context);
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    return rect.overlaps(screen);
  }

  /// Starts or stops the ticker to match the three conditions. Idempotent.
  void _sync() {
    if (!mounted) {
      return;
    }
    final run =
        _foreground && !_reducedMotion && !widget.paused && _onScreen();
    if (run == _ticker.isActive) {
      return;
    }
    if (run) {
      // One interval in the past, so a resumed halo draws its first frame at
      // once rather than 33 ms of stillness after coming back.
      _lastFrame = -kHaloFrameInterval;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  /// Re-checks after the frame, when the box has a position to check.
  void _scheduleWake() {
    if (_wakeScheduled) {
      return;
    }
    _wakeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wakeScheduled = false;
      _sync();
    });
  }

  void _tick(Duration elapsed) {
    final step = elapsed - _lastFrame;
    if (step < kHaloFrameInterval) {
      return;
    }
    if (!_onScreen()) {
      _ticker.stop();
      return;
    }
    _lastFrame = elapsed;
    _clock.value += (step.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, kHaloMaxStep);
    widget.onFrame?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ticker.isActive) {
      _scheduleWake();
    }
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: HaloPainter(
            clock: _clock,
            ink: HaloInk.of(context.colors),
            alignment: widget.alignment ?? BioDisplayScope.of(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
