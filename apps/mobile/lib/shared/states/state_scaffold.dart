/// The shared loading / error / empty states, and the card frame they sit in.
///
/// Engineering Standards §3: "Every async consumer renders all three states —
/// loading, error (with retry), and empty/no-data — using the shared-state
/// widgets. An error state that renders as a blank card is a bug."
///
/// They live together in one file because they are one decision: three answers to
/// "there is nothing to draw yet", which must look like siblings. Split across
/// three files they drift apart, and the version a screen forgot to update is the
/// one the owner sees on the worst day.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The ledger sheet every state renders inside — a 1px frame, near-square.
class StateCard extends StatelessWidget {
  /// Wraps [child] in the app's card frame.
  const StateCard({required this.child, this.accent, super.key});

  /// The card's contents.
  final Widget child;

  /// An optional left rule, used to mark a card's state.
  ///
  /// A thin border, never a nested container — `feedback_no_card_in_card` is
  /// explicit that state accents "go on a thin left border or content opacity".
  final Color? accent;

  /// Width of the state accent rule.
  static const double _accentWidth = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(Radii.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: radius,
        // Uniform, always. A BoxDecoration whose border differs per side cannot
        // carry a borderRadius — Flutter asserts at paint time — so the accent
        // rule is painted as its own strip below rather than as a fat left side.
        border: Border.all(color: colors.lineStrong, width: hairline),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // The Stack sizes to this, its only non-positioned child, so the
            // card still grows with its content in an unbounded list.
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: child,
            ),
            if (accent case final Color rule)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                start: 0,
                child: ColoredBox(
                  color: rule,
                  child: const SizedBox(width: _accentWidth),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Waiting on data.
///
/// Deliberately quiet: a determinate-looking spinner over a card that will
/// usually fill from cache in milliseconds reads as slowness that is not there.
class LoadingState extends StatelessWidget {
  /// Shows a subdued progress indicator.
  const LoadingState({this.label, super.key});

  /// What is being loaded, for screen readers and for slow paths.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StateCard(
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.inkFaint),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              label ?? 'Loading…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Something failed — OUR fault, and retryable.
///
/// Distinct from a withheld value in both colour and copy. A withhold is an
/// answer; this is the absence of one. [onRetry] is required rather than optional
/// so "error with no way forward" cannot be built by omission.
class ErrorState extends StatelessWidget {
  /// Shows a failure with a retry affordance.
  const ErrorState({
    required this.message,
    required this.onRetry,
    this.detail,
    super.key,
  });

  /// What went wrong, in plain words the owner can act on.
  final String message;

  /// Optional technical detail — shown small, never instead of [message].
  final String? detail;

  /// Tries again. Required: see the class docstring.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      accent: colors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: text.titleSmall),
          if (detail case final String detailText) ...[
            const SizedBox(height: Insets.sm),
            Text(detailText, style: text.bodySmall?.copyWith(color: colors.inkFaint)),
          ],
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ),
        ],
      ),
    );
  }
}

/// There is genuinely nothing here yet, and here is how to change that.
///
/// `docs/APP_DESIGN.md` §1: "Empty states, not '—'. Graceful 'no data yet /
/// here's how to get it' degradation." The [hint] is that second half and is
/// required for the same reason [ErrorState.onRetry] is.
class EmptyState extends StatelessWidget {
  /// Shows an honest empty card.
  const EmptyState({required this.message, required this.hint, super.key});

  /// What is absent.
  final String message;

  /// What would make it appear.
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: text.titleSmall),
          const SizedBox(height: Insets.sm),
          Text(hint, style: text.bodySmall?.copyWith(color: colors.inkFaint)),
        ],
      ),
    );
  }
}
