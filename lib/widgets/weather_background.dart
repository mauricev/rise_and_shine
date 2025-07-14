// lib/widgets/weather_background.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:rise_and_shine/consts/consts_weather_background.dart';
// import 'package:rise_and_shine/utils/app_logger.dart'; // Removed logger import

/// A StatefulWidget that provides an animated background based on weather conditions.
class WeatherBackground extends StatefulWidget {
  final WeatherCondition condition;
  final bool isDay;

  const WeatherBackground({
    super.key,
    required this.condition,
    required this.isDay,
  });

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _getAnimationDuration(widget.condition),
      vsync: this,
    )..repeat(); // Loop the animation
  }

  @override
  void didUpdateWidget(covariant WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // IMPORTANT: Always reset and restart if condition or isDay changes
    if (oldWidget.condition != widget.condition || oldWidget.isDay != widget.isDay) {
      _controller.duration = _getAnimationDuration(widget.condition); // Update duration based on new condition
      _controller.reset(); // Reset animation to start from beginning
      _controller.repeat(); // Restart animation
    }
  }

  Duration _getAnimationDuration(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.cloudy: // Fallback
      case WeatherCondition.fewClouds:
      case WeatherCondition.scatteredClouds:
      case WeatherCondition.brokenClouds:
      case WeatherCondition.atmosphere:
        return kCloudAnimationDuration;
      case WeatherCondition.rainy:
      case WeatherCondition.drizzle:
      case WeatherCondition.thunderstorm:
        return kRainAnimationDuration;
      case WeatherCondition.snowy:
        return kSnowAnimationDuration;
      case WeatherCondition.sunny:
      case WeatherCondition.clear:
      case WeatherCondition.unknown:
      default:
        return kSunMoonAnimationDuration; // Subtle movement for static backgrounds
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _getWeatherPainter(widget.condition, widget.isDay, _controller.value),
          child: Container(), // Empty container to ensure CustomPaint fills space
        );
      },
    );
  }

  CustomPainter _getWeatherPainter(WeatherCondition condition, bool isDay, double animationValue) {
    switch (condition) {
      case WeatherCondition.sunny:
      case WeatherCondition.clear:
        return SunnyBackgroundPainter(isDay: isDay, animationValue: animationValue);
      case WeatherCondition.cloudy: // Fallback
      case WeatherCondition.fewClouds:
      case WeatherCondition.scatteredClouds:
      case WeatherCondition.brokenClouds:
        return CloudyBackgroundPainter(isDay: isDay, animationValue: animationValue, cloudCondition: condition); // Pass specific cloud condition
      case WeatherCondition.rainy:
      case WeatherCondition.drizzle:
      case WeatherCondition.thunderstorm:
        return RainyBackgroundPainter(isDay: isDay, animationValue: animationValue);
      case WeatherCondition.snowy:
        return SnowyBackgroundPainter(isDay: isDay, animationValue: animationValue);
      case WeatherCondition.atmosphere:
        return AtmosphereBackgroundPainter(isDay: isDay, animationValue: animationValue);
      case WeatherCondition.unknown:
      default:
        return DefaultBackgroundPainter(isDay: isDay);
    }
  }
}

// --- Custom Painters for each weather condition ---

/// Default painter for unknown/unspecified conditions.
class DefaultBackgroundPainter extends CustomPainter {
  final bool isDay;

  DefaultBackgroundPainter({required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Fill entire canvas with a distinct default color
    paint.color = isDay ? Colors.grey.shade300 : Colors.blueGrey.shade900; // More distinct default
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Only repaint if isDay changes, as there's no animation for this painter
    return oldDelegate is! DefaultBackgroundPainter || oldDelegate.isDay != isDay;
  }
}

/// Painter for Sunny conditions.
class SunnyBackgroundPainter extends CustomPainter {
  final bool isDay;
  final double animationValue;
  final List<Offset> _starPositions; // Store star positions

