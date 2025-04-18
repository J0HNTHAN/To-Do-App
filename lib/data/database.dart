import 'package:hive_flutter/hive_flutter.dart';

import 'models/todo_model.dart';


class TodoDatabase{

  final _myBox = Hive.box<TodoModel>('todoBox');

  // void loadData(){
  //   todoList = _myBox.get('todoList');
  // }
  //
  // void updateDatabase(){
  //   _myBox.put('todoList', todoList);
  // }

  void addTodo(TodoModel todoModel){
    _myBox.add(todoModel);
  }

  List<TodoModel> loadTodos(){
    return _myBox.values.toList();
  }
}