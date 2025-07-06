// lib/widgets/unit_toggle_button.dart

import 'package:flutter/material.dart';
import 'package:rise_and_shine/utils/app_logger.dart'; // Import the global logger

class UnitToggleButton extends StatefulWidget {
  final bool initialIsMetric;
  final ValueChanged<bool>? onChanged; // Callback for when the value changes

  const UnitToggleButton({
    super.key,
    this.initialIsMetric = false, // Default to English (false means English)
    this.onChanged,
  });

  @override
  State<UnitToggleButton> createState() => _UnitToggleButtonState();
}

class _UnitToggleButtonState extends State<UnitToggleButton> {
  late bool _isMetric; // True for Metric, False for English

  @override
  void initState() {
    super.initState();
    _isMetric = widget.initialIsMetric;
  }

  void _toggleUnits() {
    setState(() {
      _isMetric = !_isMetric;
    });
    logger.d('UnitToggleButton: Toggled to Metric: $_isMetric');
    widget.onChanged?.call(_isMetric); // Notify parent
  }

  @override
  Widget build(BuildContext context) {
    // Define dimensions for the toggle button
    const double width = 180.0; // Total width of the button
    const double height = 50.0; // Total height of the button
    const double toggleDiameter = 40.0; // Diameter of the sliding circle
    const double padding = 5.0; // Padding around the toggle circle

    return GestureDetector(
      onTap: _toggleUnits,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueGrey[50], // Light background for the toggle
          borderRadius: BorderRadius.circular(height / 2), // Fully rounded corners
          border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sliding circle
            AnimatedAlign(
              alignment: _isMetric ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                width: toggleDiameter,
                height: toggleDiameter,
                margin: const EdgeInsets.symmetric(horizontal: padding),
                decoration: BoxDecoration(
                  color: _isMetric ? Colors.blueAccent : Colors.green, // Color changes with unit
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // FIX: Replaced withOpacity with withAlpha
                      color: Colors.black.withAlpha((255 * 0.2).round()),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Text labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'English',
                      style: TextStyle(
                        color: _isMetric ? Colors.blueGrey : Colors.white, // Text color changes
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Metric',
                      style: TextStyle(
                        color: _isMetric ? Colors.white : Colors.blueGrey, // Text color changes
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