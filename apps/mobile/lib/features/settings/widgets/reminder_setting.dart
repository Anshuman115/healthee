import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/notifications/notification_providers.dart';
import 'package:healthee/data/notifications/reminder_preferences.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class ReminderSetting extends ConsumerWidget {
  const ReminderSetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ExpansionTile(
      title: const Text('Reminders'),
      children: [
        const Text(
          'Optional reminders at your chosen local times. Delivery may be delayed by the phone. Bedtime also adds a reminder 45 minutes beforehand.',
        ),
        AccountAsyncView<AccountApi>(
          value: ref.watch(accountApiProvider),
          onRetry: () => ref.invalidate(accountApiProvider),
          builder: (context, api) => AccountAsyncView<ReminderPreferences>(
            value: ref.watch(reminderPreferencesProvider),
            onRetry: () => ref.invalidate(reminderPreferencesProvider),
            builder: (context, value) => _Editor(
              key: ValueKey('${api.sessionScope}:${value.encode()}'),
              value: value.scope == api.sessionScope
                  ? value
                  : const ReminderPreferences(),
              save: (next) async {
                await ref
                    .read(notificationServiceProvider)
                    .save(
                      ReminderPreferences(
                        scope: api.sessionScope,
                        daily: next.daily,
                        bedtime: next.bedtime,
                        completions: next.completions,
                        dailyMinute: next.dailyMinute,
                        bedtimeMinute: next.bedtimeMinute,
                      ),
                      api,
                    );
                ref.invalidate(reminderPreferencesProvider);
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({required this.value, required this.save, super.key});
  final ReminderPreferences value;
  final Future<void> Function(ReminderPreferences) save;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool daily = widget.value.daily;
  late bool bed = widget.value.bedtime;
  late bool completions = widget.value.completions;
  late int dailyMinute = widget.value.dailyMinute;
  late int bedtimeMinute = widget.value.bedtimeMinute;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Daily focus'),
        value: daily,
        onChanged: (v) => setState(() => daily = v),
      ),
      _time('Daily reminder time', dailyMinute, (v) => dailyMinute = v),
      SwitchListTile(
        title: const Text('Bedtime and wind-down'),
        value: bed,
        onChanged: (v) => setState(() => bed = v),
      ),
      _time('Chosen bedtime', bedtimeMinute, (v) => bedtimeMinute = v),
      SwitchListTile(
        title: const Text('Challenge completion notifications'),
        value: completions,
        onChanged: (v) => setState(() => completions = v),
      ),
      ServerActionButton(
        label: 'Save reminders',
        action: () => widget.save(
          ReminderPreferences(
            daily: daily,
            bedtime: bed,
            completions: completions,
            dailyMinute: dailyMinute,
            bedtimeMinute: bedtimeMinute,
          ),
        ),
        onSaved: () {},
      ),
    ],
  );
  Widget _time(String label, int minute, void Function(int) update) => ListTile(
    title: Text(label),
    trailing: Text(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context),
    ),
    onTap: () async {
      final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
      if (value != null && mounted) {
        setState(() => update(value.hour * 60 + value.minute));
      }
    },
  );
}
