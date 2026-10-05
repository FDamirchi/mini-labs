import 'dart:io';

import 'ride_sharing.dart';

Future<void> runSimulation() async {
  final service = BookingService([
    Driver(id: 'D1', name: 'Reza'),
    Driver(id: 'D2', name: 'Nima'),
  ]);

  const ali = Rider(id: 'R1', name: 'Ali');
  const sara = Rider(id: 'R2', name: 'Sara');
  const mina = Rider(id: 'R3', name: 'Mina');

  stdout.writeln('1. Two bookings at the same time');

  await Future.wait<Trip>([
    service.bookTrip(
      ali,
      pickup: 'Home',
      destination: 'University',
    ),
    service.bookTrip(
      sara,
      pickup: 'Office',
      destination: 'Station',
    ),
  ]);

  stdout.writeln('\n2. A simulated trip failure');

  await service.bookTrip(
    mina,
    pickup: 'Park',
    destination: 'Library',
    simulateFailure: true,
  );

  stdout.writeln('\n3. Book again after the failure');

  await service.bookTrip(
    mina,
    pickup: 'Park',
    destination: 'Library',
  );

  stdout.writeln('\nFinal trips:');

  for (final trip in service.trips) {
    stdout.writeln(
      '${trip.id}: ${trip.rider.name}, '
      '${trip.driver?.name ?? '-'}, ${trip.status.name}',
    );
  }

  final available = service.drivers.where(
    (driver) => driver.isAvailable,
  );

  stdout.writeln('Available drivers: ${available.length}');
}
