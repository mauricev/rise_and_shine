// lib/models/weather_alert.dart

import 'package:flutter/foundation.dart'; // For @immutable and listEquals

@immutable
class WeatherAlert {
  final String senderName;
  final String event;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? severity; // e.g., "Moderate", "Severe", "Extreme"
  final String? urgency; // e.g., "Immediate", "Expected", "Future"
  final String? certainty; // e.g., "Observed", "Likely", "Possible"

  const WeatherAlert({
    required this.senderName,
    required this.event,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.severity,
    this.urgency,
    this.certainty,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      senderName: json['sender_name'] as String,
      event: json['event'] as String,
      description: json['description'] as String,
      // OpenWeatherMap API provides timestamps in seconds
      startTime: DateTime.fromMillisecondsSinceEpoch((json['start'] as int) * 1000, isUtc: true),
      endTime: DateTime.fromMillisecondsSinceEpoch((json['end'] as int) * 1000, isUtc: true),
      severity: json['severity'] as String?,
      urgency: json['urgency'] as String?,
      certainty: json['certainty'] as String?,
    );
  }

  @override
  String toString() {
    return 'WeatherAlert(event: $event, sender: $senderName, start: $startTime, end: $endTime, severity: $severity)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is WeatherAlert &&
              runtimeType == other.runtimeType &&
              senderName == other.senderName &&
              event == other.event &&
              startTime == other.startTime &&
              endTime == other.endTime &&
              severity == other.severity &&
              urgency == other.urgency &&
              certainty == other.certainty;

  @override
  int get hashCode => Object.hash(senderName, event, startTime, endTime, severity, urgency, certainty);
}