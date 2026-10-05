import 'dart:io';

import 'task_scheduler.dart';

Future<void> _delay(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

Future<void> runDemo() async {
  final repository = TaskRepository()
    ..add(Task(
      id: '1',
      name: 'Task A',
      action: () => _delay(1000),
    ))
    ..add(Task(
      id: '2',
      name: 'Task B',
      action: () => _delay(500),
    ))
    ..add(Task(
      id: '3',
      name: 'Failing task',
      action: () async {
        await _delay(100);
        throw StateError('This failure is intentional.');
      },
    ))
    ..add(Task(
      id: '4',
      name: 'Task C',
      action: () => _delay(200),
    ));

  await TaskScheduler(repository, maxConcurrent: 2).runAll();

  stdout.writeln('\nFinal status:');

  for (final task in repository.all) {
    stdout.writeln('${task.id} ${task.name}: ${task.status.name}');
  }
}