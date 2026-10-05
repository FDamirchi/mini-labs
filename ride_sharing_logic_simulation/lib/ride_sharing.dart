import 'dart:io';

enum TripStatus { requested, matched, inProgress, completed, failed }

class Driver {
  Driver({required this.id, required this.name});

  final String id;
  final String name;

  bool _isAvailable = true;

  bool get isAvailable => _isAvailable;
}

class Rider {
  const Rider({required this.id, required this.name});

  final String id;
  final String name;
}

class Trip {
  Trip._({
    required this.id,
    required this.rider,
    required this.pickup,
    required this.destination,
  });

  final String id;
  final Rider rider;
  final String pickup;
  final String destination;

  Driver? _driver;
  TripStatus _status = TripStatus.requested;
  Object? _error;
  StackTrace? _stackTrace;

  Driver? get driver => _driver;
  TripStatus get status => _status;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;
}

class BookingException implements Exception {
  const BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

void _consoleLog(String message) => stdout.writeln(message);

class BookingService {
  BookingService(
    List<Driver> drivers, {
    this.stepDelay = const Duration(milliseconds: 250),
    this.tripDuration = const Duration(milliseconds: 500),
    void Function(String)? logger,
  })  : _drivers = List<Driver>.unmodifiable(drivers),
        _logger = logger ?? _consoleLog {
    final ids = _drivers.map((driver) => driver.id).toSet();

    if (ids.length != _drivers.length || ids.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Driver IDs must be non-empty and unique.');
    }

    if (stepDelay.isNegative || tripDuration.isNegative) {
      throw ArgumentError('Delays cannot be negative.');
    }
  }

  final List<Driver> _drivers;
  final Duration stepDelay;
  final Duration tripDuration;
  final void Function(String) _logger;

  final List<Trip> _trips = [];
  final Set<String> _activeRiders = {};

  int _nextTripId = 1;

  List<Driver> get drivers => _drivers;
  List<Trip> get trips => List<Trip>.unmodifiable(_trips);

  Future<Trip> bookTrip(
    Rider rider, {
    required String pickup,
    required String destination,
    bool simulateFailure = false,
  }) async {
    final trip = Trip._(
      id: 'T${_nextTripId++}',
      rider: rider,
      pickup: pickup.trim(),
      destination: destination.trim(),
    );

    _trips.add(trip);

    Driver? driver;
    var riderReserved = false;

    try {
      _log(
        trip,
        '${rider.name}: ${trip.pickup} -> ${trip.destination}',
      );

      if (rider.id.trim().isEmpty ||
          trip.pickup.isEmpty ||
          trip.destination.isEmpty) {
        throw const BookingException(
          'Rider ID, pickup, and destination are required.',
        );
      }

      if (_activeRiders.contains(rider.id)) {
        throw const BookingException(
          'Rider already has an active booking.',
        );
      }

      for (final candidate in _drivers) {
        if (candidate.isAvailable) {
          driver = candidate;
          break;
        }
      }

      if (driver == null) {
        throw const BookingException('No available driver.');
      }

      // Reserve both resources before the first await.
      driver._isAvailable = false;
      _activeRiders.add(rider.id);
      riderReserved = true;

      await Future<void>.delayed(stepDelay);

      trip._driver = driver;
      trip._status = TripStatus.matched;
      _log(trip, 'Driver: ${driver.name}');

      await Future<void>.delayed(stepDelay);

      trip._status = TripStatus.inProgress;
      _log(trip);

      await Future<void>.delayed(tripDuration);

      if (simulateFailure) {
        throw const BookingException('Simulated trip failure.');
      }

      trip._status = TripStatus.completed;
      _log(trip);
    } catch (error, stackTrace) {
      trip._status = TripStatus.failed;
      trip._error = error;
      trip._stackTrace = stackTrace;

      _log(trip, '$error');
    } finally {
      if (driver != null) {
        driver._isAvailable = true;
      }

      if (riderReserved) {
        _activeRiders.remove(rider.id);
      }
    }

    return trip;
  }

  void _log(Trip trip, [String detail = '']) {
    final suffix = detail.isEmpty ? '' : ' | $detail';

    _logger(
      '[${DateTime.now().toIso8601String()}] '
      '${trip.id}: ${trip.status.name}$suffix',
    );
  }
}
