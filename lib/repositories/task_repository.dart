import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/models/task_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class TaskRepository {
  static final TaskRepository _instance = TaskRepository._internal();
  factory TaskRepository() => _instance;
  TaskRepository._internal();

  final List<Task> _tasks = [];
  final _controller = StreamController<List<Task>>.broadcast();

  Stream<List<Task>> get tasksStream => _controller.stream;
  List<Task> get currentTasks => List.unmodifiable(_tasks);

  void addTask(String title, {String description = '', DateTime? dueDate, String? sourceConversationId, String? sourceMessageId, String status = 'pending'}) {
    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      status: status,
      sourceConversationId: sourceConversationId,
      sourceMessageId: sourceMessageId,
    );
    _tasks.add(newTask);
    _controller.add(_tasks);
    _saveTasks();
    debugPrint("TaskRepo: Added task '${newTask.title}'");
  }
  
  void addTaskObject(Task task) {
       _tasks.add(task);
       _controller.add(_tasks);
       _saveTasks();
       debugPrint("TaskRepo: Added task object '${task.title}'");
  }

  void updateTask(String id, {String? title, String? description, DateTime? dueDate, bool? isCompleted, String? status}) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final oldTask = _tasks[index];
      _tasks[index] = Task(
        id: oldTask.id,
        title: title ?? oldTask.title,
        description: description ?? oldTask.description,
        dueDate: dueDate ?? oldTask.dueDate,
        isCompleted: isCompleted ?? oldTask.isCompleted,
        status: status ?? oldTask.status,
        sourceConversationId: oldTask.sourceConversationId,
        sourceMessageId: oldTask.sourceMessageId,
      );
      _controller.add(_tasks);
      _saveTasks();
      debugPrint("TaskRepo: Updated task '${_tasks[index].title}'");
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _tasks.removeWhere((t) => t.id == id);
    _controller.add(_tasks);
    _saveTasks();
    debugPrint("TaskRepo: Deleted task $id");
  }
  
  // New method to handle batch updates from analysis
  void handleAnalysisUpdates({List<Task>? newTasks, List<Map<String, dynamic>>? updates}) {
      bool changed = false;
      
      if (newTasks != null) {
          for (var task in newTasks) {
              _tasks.add(task);
              changed = true;
          }
      }
      
      if (updates != null) {
          for (var update in updates) {
              final id = update['id'];
              final index = _tasks.indexWhere((t) => t.id == id);
              if (index != -1) {
                  final oldTask = _tasks[index];
                  // Safe parsing
                  DateTime? newDueDate = update['dueDate'] != null ? DateTime.tryParse(update['dueDate']) : oldTask.dueDate;
                  
                  _tasks[index] = Task(
                    id: oldTask.id,
                    title: update['title'] ?? oldTask.title,
                    description: update['description'] ?? oldTask.description,
                    dueDate: newDueDate,
                    isCompleted: update['isCompleted'] ?? oldTask.isCompleted,
                    status: update['status'] ?? oldTask.status,
                    sourceConversationId: oldTask.sourceConversationId,
                    sourceMessageId: oldTask.sourceMessageId,
                  );
                  changed = true;
              }
          }
      }
      
      if (changed) {
          _controller.add(_tasks);
          _saveTasks();
          debugPrint("TaskRepo: Processed analysis updates.");
      }
  }
  // --- Persistence ---

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadTasks();
    _isInitialized = true;
  }

  Future<void> _loadTasks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/tasks.json');
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> list = jsonDecode(jsonStr);
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e)).toList());
        _controller.add(_tasks);
        debugPrint("TaskRepo: Loaded ${_tasks.length} tasks");
      }
    } catch (e) {
      debugPrint("TaskRepo: Error loading tasks: $e");
    }
  }

  Future<void> _saveTasks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/tasks.json');
      final jsonStr = jsonEncode(_tasks.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint("TaskRepo: Error saving tasks: $e");
    }
  }

  Future<void> reset() async {
      _tasks.clear();
      _controller.add(_tasks);
      try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/tasks.json');
          if (await file.exists()) {
              await file.delete();
          }
      } catch (e) {
          debugPrint("TaskRepo: Error clearing tasks: $e");
      }
  }
}
