/// "Use my location" on the address step, as an optional capability: the
/// SDK reads no position itself and adds no location plugin. The app hands
/// it a [ConferBotLocationProvider] (`ConferBotConfig.locationProvider`),
/// for example on top of `geolocator`; without one the button is not drawn.
///
/// Web: `ts/chat/richNodesView.ts` (the address card's locate button,
/// `navigator.geolocation.getCurrentPosition`, then `geo/reverse`).
library;

/// A point on the map, in degrees.
class ConferBotLatLng {
  final double latitude;
  final double longitude;
  const ConferBotLatLng(this.latitude, this.longitude);

  /// A real point: finite, latitude within ±90 and longitude within ±180.
  bool get isValid =>
      latitude.isFinite && longitude.isFinite && latitude.abs() <= 90 && longitude.abs() <= 180;

  @override
  bool operator ==(Object other) => other is ConferBotLatLng && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'ConferBotLatLng($latitude, $longitude)';
}

/// The app's way to the device's position. Return null when it could not be
/// found; throw [ConferBotLocationDenied] when the visitor (or the system)
/// refused location access. Any other error counts as not found.
typedef ConferBotLocationProvider = Future<ConferBotLatLng?> Function();

/// Location access was refused: the step says so ("location access is
/// turned off") and the visitor types the address instead.
class ConferBotLocationDenied implements Exception {
  const ConferBotLocationDenied();
  @override
  String toString() => 'ConferBotLocationDenied';
}

/// How a location request ended: the point, or the address step's error
/// code ('denied' or 'unavailable', see `addressErrorText`).
Future<({ConferBotLatLng? at, String? error})> locate(
  ConferBotLocationProvider provider, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    final at = await provider().timeout(timeout);
    if (at == null || !at.isValid) return (at: null, error: 'unavailable');
    return (at: at, error: null);
  } on ConferBotLocationDenied {
    return (at: null, error: 'denied');
  } catch (_) {
    return (at: null, error: 'unavailable');
  }
}
