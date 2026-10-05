import 'package:flutter_test/flutter_test.dart';
import 'package:ride_sharing_simulation/ride_sharing.dart';

const ali = Rider(id: 'R1', name: 'Ali');
const sara = Rider(id: 'R2', name: 'Sara');

BookingService makeService({
  int driverCount = 1,
  void Function(String)? logger,
}) {
  return BookingService(
    List.generate(
      driverCount,
      (i) => Driver(id: 'D$i', name: 'Driver $i'),
    ),
    stepDelay: Duration.zero,
    tripDuration: Duration.zero,
    logger: logger ?? (_) {},
  );
}

Future<Trip> book(
  BookingService service,
  Rider rider, {
  bool simulateFailure = false,
}) {
  return service.bookTrip(
    rider,
    pickup: 'Home',
    destination: 'University',
    simulateFailure: simulateFailure,
  );
}

void main() {
  test('successful trip follows its lifecycle and releases its driver',
      () async {
    final states = <TripStatus>[];
    late BookingService service;

    service = makeService(
      logger: (_) => states.add(service.trips.last.status),
    );

    final trip = await book(service, ali);

    expect(states, [
      TripStatus.requested,
      TripStatus.matched,
      TripStatus.inProgress,
      TripStatus.completed,
    ]);

    expect(trip.driver, same(service.drivers.first));
    expect(trip.error, isNull);
    expect(service.drivers.first.isAvailable, isTrue);
  });

  test('one driver cannot serve two overlapping bookings', () async {
    final service = makeService();

    final trips = await Future.wait<Trip>([
      book(service, ali),
      book(service, sara),
    ]);

    expect(trips[0].status, TripStatus.completed);
    expect(trips[1].status, TripStatus.failed);
    expect(trips[1].error, isA<BookingException>());

    final retry = await book(service, sara);

    expect(retry.status, TripStatus.completed);
  });

  test('one rider ID cannot have two active bookings', () async {
    final service = makeService(driverCount: 2);
    const sameRider = Rider(id: 'R1', name: 'Ali');

    final trips = await Future.wait<Trip>([
      book(service, ali),
      book(service, sameRider),
      book(service, sameRider),
    ]);

    expect(trips[0].status, TripStatus.completed);
    expect(trips[1].status, TripStatus.failed);
    expect(trips[2].status, TripStatus.failed);

    expect(
      service.drivers.every((driver) => driver.isAvailable),
      isTrue,
    );
  });

  test('failed trip releases resources and allows rebooking', () async {
    final service = makeService();

    final failed = await book(
      service,
      ali,
      simulateFailure: true,
    );

    expect(failed.status, TripStatus.failed);
    expect(failed.error, isA<BookingException>());
    expect(failed.stackTrace, isNotNull);
    expect(service.drivers.first.isAvailable, isTrue);

    final recovered = await book(service, ali);

    expect(recovered.status, TripStatus.completed);
    expect(recovered.id, isNot(failed.id));
    expect(failed.status, TripStatus.failed);
  });

  test('invalid route fails without blocking a later booking', () async {
    final service = makeService();

    final invalid = await service.bookTrip(
      ali,
      pickup: 'Home',
      destination: ' ',
    );

    expect(invalid.status, TripStatus.failed);
    expect(invalid.driver, isNull);
    expect(service.drivers.first.isAvailable, isTrue);

    final valid = await book(service, ali);

    expect(valid.status, TripStatus.completed);
  });
}
