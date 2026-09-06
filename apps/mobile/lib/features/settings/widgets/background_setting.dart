import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/background/background_preferences.dart';
import 'package:healthee/data/background/background_scheduler.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class BackgroundSetting extends ConsumerWidget {
  const BackgroundSetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ExpansionTile(
      title: const Text('Background sync'),
      children: [
        const Text(
          'The phone decides when jobs run. Intervals are minimum requests, not exact schedules. Bluetooth permissions must already be granted. Upload constraints apply to background jobs; Sync now remains manual.',
        ),
        AccountAsyncView<BackgroundPreferences>(
          value: ref.watch(backgroundPreferencesProvider),
          onRetry: () => ref.invalidate(backgroundPreferencesProvider),
          builder: (context, value) => _Editor(
            key: ValueKey(value.encode()),
            value: value,
            save: (next) async {
              await ref.read(backgroundSchedulerProvider).save(next);
              ref.invalidate(backgroundPreferencesProvider);
            },
          ),
        ),
        AccountAsyncView<String?>(
          value: ref.watch(backgroundLastRunProvider),
          onRetry: () => ref.invalidate(backgroundLastRunProvider),
          builder: (context, value) => ListTile(
            title: const Text('Last background attempt'),
            subtitle: Text(value ?? 'No background job has run yet.'),
            trailing: IconButton(
              tooltip: 'Refresh status',
              onPressed: () => ref.invalidate(backgroundLastRunProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({required this.value, required this.save, super.key});
  final BackgroundPreferences value;
  final Future<void> Function(BackgroundPreferences) save;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool enabled = widget.value.enabled;
  late bool wifi = widget.value.wifiOnly;
  late bool charging = widget.value.chargingOnly;
  late int pull = widget.value.pullMinutes;
  late int push = widget.value.pushMinutes;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Enable scheduled sync'),
        value: enabled,
        onChanged: (v) => setState(() => enabled = v),
      ),
      DropdownButton<int>(
        value: pull,
        items: [
          for (final minutes in BackgroundPreferences.pullOptions)
            DropdownMenuItem(
              value: minutes,
              child: Text('Collect every $minutes minutes'),
            ),
        ],
        onChanged: (v) => setState(() => pull = v!),
      ),
      DropdownButton<int>(
        value: push,
        items: [
          for (final minutes in BackgroundPreferences.pushOptions)
            DropdownMenuItem(
              value: minutes,
              child: Text('Upload every $minutes minutes'),
            ),
        ],
        onChanged: (v) => setState(() => push = v!),
      ),
      SwitchListTile(
        title: const Text('Upload on unmetered networks only'),
        value: wifi,
        onChanged: (v) => setState(() => wifi = v),
      ),
      SwitchListTile(
        title: const Text('Run only while charging'),
        value: charging,
        onChanged: (v) => setState(() => charging = v),
      ),
      ServerActionButton(
        label: 'Save background settings',
        action: () => widget.save(
          BackgroundPreferences(
            enabled: enabled,
            pullMinutes: pull,
            pushMinutes: push,
            wifiOnly: wifi,
            chargingOnly: charging,
          ),
        ),
        onSaved: () {},
      ),
    ],
  );
}