  SunnyBackgroundPainter({required this.isDay, required this.animationValue})
      : _starPositions = List.generate(50, (index) {
    // Generate fixed initial star positions
    final random = math.Random(index); // Use index as seed for consistent positions
    return Offset(random.nextDouble(), random.nextDouble()); // Normalized positions
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Sky Gradient (fills entire canvas)
    final Gradient skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDay
          ? [kSunnyDaySkyColor, kSunnyDaySkyColor.withAlpha((255 * 0.7).round())]
          : [kSunnyNightSkyColor, kSunnyNightSkyColor.withAlpha((255 * 0.7).round())],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    paint.shader = null; // Clear shader for subsequent drawings

    if (isDay) {
      // Sun
      paint.color = kSunColor;
      // Animate sun subtly across the top, looping
      final double sunX = size.width * 0.2 + (size.width * 0.6 * (animationValue % 1.0));
      canvas.drawCircle(Offset(sunX, size.height * 0.2), size.width * 0.1, paint);
    } else {
      // Moon
      paint.color = kMoonColor;
      // Animate moon subtly across the top, looping
      final double moonX = size.width * 0.2 + (size.width * 0.6 * (animationValue % 1.0));
      canvas.drawCircle(Offset(moonX, size.height * 0.08), size.width * 0.08, paint); // Adjusted Y for moon

      // Stars (move barely)
      paint.color = kStarColor;
      // The animationValue is now very slow (kSunMoonAnimationDuration = 6000s)
      // Apply a very small horizontal shift to star positions
      final double starShift = size.width * 0.01 * (animationValue % 1.0); // Shift by 1% of width over the entire duration
      for (final starPos in _starPositions) {
        final double starX = (starPos.dx * size.width + starShift) % size.width;
        final double starY = starPos.dy * size.height * 0.7; // Limit stars to top 70% of screen
        canvas.drawCircle(Offset(starX, starY), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SunnyBackgroundPainter oldDelegate) {
    return oldDelegate.isDay != isDay || oldDelegate.animationValue != animationValue;
  }
}

/// Painter for Cloudy conditions.
class CloudyBackgroundPainter extends CustomPainter {
  final bool isDay;
  final double animationValue;
  final WeatherCondition cloudCondition; // NEW: Specific cloud condition

  CloudyBackgroundPainter({
    required this.isDay,
    required this.animationValue,
    required this.cloudCondition, // NEW
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Sky Gradient (fills entire canvas) - Always a blue base
    final Gradient skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDay
          ? [kCloudyDaySkyColor, kCloudyDaySkyColor.withAlpha((255 * 0.7).round())]
          : [kCloudyNightSkyColor, kCloudyNightSkyColor.withAlpha((255 * 0.7).round())],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    paint.shader = null;

    // Determine cloud properties based on cloudCondition
    int numberOfClouds;
    double cloudScaleFactor;
    double cloudOpacity;

    switch (cloudCondition) {
      case WeatherCondition.fewClouds:
        numberOfClouds = 2;
        cloudScaleFactor = 0.0018; // Doubled size (was 0.0006)
        cloudOpacity = 0.7;
        break;
      case WeatherCondition.scatteredClouds:
        numberOfClouds = 4;
        cloudScaleFactor = 0.0021; // Tripled size (was 0.0007)
        cloudOpacity = 0.8;
        break;
      case WeatherCondition.brokenClouds: // Overcast
        numberOfClouds = 6;
        cloudScaleFactor = 0.0027; // Tripled size (was 0.0009)
        cloudOpacity = 0.9;
        break;
      case WeatherCondition.cloudy: // Generic fallback for 'cloudy'
      default:
        numberOfClouds = 3;
        cloudScaleFactor = 0.0021; // Tripled size (was 0.0007)
        cloudOpacity = 0.75;
        break;
    }

    // Clouds
    paint.color = (isDay ? kCloudColorLight : kCloudColorDark).withAlpha((255 * cloudOpacity).round());

    // Draw clouds with varying positions and sizes
    for (int i = 0; i < numberOfClouds; i++) {
      // Use a fixed seed for cloud positions to make them consistent across repaints,
      // but still allow animationValue to move them.
      // Offset each cloud's starting position based on its index
      final double initialXOffset = (i * size.width * 0.3) % size.width;
      final double initialYOffset = (i % 2 == 0 ? size.height * 0.2 : size.height * 0.35) + (math.Random(i).nextDouble() * size.height * 0.1 - size.height * 0.05);

      final double xPos = (initialXOffset + (size.width * 1.5 * animationValue)) % (size.width * 2) - size.width * 0.5;
      final double yOffset = initialYOffset;

      _drawCloud(canvas, paint, size, xPos, yOffset, cloudScaleFactor);
    }
  }

  void _drawCloud(Canvas canvas, Paint paint, Size size, double xOffset, double yOffset, double scaleFactor) {
    final double cloudBaseSize = size.width * scaleFactor; // Base size relative to screen width
    final Path path = Path()
      ..moveTo(xOffset + 50 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 50 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 120 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 120 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset + 100 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset + 80 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 20 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset - 20 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset - 20 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CloudyBackgroundPainter oldDelegate) {
    return oldDelegate.isDay != isDay || oldDelegate.animationValue != animationValue || oldDelegate.cloudCondition != cloudCondition;
  }
}

/// Painter for Rainy conditions.
class RainyBackgroundPainter extends CustomPainter {
  final bool isDay;
  final double animationValue; // Used for rain drop animation
  final List<Offset> _raindropInitialPositions; // Store initial raindrop positions
  final List<double> _cloudInitialXOffsets; // Store initial cloud X offsets
  final List<double> _cloudInitialYOffsets; // Store initial cloud Y offsets
  final List<double> _cloudScales; // Store individual cloud scales

  RainyBackgroundPainter({required this.isDay, required this.animationValue})
      : _raindropInitialPositions = List.generate(100, (index) { // 100 raindrops
    final random = math.Random(index);
    // Generate initial Y positions from -0.5 to 1.0 (normalized screen height)
    // This ensures drops start above the screen and cover the whole screen.
    return Offset(random.nextDouble(), random.nextDouble() * 1.5 - 0.5);
  }),
        _cloudInitialXOffsets = List.generate(3, (index) => math.Random(index).nextDouble()), // 3 clouds
        _cloudInitialYOffsets = List.generate(3, (index) => math.Random(index + 100).nextDouble() * 0.2 + 0.1), // Top 10-30%
        _cloudScales = List.generate(3, (index) => 0.0025 + math.Random(index + 200).nextDouble() * 0.0008); // Larger base scale, more variation

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Sky Gradient (fills entire canvas)
    final Gradient skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDay
          ? [kRainyDaySkyColor, kRainyDaySkyColor.withAlpha((255 * 0.7).round())]
          : [kRainyNightSkyColor, kRainyNightSkyColor.withAlpha((255 * 0.7).round())],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    paint.shader = null;

    // Clouds (darker) - Refactored for continuous movement, larger size, and randomness
    int numberOfRainClouds = _cloudInitialXOffsets.length;
    double rainCloudOpacity = 0.8;

    paint.color = (isDay ? kCloudColorDark : Colors.grey.shade700).withAlpha((255 * rainCloudOpacity).round());

    // Define the total horizontal travel distance for clouds (e.g., 2.5 times screen width)
    // This allows clouds to start fully off-screen left and exit fully off-screen right.
    final double totalCloudTravelDistance = size.width * 2.5;
    final double cloudSpeedFactor = 0.1; // Slower cloud movement

    for (int i = 0; i < numberOfRainClouds; i++) {
      // Calculate xPos to ensure smooth entry from right and exit to left
      // _cloudInitialXOffsets[i] is a normalized value (0 to 1)
      final double startX = _cloudInitialXOffsets[i] * size.width * 1.5; // Spread starting positions
      final double xPos = (startX + (totalCloudTravelDistance * animationValue * cloudSpeedFactor)) % totalCloudTravelDistance - size.width * 0.75; // Adjust offset for entry/exit
      final double yOffset = _cloudInitialYOffsets[i] * size.height;
      final double cloudScaleFactor = _cloudScales[i];

      _drawCloud(canvas, paint, size, xPos, yOffset, cloudScaleFactor);
    }

    // Raindrops - Increased count and speed, continuous falling, bigger drops
    paint.color = kRaindropColor;
    paint.strokeWidth = 2.8; // Thicker drops
    double rainSpeedFactor = 0.9; // Slightly slower speed (was 1.2, now 0.9)
    double dropLength = 6.0; // Shorter drops
    double dropXOffset = 2.0; // Horizontal slant

    // The total distance a drop travels before looping.
    // It should be at least size.height + dropLength to ensure seamless loop.
    final double totalLoopDistance = size.height + dropLength;


    for (int i = 0; i < _raindropInitialPositions.length; i++) {
      final Offset initialPos = _raindropInitialPositions[i];
      final double rainX = initialPos.dx * size.width;

      // Calculate continuous falling Y position with wrap-around
      // `initialPos.dy` is a normalized value, scaled by `totalLoopDistance`
      final double currentY = (initialPos.dy * totalLoopDistance + (animationValue * totalLoopDistance * rainSpeedFactor)) % totalLoopDistance;

      // Draw the line segment for the raindrop
      canvas.drawLine(Offset(rainX, currentY), Offset(rainX + dropXOffset, currentY + dropLength), paint);
    }
  }

  // Unified _drawCloud method for RainyBackgroundPainter
  void _drawCloud(Canvas canvas, Paint paint, Size size, double xOffset, double yOffset, double scaleFactor) {
    final double cloudBaseSize = size.width * scaleFactor; // Base size relative to screen width
    final Path path = Path()
      ..moveTo(xOffset + 50 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 50 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 120 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 120 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset + 100 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset + 80 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 20 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset - 20 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset - 20 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RainyBackgroundPainter oldDelegate) {
    return oldDelegate.isDay != isDay || oldDelegate.animationValue != animationValue;
  }
}

/// Painter for Snowy conditions.
class SnowyBackgroundPainter extends CustomPainter {
  final bool isDay;
  final double animationValue; // Used for snowflake animation
  final List<Offset> _snowflakeInitialPositions; // Store initial snowflake positions
  final List<double> _cloudInitialXOffsets; // Store initial cloud X offsets
  final List<double> _cloudInitialYOffsets; // Store initial cloud Y offsets
  final List<double> _cloudScales; // Store individual cloud scales


  SnowyBackgroundPainter({required this.isDay, required this.animationValue})
      : _snowflakeInitialPositions = List.generate(150, (index) {
    final random = math.Random(index);
    return Offset(random.nextDouble(), -random.nextDouble() * 0.5); // Start above screen
  }),
        _cloudInitialXOffsets = List.generate(4, (index) => math.Random(index).nextDouble()), // 4 clouds
        _cloudInitialYOffsets = List.generate(4, (index) => math.Random(index + 100).nextDouble() * 0.2 + 0.1), // Top 10-30%
        _cloudScales = List.generate(4, (index) => 0.0018 + math.Random(index + 200).nextDouble() * 0.0005); // Vary scale slightly


  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Sky Gradient (fills entire canvas)
    final Gradient skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDay
          ? [kSnowyDaySkyColor, kSnowyDaySkyColor.withAlpha((255 * 0.7).round())]
          : [kSnowyNightSkyColor, kSnowyNightSkyColor.withAlpha((255 * 0.7).round())],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    paint.shader = null;

    // Clouds (light grey) - Using similar robust drawing as CloudyPainter
    int numberOfSnowClouds = _cloudInitialXOffsets.length;
    double snowCloudOpacity = 0.85;

    paint.color = (isDay ? kCloudColorLight : kCloudColorDark).withAlpha((255 * snowCloudOpacity).round());

    // Define the total horizontal travel distance for clouds (e.g., 2.5 times screen width)
    final double totalCloudTravelDistance = size.width * 2.5;
    final double cloudSpeedFactor = 0.15; // Speed for snow clouds

    for (int i = 0; i < numberOfSnowClouds; i++) {
      final double startX = _cloudInitialXOffsets[i] * size.width * 1.5;
      final double xPos = (startX + (totalCloudTravelDistance * animationValue * cloudSpeedFactor)) % totalCloudTravelDistance - size.width * 0.75;
      final double yOffset = _cloudInitialYOffsets[i] * size.height;
      final double cloudScaleFactor = _cloudScales[i];

      _drawCloud(canvas, paint, size, xPos, yOffset, cloudScaleFactor);
    }

    // Snowflakes
    paint.color = kSnowflakeColor;
    double snowSpeedFactor = 0.6; // Speed for snowflakes
    double totalFallDistance = size.height * 1.5; // Allow flakes to fall further off-screen

    for (int i = 0; i < _snowflakeInitialPositions.length; i++) {
      final Offset initialPos = _snowflakeInitialPositions[i];
      final double snowX = initialPos.dx * size.width;
      final double currentY = (initialPos.dy * totalFallDistance + (animationValue * totalFallDistance * snowSpeedFactor)) % totalFallDistance;
      final double displayY = currentY; // Corrected to use currentY directly

      canvas.drawCircle(Offset(snowX, displayY), 2.0, paint);
    }
  }

  // Unified _drawCloud method for SnowyBackgroundPainter
  void _drawCloud(Canvas canvas, Paint paint, Size size, double xOffset, double yOffset, double scaleFactor) {
    final double cloudBaseSize = size.width * scaleFactor; // Base size relative to screen width
    final Path path = Path()
      ..moveTo(xOffset + 50 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 50 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset, xOffset + 100 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..cubicTo(xOffset + 120 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 120 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset + 100 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset + 80 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 20 * cloudBaseSize, yOffset + 80 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 60 * cloudBaseSize)
      ..cubicTo(xOffset - 20 * cloudBaseSize, yOffset + 60 * cloudBaseSize, xOffset - 20 * cloudBaseSize, yOffset + 20 * cloudBaseSize, xOffset + 0 * cloudBaseSize, yOffset + 20 * cloudBaseSize)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SnowyBackgroundPainter oldDelegate) {
    return oldDelegate.isDay != isDay || oldDelegate.animationValue != animationValue;
  }
}

/// Painter for Atmosphere conditions (Mist, Smoke, Haze, Fog, etc.).
class AtmosphereBackgroundPainter extends CustomPainter {
  final bool isDay;
  final double animationValue;

  AtmosphereBackgroundPainter({required this.isDay, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Sky Gradient (fills entire canvas)
    final Gradient skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDay
          ? [Colors.grey.shade400, Colors.grey.shade600]
          : [Colors.grey.shade800, Colors.grey.shade900],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    paint.shader = null;

    // Subtle, slow-moving haze/clouds
    paint.color = isDay ? Colors.white.withAlpha((255 * 0.4).round()) : Colors.grey.shade700.withAlpha((255 * 0.3).round());
    _drawHazePatch(canvas, paint, size, (size.width * 0.1 + (size.width * 0.1 * animationValue)) % (size.width * 1.2) - size.width * 0.1, size.height * 0.3, size.width * 0.4);
    _drawHazePatch(canvas, paint, size, (size.width * 0.5 - (size.width * 0.08 * animationValue)) % (size.width * 1.2) - size.width * 0.1, size.height * 0.5, size.width * 0.3);
    _drawHazePatch(canvas, paint, size, (size.width * 0.8 + (size.width * 0.05 * animationValue)) % (size.width * 1.2) - size.width * 0.1, size.height * 0.2, size.width * 0.5);
  }

  void _drawHazePatch(Canvas canvas, Paint paint, Size size, double xOffset, double yOffset, double width) {
    final double height = width * 0.3; // Proportionate height
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(xOffset, yOffset, width, height), Radius.circular(width * 0.2)));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AtmosphereBackgroundPainter oldDelegate) {
    return oldDelegate.isDay != isDay || oldDelegate.animationValue != animationValue;
  }
}