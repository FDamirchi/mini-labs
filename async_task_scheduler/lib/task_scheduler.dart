import 'dart:io';

enum TaskStatus { pending, running, completed, failed }

typedef TaskAction = Future<void> Function();

class Task {
  Task({
    required this.id,
    required this.name,
    required this.action,
  });

  final String id;
  final String name;
  final TaskAction action;

  TaskStatus _status = TaskStatus.pending;
  Object? _error;
  StackTrace? _stackTrace;

  TaskStatus get status => _status;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;
}

class TaskRepository {
  final Map<String, Task> _tasks = {};

  void add(Task task) {
    if (task.id.trim().isEmpty) {
      throw ArgumentError('Task ID cannot be empty.');
    }

    if (_tasks.containsKey(task.id)) {
      throw ArgumentError('Duplicate task ID: ${task.id}');
    }
    _tasks[task.id] = task;
  }

  List<Task> get all => List<Task>.unmodifiable(_tasks.values);
}

void _writeToConsole(String message) => stdout.writeln(message);

class TaskScheduler {
  TaskScheduler(
    this.repository, {
    this.maxConcurrent = 2,
    void Function(String)? logger,
  }) : _logger = logger ?? _writeToConsole {
    if (maxConcurrent < 1) {
      throw ArgumentError.value(
        maxConcurrent,
        'maxConcurrent',
        'Must be at least 1.',
      );
    }
  }

  final TaskRepository repository;
  final int maxConcurrent;
  final void Function(String) _logger;

  bool _isRunning = false;

  Future<void> runAll() async {
    if (_isRunning) {
      throw StateError('Scheduler is already running.');
    }

    _isRunning = true;

    try {
      final tasks = repository.all
          .where((task) => task.status == TaskStatus.pending)
          .toList();

      var nextIndex = 0;

      Future<void> worker() async {
        while (nextIndex < tasks.length) {
          final task = tasks[nextIndex++];

          if (task.status != TaskStatus.pending) continue;

          await _execute(task);
        }
      }

      final workers =
          tasks.length < maxConcurrent ? tasks.length : maxConcurrent;

      await Future.wait<void>(
        List.generate(workers, (_) => worker()),
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _execute(Task task) async {
    task._status = TaskStatus.running;
    _log('START [${task.id}] ${task.name}');

    try {
      await task.action();

      task._status = TaskStatus.completed;
      _log('DONE  [${task.id}] ${task.name}');
    } catch (error, stackTrace) {
      task._status = TaskStatus.failed;
      task._error = error;
      task._stackTrace = stackTrace;

      _log('FAIL  [${task.id}] ${task.name}: $error');
    }
  }

  void _log(String message) {
    _logger('[${DateTime.now().toIso8601String()}] $message');
  }
}