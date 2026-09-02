import 'package:flutter/material.dart';

/// RGB 三条滑条；只负责当前 [Color]，不读写 conf、不负责确认。
class RgbColorPicker extends StatelessWidget {
  const RgbColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _channelMin = 0.0;
  static const _channelMax = 255.0;
  static const _channelDivisions = 255;
  static const _labelWidth = 16.0;
  static const _valueWidth = 32.0;
  static const _rowGap = 4.0;

  final Color value;
  final ValueChanged<Color> onChanged;

  int get _r => _byte(value.r);
  int get _g => _byte(value.g);
  int get _b => _byte(value.b);

  static int _byte(double unit) => (unit * 255.0).round().clamp(0, 255);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _channelRow(label: 'R', channel: _r, onChanged: (r) {
          onChanged(Color.fromARGB(255, r, _g, _b));
        }),
        const SizedBox(height: _rowGap),
        _channelRow(label: 'G', channel: _g, onChanged: (g) {
          onChanged(Color.fromARGB(255, _r, g, _b));
        }),
        const SizedBox(height: _rowGap),
        _channelRow(label: 'B', channel: _b, onChanged: (b) {
          onChanged(Color.fromARGB(255, _r, _g, b));
        }),
      ],
    );
  }

  Widget _channelRow({
    required String label,
    required int channel,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            min: _channelMin,
            max: _channelMax,
            divisions: _channelDivisions,
            value: channel.toDouble(),
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
        SizedBox(
          width: _valueWidth,
          child: Text(
            '$channel',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
