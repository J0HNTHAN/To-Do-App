import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import '../components/dialog_box.dart';
import '../components/todo_tile.dart';
import '../data/database.dart';
import '../data/models/todo_model.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TodoModel> todoList = [];

  final _myBox = Hive.box<TodoModel>('todoBox');
  var todoDatabase = TodoDatabase();
  final _controller = TextEditingController();

  // Voice-to-text state
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = '';
  String _selectedLanguage = 'en_US';
  DateTime? _lastSpeechTime;
  Timer? _silenceTimer;
  String? _voiceErrorMsg;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    if (_myBox.isNotEmpty) {
      todoList = todoDatabase.loadTodos();
    }
    _speech = stt.SpeechToText();
    _checkMicPermission();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    super.dispose();
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isListening && _lastSpeechTime != null) {
        final diff = DateTime.now().difference(_lastSpeechTime!);
        if (diff.inSeconds > 180) {
          _stopListening();
        }
      }
    });
  }

  void _stopSilenceTimer() {
    _silenceTimer?.cancel();
  }

  void _resetVoiceState() {
    setState(() {
      _voiceText = '';
      _voiceErrorMsg = null;
    });
  }

  Future<bool> _checkMicPermission() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    return true;
  }

  Future<void> _startListening() async {
    if (!await _checkMicPermission()) {
      setState(() {
        _voiceErrorMsg = 'Microphone permission denied.';
      });
      return;
    }
    if (_isListening) {
      _stopListening();
      return;
    }
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _stopListening();
        }
      },
      onError: (error) {
        setState(() {
          _voiceErrorMsg = error.errorMsg ?? 'Voice recognition error';
        });
        _stopListening();
      },
    );
    if (available) {
      setState(() {
        _isListening = true;
        _voiceText = '';
        _lastSpeechTime = DateTime.now();
        _voiceErrorMsg = null;
      });
      _startSilenceTimer();
      await _speech.listen(
        localeId: _selectedLanguage,
        onResult: (result) {
          setState(() {
            _voiceText = result.recognizedWords;
            _controller.text = _voiceText;
            _lastSpeechTime = DateTime.now();
          });
        },
      );
    } else {
      setState(() {
        _voiceErrorMsg = 'Speech recognition not available';
      });
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _stopSilenceTimer();
  }

  void _onLanguageChanged(String? lang) {
    if (lang != null) {
      setState(() {
        _selectedLanguage = lang;
      });
    }
  }

  void onCheckboxChanged(bool? value, int index) {
    setState(() {
      todoList[index].isCompleted = !todoList[index].isCompleted;
      _myBox.putAt(index, todoList[index]); // Update the task in Hive
    });
  }

  void saveNewTask() {
    setState(() {
      var newTask = TodoModel(title: _controller.text, isCompleted: false);
      todoList.add(newTask);
      todoDatabase.addTodo(newTask);
    });
    _controller.clear();
    Navigator.pop(context);
  }

  void cancelDialog() {
    _controller.clear();
    Navigator.pop(context);
  }

  void createNewTask() {
    _resetVoiceState();
    _controller.clear();
    showDialog(
      context: context,
      builder: (context) {
        return DialogBox(
          controller: _controller,
          onSave: saveNewTask,
          onCancel: () {
            _resetVoiceState();
            cancelDialog();
          },
          onStartVoice: _startListening,
          onStopVoice: _stopListening,
          voiceText: _voiceText,
          isRecording: _isListening,
          selectedLanguage: _selectedLanguage,
          onLanguageChanged: _onLanguageChanged,
          errorMsg: _voiceErrorMsg,
        );
      },
    );
  }

  // New function to handle editing a todo
  void editTask(int index) {
    _controller.text = todoList[index].title;
    String _editVoiceText = '';
    bool _editIsListening = false;
    String _editSelectedLanguage = _selectedLanguage;
    String? _editVoiceErrorMsg;
    stt.SpeechToText _editSpeech = stt.SpeechToText();

    Future<void> _editStartListening() async {
      if (!await _checkMicPermission()) {
        setState(() {
          _editVoiceErrorMsg = 'Microphone permission denied.';
        });
        return;
      }
      _editVoiceErrorMsg = null;
      bool available = await _editSpeech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _editSpeech.stop();
            setState(() {
              _editIsListening = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _editVoiceErrorMsg = error.errorMsg ?? 'Voice recognition error';
            _editIsListening = false;
          });
        },
      );
      if (available) {
        setState(() {
          _editIsListening = true;
          _editVoiceText = '';
          _editVoiceErrorMsg = null;
        });
        _editSpeech.listen(
          localeId: _editSelectedLanguage,
          onResult: (result) {
            setState(() {
              _editVoiceText = result.recognizedWords;
              _controller.text = _editVoiceText;
            });
          },
        );
      } else {
        setState(() {
          _editVoiceErrorMsg = 'Speech recognition not available';
        });
      }
    }

    void _editStopListening() {
      _editSpeech.stop();
      setState(() {
        _editIsListening = false;
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Enter updated task'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _editSelectedLanguage,
                        items: const [
                          DropdownMenuItem(value: 'ar_SA', child: Text('Arabic')),
                          DropdownMenuItem(value: 'en_US', child: Text('English')),
                        ],
                        onChanged: (lang) {
                          setStateDialog(() {
                            _editSelectedLanguage = lang!;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(_editIsListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                        color: _editIsListening ? Colors.green : Colors.grey,
                        onPressed: _editIsListening ? _editStopListening : _editStartListening,
                        tooltip: 'Voice Input',
                      ),
                    ],
                  ),
                  if (_editVoiceErrorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_editVoiceErrorMsg!, style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _controller.clear();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      setState(() {
                        todoList[index].title = _controller.text.trim();
                        _myBox.putAt(index, todoList[index]);
                        _controller.clear();
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Authentication check (pseudo, replace with your logic)
    // if (!isAuthenticated) {
    //   Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
    // }

    final Color scaffoldBg = _isDarkMode ? const Color(0xFF181A20) : Colors.white;
    final Color cardBg = _isDarkMode ? const Color(0xFF23262B) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color inputBorderColor = _isDarkMode ? Colors.white24 : Colors.black12;
    final Color iconColor = _isDarkMode ? Colors.white : Colors.black;
    final Color micBg = _isDarkMode ? Colors.grey[800]! : Colors.white;
    final Color micIconColor = _isDarkMode ? Colors.greenAccent : Colors.green;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text('Just Do It ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: iconColor),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: iconColor),
            onPressed: () => Navigator.pushNamed(context, '/settingspage'),
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: iconColor),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
            },
            tooltip: 'Toggle Dark Mode',
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text('Logout', style: TextStyle(color: iconColor)),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _isDarkMode ? Colors.black54 : Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Capture your tasks with voice or text, your way.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Add a task...',
                            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: inputBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: inputBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: iconColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          ),
                          onSubmitted: (_) => _handleAddTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _handleAddTask,
                          child: const Text('Add Task'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: cardBg,
                        style: TextStyle(color: textColor),
                        items: const [
                          DropdownMenuItem(value: 'ar_SA', child: Text('Arabic')),
                          DropdownMenuItem(value: 'en_US', child: Text('English')),
                        ],
                        onChanged: _onLanguageChanged,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: micBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: micIconColor),
                              onPressed: _startListening,
                              tooltip: 'Voice Input',
                            ),
                            if (_isListening)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.green,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.list, color: iconColor),
                        label: Text('List View', style: TextStyle(color: textColor)),
                      ),
                    ],
                  ),
                  if (_voiceErrorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_voiceErrorMsg!, style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            // Task List
            Expanded(
              child: ListView.builder(
                itemCount: todoList.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Dismissible(
                      key: Key(todoList[index].title),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white, size: 32),
                      ),
                      onDismissed: (direction) {
                        setState(() {
                          todoList.removeAt(index);
                          _myBox.deleteAt(index);
                        });
                      },
                      child: Card(
                        color: cardBg,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: Checkbox(
                            value: todoList[index].isCompleted,
                            onChanged: (value) => onCheckboxChanged(value, index),
                          ),
                          title: Text(
                            todoList[index].title,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                              decoration: todoList[index].isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => editTask(index),
                                icon: Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    todoList.removeAt(index);
                                    _myBox.deleteAt(index);
                                  });
                                },
                                icon: Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAddTask() {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _voiceErrorMsg = 'Please enter a task.';
      });
      return;
    }
    setState(() {
      var newTask = TodoModel(title: _controller.text.trim(), isCompleted: false);
      todoList.add(newTask);
      todoDatabase.addTodo(newTask);
      _controller.clear();
      _voiceText = '';
      _voiceErrorMsg = null;
    });
  }
}
