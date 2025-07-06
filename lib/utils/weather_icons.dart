// lib/utils/weather_icons.dart

/// Returns a weather emoji based on the OpenWeatherMap icon code.
String getWeatherEmoji(String iconCode) {
  if (iconCode.contains('01')) return '☀️'; // Clear sky
  if (iconCode.contains('02')) return '🌤️'; // Few clouds
  if (iconCode.contains('03') || iconCode.contains('04')) return '☁️'; // Scattered clouds, Broken clouds
  if (iconCode.contains('09') || iconCode.contains('10')) return '🌧️'; // Shower rain, Rain
  if (iconCode.contains('11')) return '⛈️'; // Thunderstorm
  if (iconCode.contains('13')) return '❄️'; // Snow
  if (iconCode.contains('50')) return '🌫️'; // Mist
  return '❓'; // Unknown or other
}