import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../data/models/todo_model.dart';
import '../data/database.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceText = '';
  String _selectedLanguage = 'ar_SA'; // تعيين العربية كلغة افتراضية
  Timer? _silenceTimer;
  DateTime? _lastSpeechTime;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasPermission = status.isGranted;
    });
    if (!status.isGranted) {
      await Permission.microphone.request();
      final newStatus = await Permission.microphone.status;
      setState(() {
        _hasPermission = newStatus.isGranted;
      });
    }
  }

  Future<void> _initializeSpeech() async {
    if (!_hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى السماح بالوصول إلى الميكروفون',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _stopListening();
        }
      },
      onError: (errorNotification) {
        _stopListening();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ في التعرف على الصوت',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خدمة التعرف على الصوت غير متوفرة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startListening() async {
    if (!_hasPermission) {
      await _checkPermissions();
      if (!_hasPermission) return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
        onError: (errorNotification) {
          _stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'حدث خطأ في التعرف على الصوت',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _voiceText = '';
          _lastSpeechTime = DateTime.now();
        });
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _voiceText = result.recognizedWords;
              _textController.text = _voiceText;
              _lastSpeechTime = DateTime.now();
            });
            _resetSilenceTimer();
          },
          localeId: _selectedLanguage,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خدمة التعرف على الصوت غير متوفرة',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _silenceTimer?.cancel();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(minutes: 3), () {
      if (_isListening) {
        if (_lastSpeechTime != null && 
            DateTime.now().difference(_lastSpeechTime!) > const Duration(minutes: 3)) {
          _stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إيقاف التسجيل لعدم وجود صوت',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    });
  }

  void _saveTodo() {
    if (_textController.text.isNotEmpty) {
      final todo = TodoModel(
        title: _textController.text,
        isCompleted: false,
      );
      final todoBox = Hive.box<TodoModel>('todoBox');
      todoBox.add(todo);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ المهمة بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      _textController.clear();
      setState(() {
        _voiceText = '';
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _silenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _saveTodo,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.cairo(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'أضف مهمة جديدة...',
                        hintStyle: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.blue : Colors.white,
                    ).animate(target: _isListening ? 1 : 0)
                     .scale(duration: 300.ms, curve: Curves.easeInOut)
                     .fadeIn(),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _saveTodo,
                  ),
                ],
              ),
            ),
          ),
          
          // Voice Recording Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_voiceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _voiceText,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  spreadRadius: 8,
                                  blurRadius: 24,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 32,
                      ).animate(target: _isListening ? 1 : 0)
                       .scale(duration: 300.ms, curve: Curves.easeInOut)
                       .fadeIn(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isListening ? 'انقر للإيقاف' : 'انقر للتحدث',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Language Selector
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF1B2B3A),
                    style: GoogleFonts.cairo(color: Colors.white),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(value: 'ar_SA', child: Text('العربية')),
                      DropdownMenuItem(value: 'en_US', child: Text('English')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedLanguage = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
