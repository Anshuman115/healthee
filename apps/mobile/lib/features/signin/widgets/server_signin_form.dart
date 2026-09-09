/// The server address and the token — the only typing this screen asks for.
///
/// v02's `.field` geometry (`fields.dart`), the same two controls, the same
/// promises, the same submit. Nothing about where the token goes changed; only
/// what the boxes look like.
///
/// ## What the form says, in the form
///
/// The same discipline `zepp_sign_in_form.dart` uses: the promise about where a
/// secret goes is on screen next to the field that collects it, because that is
/// where the question gets asked. Here the promise is short — the token goes to
/// the address above it and nowhere else, over HTTPS, and it is checked before
/// it is kept.
///
/// ## The reveal toggle
///
/// Obscured by default, with an eye. A token is long, opaque and usually pasted,
/// and the single most common way to get it wrong is an invisible character at
/// one end — so being able to look at what is in the field is a correctness
/// feature, not a convenience. The whitespace that causes that is trimmed
/// anyway (`data/api/server_session.dart`), which is the belt to this brace.
///
/// **The token is never rendered anywhere but this field.** It is not put in
/// the semantics label, not in a log line, and not in the state object — see
/// `server_signin_state.dart`, and `test/signin/signin_secrecy_test.dart`,
/// which executes the claim.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/fields.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// Collects the server address and the API token.
class ServerSignInForm extends StatefulWidget {
  /// [initialUrl] prefills the address; [onSubmit] receives both fields as typed.
  const ServerSignInForm({
    required this.initialUrl,
    required this.onSubmit,
    required this.onEdited,
    required this.enabled,
    super.key,
  });

  /// What the address field starts with — the stored server, or the build's.
  final String initialUrl;

  /// Runs the check. Trimming is the data layer's job, in one place.
  final void Function(String url, String token) onSubmit;

  /// Called on the first edit after a failure, so stale copy can be cleared.
  final VoidCallback onEdited;

  /// False while a check is in flight.
  final bool enabled;

  @override
  State<ServerSignInForm> createState() => _ServerSignInFormState();
}

class _ServerSignInFormState extends State<ServerSignInForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );
  final TextEditingController _token = TextEditingController();
  bool _revealed = false;

  @override
  void dispose() {
    // A controller holding a token is memory we can drop early, and must drop
    // at all: leaking it would keep the string alive for the life of the isolate.
    _token
      ..clear()
      ..dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) {
      return;
    }
    widget.onSubmit(_url.text, _token.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Sign in to your server',
            style: FormType.heading3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: SectionGap.height),
          const SmallProse(
            'Healthee reads what your strap measured with no server at all. '
            'Signing in adds the half that is worked out on it — recovery, '
            'sleep health, debt, VO₂max and biological age.',
          ),
          const SizedBox(height: SectionGap.height),
          HField(
            label: 'Server address',
            hint: 'https:// unless it is this phone itself',
            child: HTextField(
              controller: _url,
              enabled: widget.enabled,
              keyboardType: TextInputType.url,
              onChanged: (_) => widget.onEdited(),
            ),
          ),
          HField(
            label: 'API token',
            hint: 'Checked against the server before it is saved',
            child: HTextField(
              controller: _token,
              enabled: widget.enabled,
              obscure: !_revealed,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => widget.onEdited(),
              // A token is pasted, and a smart keyboard capitalising the first
              // character of an opaque secret is a 401 nobody can explain.
              suffixIcon: IconButton(
                onPressed: () => setState(() => _revealed = !_revealed),
                tooltip: _revealed ? 'Hide the token' : 'Show the token',
                icon: Icon(
                  _revealed
                      ? SolarIconsOutline.eyeClosed
                      : SolarIconsOutline.eye,
                  size: 18,
                  color: colors.ink3,
                ),
              ),
            ),
          ),
          const SmallProse(
            'The token is kept in this phone’s secure keystore — the same place '
            'a password manager uses — and is sent only to the address above, '
            'as an Authorization header. It is never written to a log and never '
            'put in a web address.',
          ),
          const SizedBox(height: SectionGap.height),
          HButton(
            label: 'Check and sign in',
            onPressed: widget.enabled ? _submit : null,
          ),
        ],
      ),
    );
  }
}
