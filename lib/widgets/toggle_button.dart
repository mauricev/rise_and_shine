// lib/widgets/toggle_button.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/utils/app_logger.dart';

class ToggleButton extends StatefulWidget {
  final bool initialValue; // Generic name for initial state (e.g., true for active/metric, false for inactive/english)
  final ValueChanged<bool>? onChanged; // Callback when the value changes
  final String leftLabel; // Label for the left side (e.g., "English")
  final String rightLabel; // Label for the right side (e.g., "Metric")
  final Color activeColor; // Color of the toggle circle when active (e.g., Metric)
  final Color inactiveColor; // Color of the toggle circle when inactive (e.g., English)
  final Color activeTextColor; // Color of the text when its side is active
  final Color inactiveTextColor; // Color of the text when its side is inactive

  const ToggleButton({
    super.key,
    required this.initialValue,
    this.onChanged,
    required this.leftLabel,
    required this.rightLabel,
    required this.activeColor,
    required this.inactiveColor,
    required this.activeTextColor,
    required this.inactiveTextColor,
  });

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  late bool _value; // Internal state: true for active (right side), false for inactive (left side)

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _toggleValue() {
    setState(() {
      _value = !_value;
    });
    logger.d('ToggleButton: Toggled to value: $_value (Label: ${_value ? widget.rightLabel : widget.leftLabel})');
    widget.onChanged?.call(_value); // Notify parent
  }

  @override
  Widget build(BuildContext context) {
    const double width = 180.0;
    const double height = 50.0;
    const double toggleDiameter = 40.0;
    const double padding = 5.0;

    return GestureDetector(
      onTap: _toggleValue,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              alignment: _value ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                width: toggleDiameter,
                height: toggleDiameter,
                margin: const EdgeInsets.symmetric(horizontal: padding),
                decoration: BoxDecoration(
                  color: _value ? widget.activeColor : widget.inactiveColor, // Use passed colors
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.2).round()),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      widget.leftLabel,
                      style: TextStyle(
                        color: _value ? widget.inactiveTextColor : widget.activeTextColor, // Text color changes
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.rightLabel,
                      style: TextStyle(
                        color: _value ? widget.activeTextColor : widget.inactiveTextColor, // Text color changes
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}