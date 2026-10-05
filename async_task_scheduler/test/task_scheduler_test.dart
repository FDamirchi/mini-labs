  import 'package:async_task_scheduler/task_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records failures, logs outcomes, and runs each task once', () async {
    final repository = TaskRepository();
    final logs = <String>[];

    final syncError = StateError('sync failure');
    final asyncError = StateError('async failure');
    var successfulRuns = 0;

    repository
      ..add(Task(
        id: '1',
        name: 'Sync failure',
        action: () => throw syncError,
      ))
      ..add(Task(
        id: '2',
        name: 'Async failure',
        action: () async {
          await Future<void>.delayed(Duration.zero);
          throw asyncError;
        },
      ))
      ..add(Task(
        id: '3',
        name: 'Success',
        action: () async {
          successfulRuns++;
        },
      ));

    final scheduler = TaskScheduler(repository, logger: logs.add);

    await scheduler.runAll();
    await scheduler.runAll();

    final tasks = repository.all;

    expect(tasks.map((task) => task.status), [
      TaskStatus.failed,
      TaskStatus.failed,
      TaskStatus.completed,
    ]);

    expect(tasks[0].error, same(syncError));
    expect(tasks[1].error, same(asyncError));
    expect(tasks[0].stackTrace, isNotNull);
    expect(tasks[1].stackTrace, isNotNull);
    expect(successfulRuns, 1);

    expect(logs.where((line) => line.contains('START')).length, 3);
    expect(logs.where((line) => line.contains('FAIL')).length, 2);
    expect(logs.where((line) => line.contains('DONE')).length, 1);
  });

  test('runs concurrently without exceeding the worker limit', () async {
    final repository = TaskRepository();

    var active = 0;
    var peak = 0;
    var completed = 0;

    for (var i = 0; i < 5; i++) {
      repository.add(Task(
        id: '$i',
        name: 'Task $i',
        action: () async {
          active++;

          if (active > peak) peak = active;

          await Future<void>.delayed(const Duration(milliseconds: 1));

          active--;
          completed++;
        },
      ));
    }

    await TaskScheduler(
      repository,
      maxConcurrent: 2,
      logger: (_) {},
    ).runAll();

    expect(peak, 2);
    expect(active, 0);
    expect(completed, 5);

    expect(
      repository.all.every(
        (task) => task.status == TaskStatus.completed,
      ),
      isTrue,
    );
  });

  test('rejects duplicate IDs and invalid worker counts', () {
    final repository = TaskRepository();
    final task = Task(id: '1', name: 'Task', action: () async {});

    repository.add(task);

    expect(() => repository.add(task), throwsArgumentError);

    expect(
      () => TaskScheduler(repository, maxConcurrent: 0),
      throwsArgumentError,
    );
  });
}