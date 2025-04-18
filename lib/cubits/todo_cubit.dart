import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

import '../data/models/todo_model.dart';

class TodoCubit extends Cubit<List<TodoModel>> {
  final Box<TodoModel> _todoBox;

  TodoCubit(this._todoBox) : super([]) {
    // Load the initial list of todos from the Hive box
    loadTodos();
  }

  // Load the todos list from Hive
  void loadTodos() {
    if (_todoBox.isNotEmpty) {
      emit(_todoBox.values.toList());
    }
  }

  // Add a new task
  void addTodo(String title) {
    final newTask = TodoModel(title: title, isCompleted: false);
    _todoBox.add(newTask);
    emit([...state, newTask]);
  }

  // Update a task (toggle completion)
  void updateTodo(int index) {
    final updatedTask = state[index];
    updatedTask.isCompleted = !updatedTask.isCompleted;
    _todoBox.putAt(index, updatedTask);
    emit([...state]);
  }

  // Delete a task
  void deleteTodo(int index) {
    _todoBox.deleteAt(index);
    emit([...state]..removeAt(index));
  }

  // Edit a task (update the title)
  void editTodo(int index, String newTitle) {
    final updatedTask = state[index];
    updatedTask.title = newTitle; // Update the title
    _todoBox.putAt(index, updatedTask); // Save the updated task to Hive
    emit([...state]); // Emit the updated state to refresh the UI
  }
}