// lib/consts/consts_weather_background.dart

import 'package:flutter/material.dart';

/// Enum representing various weather conditions for background animation.
enum WeatherCondition {
  sunny,
  clear, // Can be used interchangeably with sunny if no distinct animation
  cloudy, // General cloudy, will be refined
  fewClouds, // For 02d/n
  scatteredClouds, // For 03d/n
  brokenClouds, // For 04d/n (overcast)
  rainy,
  drizzle, // Can be used interchangeably with rainy
  thunderstorm, // Can be used interchangeably with rainy
  snowy,
  atmosphere, // For mist, smoke, haze, fog (50d/n)
  unknown,
}

// --- Animation Durations ---
const Duration kCloudAnimationDuration = Duration(seconds: 40); // Slower clouds
const Duration kRainAnimationDuration = Duration(seconds: 2); // Fast rain
const Duration kSnowAnimationDuration = Duration(seconds: 10); // Medium snow
const Duration kSunMoonAnimationDuration = Duration(seconds: 6000); // Very subtle movement

// --- Colors for Sunny/Clear conditions ---
const Color kSunnyDaySkyColor = Color(0xFF87CEEB); // Sky Blue
const Color kSunnyNightSkyColor = Color(0xFF1A237E); // Deep Indigo
const Color kSunColor = Color(0xFFFFD700); // Gold
const Color kMoonColor = Color(0xFFF0F8FF); // Alice Blue
const Color kStarColor = Color(0xFFFFFFFF); // White

// --- Colors for Cloudy conditions (base blue sky, clouds drawn over) ---
// These will be the *base* sky colors, over which clouds are drawn.
const Color kCloudyDaySkyColor = Color(0xFF64B5F6); // A slightly muted blue for cloudy days
const Color kCloudyNightSkyColor = Color(0xFF2C3E50); // Darker blue-grey for cloudy nights

const Color kCloudColorLight = Color(0xFFFFFFFF); // White clouds
const Color kCloudColorDark = Color(0xFFB0BEC5); // Light grey clouds

// --- Colors for Rainy conditions ---
const Color kRainyDaySkyColor = Color(0xFF607D8B); // Blue Grey
const Color kRainyNightSkyColor = Color(0xFF37474F); // Darker Blue Grey
// Updated to a darker, more desaturated blue-grey for raindrops
const Color kRaindropColor = Color(0xFF90A4AE); // Blue Grey 300

// --- Colors for Snowy conditions ---
const Color kSnowyDaySkyColor = Color(0xFFB0BEC5); // Light Blue Grey
const Color kSnowyNightSkyColor = Color(0xFF546E7A); // Dark Blue Grey
const Color kSnowflakeColor = Color(0xFFFFFFFF); // White

// --- Colors for Ground (removed from painters, but kept for reference if needed elsewhere) ---
// const Color kGroundColorGreen = Color(0xFF8BC34A); // Light Green
// const Color kGroundColorBrown = Color(0xFF795548); // Brown
// const Color kGroundColorSnow = Color(0xFFE0F2F7); // Light Cyan