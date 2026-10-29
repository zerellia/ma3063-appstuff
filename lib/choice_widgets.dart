import 'package:flutter/material.dart';
import 'labels.dart';
import 'theme.dart';

/// Shared choice controls. Closed sets are never free text here:
/// choice sheet, weekday chips, time picker row, sliders with presets,
/// and removable chip inputs for genuinely list-like values.

Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String, String?)> options,
  required T current,
  bool searchable = false,
}) async {
  var query = '';
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final shown = query.isEmpty
            ? options
            : options.where((o) => o.$2.toLowerCase().contains(query.toLowerCase())).toList();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 36, height: 5, decoration: BoxDecoration(color: appBorder, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: appInk))),
                ),
                if (searchable) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                      onChanged: (v) => setS(() => query = v),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in options)
                        if (shown.contains(o))
                          RadioListTile<T>(
                            value: o.$1,
                            groupValue: current,
                            title: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600, color: appInk)),
                            subtitle: o.$3 == null ? null : Text(o.$3!, style: const TextStyle(color: appMuted)),
                            activeColor: appBlue,
                            onChanged: (v) => Navigator.pop(ctx, v),
                          ),
                      if (shown.isEmpty)
                        const Padding(padding: EdgeInsets.all(20), child: Text('Nothing matches that search.', style: TextStyle(color: appMuted))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget choiceRow(String title, String value, String? subtitle, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: appSurfaceLow, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: appInk)),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: appMuted, fontSize: 12))],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: appBlue))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: appMuted),
        ],
      ),
    ),
  );
}

class WeekdayChips extends StatelessWidget {
  const WeekdayChips({super.key, required this.selected, required this.onChanged, this.showPresets = true});
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool showPresets;
  @override
  Widget build(BuildContext context) {
    void toggle(String code) {
      final next = Set<String>.from(selected);
      if (next.contains(code)) {
        next.remove(code);
      } else {
        next.add(code);
      }
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in Weekday.values)
              FilterChip(
                label: Text(d.short),
                selected: selected.contains(d.code),
                selectedColor: appSecondaryContainer,
                checkmarkColor: appOnSecondary,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected.contains(d.code) ? appOnSecondary : appInk),
                onSelected: (_) => toggle(d.code),
              ),
          ],
        ),
        if (showPresets) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: () => onChanged(Weekday.values.map((d) => d.code).toSet()), child: const Text('Every day')),
              TextButton(onPressed: () => onChanged({'mon', 'tue', 'wed', 'thu', 'fri'}), child: const Text('Weekdays')),
              TextButton(onPressed: () => onChanged({'sat', 'sun'}), child: const Text('Weekends')),
              TextButton(onPressed: () => onChanged(<String>{}), child: const Text('Clear')),
            ],
          ),
        ],
      ],
    );
  }
}

class TimePickerRow extends StatelessWidget {
  const TimePickerRow({super.key, required this.label, required this.value, required this.onChanged, this.onClear});
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: choiceRow(
            label,
            value == null ? 'Not set' : formatDisplayTime(value!),
            null,
            () async {
              final picked = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 22, minute: 0));
              if (picked != null) onChanged(picked);
            },
          ),
        ),
        if (onClear != null) TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}

class LimitSlider extends StatelessWidget {
  const LimitSlider({super.key, required this.mbps, required this.onChanged});
  final int mbps;
  final ValueChanged<int> onChanged;
  static const steps = [0, 5, 10, 20, 50, 100, 200, 500];
  static int closestStep(int v) {
    var best = steps.first;
    for (final s in steps) {
      if ((s - v).abs() < (best - v).abs()) best = s;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final current = closestStep(mbps);
    final idx = steps.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(current == 0 ? 'No limit' : '$current Mbps', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: appInk, fontFeatures: [FontFeature.tabularFigures()])),
        Slider(
          value: idx.toDouble(),
          min: 0,
          max: (steps.length - 1).toDouble(),
          divisions: steps.length - 1,
          label: current == 0 ? 'No limit' : '$current Mbps',
          onChanged: (v) => onChanged(steps[v.round()]),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in [0, 5, 10, 20, 50, 100])
              FilterChip(
                label: Text(s == 0 ? 'No limit' : '$s Mbps'),
                selected: current == s,
                selectedColor: appSecondaryContainer,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: current == s ? appOnSecondary : appInk),
                onSelected: (_) => onChanged(s),
              ),
          ],
        ),
      ],
    );
  }
}

class RoamingSlider extends StatelessWidget {
  const RoamingSlider({super.key, required this.label, required this.dbm, required this.onChanged});
  final String label;
  final int dbm;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final v = dbm.clamp(-90, -40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: appInk)),
        Text('Roam when weaker than $v dBm', style: const TextStyle(color: appMuted, fontSize: 12)),
        Slider(
          value: v.toDouble(),
          min: -90,
          max: -40,
          divisions: 10,
          label: '$v dBm',
          onChanged: (x) => onChanged(x.round()),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Roam sooner', style: TextStyle(color: appMuted, fontSize: 12)), Text('Stay longer', style: TextStyle(color: appMuted, fontSize: 12))],
        ),
      ],
    );
  }
}

class ChipInput extends StatefulWidget {
  const ChipInput({super.key, required this.values, required this.onChanged, required this.addLabel, this.hint});
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String addLabel;
  final String? hint;
  @override
  State<ChipInput> createState() => _ChipInputState();
}

class _ChipInputState extends State<ChipInput> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final v = _c.text.trim();
    if (v.isEmpty || widget.values.contains(v)) return;
    widget.onChanged([...widget.values, v]);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in widget.values)
                Chip(
                  label: Text(v),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => widget.onChanged(widget.values.where((e) => e != v).toList()),
                ),
            ],
          ),
        if (widget.values.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _c, decoration: InputDecoration(hintText: widget.hint ?? widget.addLabel), onSubmitted: (_) => _add())),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _add, child: const Text('Add')),
          ],
        ),
      ],
    );
  }
}

class GroupedSettings extends StatelessWidget {
  const GroupedSettings({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: appSurfaceContainer, borderRadius: BorderRadius.circular(20), border: Border.all(color: appOutlineVariant)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: children[i]),
            if (i < children.length - 1) const Divider(height: 1, color: appOutlineVariant, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

Widget sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: appMuted),
    ),
  );
}

List<String> splitListValue(String s) {
  return s.split(RegExp(r'[,\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
