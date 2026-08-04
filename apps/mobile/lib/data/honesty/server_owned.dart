/// The refusal the app owes for a number the SERVER derives.
///
/// ## Why this is a `Withheld` and not a fifth [Reading] case
///
/// It was worth asking. "Recovery is 72" and "recovery is derived on the server
/// and this build has not sent it anything" are genuinely different absences,
/// and [Reading] exists precisely so different absences do not collapse into a
/// dash. A fifth case would make every `switch` in the app stop compiling until
/// somebody decided what this looks like, which is the type's whole trick.
///
/// It is still the wrong answer here, for two reasons.
///
/// **The four cases are the server's vocabulary, not ours.** `Reading`'s own
/// docstring says so: `withheld` / `excluded` / `caveats` are fixed by
/// `derive/freshness.py`, and `Present` is the fourth. A case this app invented
/// would be a state the server can never send and can never clear, sitting in
/// the same union as four it owns — and the next reader would have no way to
/// tell which of the five are contract and which are ours.
///
/// **The semantics already match, exactly.** `Withheld` means *you could have
/// this; here is what would bring it back*, against `Excluded`'s *nobody can
/// price this, ever*. A server-derived number is the first: the measurements
/// exist on the phone, the derivation exists on the server, and the missing
/// piece is a link between them. That is a temporary, nameable gap — which is
/// the definition of a withhold, not a new kind of thing.
///
/// So it is a `Withheld` carrying its own [Disclosure.reason], which is the
/// field that exists to tell refusals apart. A screen that wants to render this
/// one differently switches on the reason id, and one that does not gets a
/// correct, honest card for free.
///
/// ## The message does not promise an action, because there is not one yet
///
/// A withhold's message is normally a remedy in the second person — "wear the
/// strap overnight for a few more nights and this comes back". This build has no
/// remedy to offer: it reads the strap and stores what it reads, and nothing is
/// sent anywhere. Writing "sync to the server" would be inviting the owner to
/// press a button that does not exist, which is a smaller lie than a fabricated
/// number and still a lie. So the sentence says what is true: the number is
/// derived elsewhere, the phone deliberately does not compute it, and this build
/// does not yet talk to the thing that does.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';

/// The reason id every server-derived refusal carries.
///
/// Stable and filterable: a screen that wants to group these into one "what the
/// server would add" section keys on this rather than on the message text.
const String serverDerivedReason = 'derived_on_server';

/// Why [name] has no value on a strap-only build.
///
/// [name] is the metric in the owner's own words — "Recovery", "Sleep health".
/// It is interpolated so a list of these reads as a list of specific refusals
/// rather than the same sentence five times.
Disclosure serverDerivedDisclosure(String name) => Disclosure(
  reason: serverDerivedReason,
  message:
      '$name is derived on the server from what your strap collects — this app '
      'will not work it out on the phone, because one number computed two ways '
      'is two numbers. This build reads the strap and stores it here; it does '
      'not send anything yet, so there is nothing derived to show.',
);

/// [name]'s reading on a strap-only build: withheld, with the reason above.
///
/// Typed on the value the metric *would* carry, so wiring the real payload in
/// later is a change of source and not a change of shape.
Reading<T> serverDerived<T extends Object>(String name) =>
    Withheld<T>(serverDerivedDisclosure(name));
