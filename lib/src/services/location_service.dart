import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> currentPosition() async {
    if (!await _canUseLocation()) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Future<Stream<Position>?> positionStream(
      {int distanceFilterMeters = 500}) async {
    if (!await _canUseLocation()) {
      return null;
    }

    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  Future<bool> _canUseLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }
}
