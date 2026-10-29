import 'dart:async';
import 'package:flutter/material.dart';
import 'custom_ui.dart';
import 'labels.dart';
import 'limit_math.dart';
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
}) {
  return showCustomChoiceSheet<T>(context, title: title, options: options, current: current, searchable: searchable);
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
              CustomChoiceChip(
                label: d.short,
                selected: selected.contains(d.code),
                onTap: () => toggle(d.code),
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

class LimitEditor extends StatefulWidget {
  const LimitEditor({super.key, required this.kbps, required this.onChanged});
  final int kbps;
  final ValueChanged<int> onChanged;
  static const steps = [0, 5, 10, 20, 50, 100, 200, 500];
  static int closestStep(int kbps) => closestPresetMbps(kbps);
  @override
  State<LimitEditor> createState() => _LimitEditorState();
}

class _LimitEditorState extends State<LimitEditor> {
  late final TextEditingController _text;
  LimitUnit _unit = LimitUnit.mbps;
  Timer? _debounce;
  String? _error;
  int _lastKbps = -1;

  @override
  void initState() {
    super.initState();
    _lastKbps = widget.kbps;
    _text = TextEditingController(text: _textFor(widget.kbps));
  }

  String _textFor(int kbps) {
    if (kbps <= 0) return '';
    final v = valueFromKbps(kbps, _unit);
    return _format(v);
  }

  String _format(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  void didUpdateWidget(covariant LimitEditor old) {
    super.didUpdateWidget(old);
    if (widget.kbps != _lastKbps) {
      _lastKbps = widget.kbps;
      if (!_text.text.isEmpty || widget.kbps > 0) {
        final parsed = double.tryParse(_text.text.trim());
        final parsedKbps = parsed == null ? -1 : kbpsFromValue(parsed, _unit);
        if (parsedKbps != widget.kbps) _text.text = _textFor(widget.kbps);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _applyText() {
    final raw = _text.text.trim();
    final err = limitError(raw);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (raw.isEmpty) {
      setState(() => _error = null);
      if (widget.kbps != 0) {
        _lastKbps = 0;
        widget.onChanged(0);
      }
      return;
    }
    final kbps = kbpsFromValue(double.parse(raw), _unit);
    setState(() => _error = null);
    if (kbps != widget.kbps) {
      _lastKbps = kbps;
      widget.onChanged(kbps);
    }
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyText);
  }

  void _step(int delta) {
    final current = double.tryParse(_text.text.trim()) ?? valueFromKbps(widget.kbps, _unit);
    final next = current + delta;
    if (next < 0) {
      setState(() => _error = 'Negative is not a valid limit. Use No limit for unlimited.');
      return;
    }
    _text.text = _format(next);
    _applyText();
  }

  void _setPreset(int mbps) {
    setState(() => _unit = LimitUnit.mbps);
    _text.text = mbps == 0 ? '' : '$mbps';
    _applyText();
  }

  @override
  Widget build(BuildContext context) {
    final sliderSteps = LimitEditor.steps;
    final sliderIdx = sliderSteps.indexOf(closestPresetMbps(widget.kbps));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(limitSummary(widget.kbps), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: appInk, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        const Text('Slider shows the closest preset as a hint only. The typed value is what is used.', style: TextStyle(color: appMuted, fontSize: 12, height: 1.4)),
        CustomSlider(
          value: sliderIdx.toDouble(),
          min: 0,
          max: (sliderSteps.length - 1).toDouble(),
          divisions: sliderSteps.length - 1,
          onChanged: (v) => _setPreset(sliderSteps[v.round()]),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in sliderSteps)
              CustomChoiceChip(
                label: p == 0 ? 'No limit' : '$p Mbps',
                selected: closestPresetMbps(widget.kbps) == p && _unit == LimitUnit.mbps,
                onTap: () => _setPreset(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Manual limit',
                  hintText: 'Leave empty for No limit',
                  errorText: _error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white,
              shape: const CircleBorder(side: BorderSide(color: appOutlineVariant)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _step(-1),
                child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.remove, size: 20, color: appInk)),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: appBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _step(1),
                child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.add, size: 20, color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedControl<LimitUnit>(
          options: const [(LimitUnit.mbps, 'Mbps'), (LimitUnit.kbps, 'KBps'), (LimitUnit.mbpsByte, 'MBps')],
          value: _unit,
          onChanged: (u) {
            setState(() {
              _unit = u;
              if (widget.kbps > 0) _text.text = _format(valueFromKbps(widget.kbps, u));
            });
          },
        ),
        if (limitAboveRouterHint(widget.kbps)) ...[
          const SizedBox(height: 8),
          const Text('Above 1000 Mbps: the router may cap this. It is not clamped here.', style: TextStyle(color: Color(0xFFB45309), fontSize: 12, height: 1.4)),
        ],
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
        CustomSlider(
          value: v.toDouble(),
          min: -90,
          max: -40,
          divisions: 10,
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
