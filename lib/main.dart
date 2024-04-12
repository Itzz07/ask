import 'dart:convert';
import 'dart:io';
import 'package:ask/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ask',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
      ),
      home: const SplashScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final RxString _response = ''.obs;
  List<String> conversationHistory = [];
  bool isRecording = false;
  bool isSpeaking = false;
  bool _isLoading = false;
final ImagePicker _picker = ImagePicker();
PickedFile? _image;


  Future<void> _captureImage() async {
    _image = (await _picker.pickImage(source: ImageSource.camera)) as PickedFile?;
  }
 Future<void> _performOCR() async {
    if (_image != null) {
      String result = await FlutterScalableOcr.performOCR(_image!.path);
      print('Extracted Text: $result');
    }
  }

  @override
  void initState() {
    super.initState();
    _initSpeechRecognizer();
  }

  void _initSpeechRecognizer() async {
    bool available = await _speech.initialize(
        onStatus: (status) => print('Speech recognition status: $status'),
        onError: (errorNotification) => {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Speech recognition error: $errorNotification',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                      )),
                  duration: const Duration(
                      seconds: 2), // Adjust the duration as needed
                ),
              ),
              print('Speech recognition error: $errorNotification'),
            });
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available.',
              style: TextStyle(
                color: Colors.cyanAccent,
              )),
          duration: Duration(seconds: 2), // Adjust the duration as needed
        ),
      );
      if (kDebugMode) {
        print('Speech recognition not available');
      }
    }
  }

  void _startRecording() async {
    if (_speech.isAvailable) {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    } else {
      print('Speech recognition not available');
    }
  }

  void _stopRecording() {
    _speech.stop();
  }

  void _sendMessage(String message) async {
    setState(() {
      _isLoading = true;
    });

    String response = await GeminiAPI.getData(message);

    conversationHistory.add('User:\n$message');
    conversationHistory.add('$response\n\n\n');
    setState(() {
      _response.value = conversationHistory.join('\n\n');
      _isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset(
              'assets/ask.png',
              width: 35,
              height: 35,
              color: Colors.cyanAccent,
            ),
            const SizedBox(width: 10),
            const Text(
              'Ask',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.cyanAccent,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Reverse the order of items in the ListView
              itemCount: conversationHistory.length,
              itemBuilder: (context, index) {
                int reversedIndex = conversationHistory.length - 1 - index;
                return MessageCard(
                  message: conversationHistory[reversedIndex],
                  isUserMessage: reversedIndex % 2 == 0,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 100.0, // Adjust the max height as needed
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(
                    color: Colors.cyanAccent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50.0),
                    borderSide: const BorderSide(
                      color: Colors.cyanAccent,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50.0),
                    borderSide: const BorderSide(
                      color: Colors.cyanAccent,
                    ),
                  ),
                  prefixIcon: IconButton(
                    onPressed: (){},
                    tooltip: 'Capture Image',
                    icon: Icon(
                      Icons.camera,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: isRecording
                            ? const Icon(Icons.stop, color: Colors.cyanAccent)
                            : const Icon(Icons.mic, color: Colors.cyanAccent),
                        onPressed: () {
                          if (isRecording) {
                            _stopRecording();
                          } else {
                            _startRecording();
                          }
                          setState(() {
                            isRecording = !isRecording;
                          });
                        },
                      ),
                      IconButton(
                        icon: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.cyanAccent,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.cyanAccent,
                              ),
                        onPressed: () {
                          _sendMessage(_textController.text);
                          _stopRecording();
                          _textController.clear();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageCard extends StatefulWidget {
  final String message;
  final bool isUserMessage;

  const MessageCard(
      {super.key, required this.message, required this.isUserMessage});

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  final FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;

  Future<void> _stopSpeaking() async {
    await flutterTts.stop();
  }

  Future<void> _startSpeaking() async {
    await flutterTts.setLanguage("en-GB");
    await flutterTts.setVolume(1.0);
    // Set the voice for a female voice
    await flutterTts
        .setVoice({"name": "Google UK English Female", "locale": "en-GB"});
    await flutterTts.setPitch(0.8);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(widget.message);
    if (kDebugMode) {
      print(await flutterTts.getVoices);
    }
    // Wait for the text-to-speech to complete
    await flutterTts.awaitSpeakCompletion(true);
    setState(() {
      isSpeaking = !isSpeaking;
    });
  }

  Future<void> _copyToClipboard() async {
    BuildContext context =
        this.context; // Capture the context before the async operation

    await Clipboard.setData(ClipboardData(text: widget.message));
    // You can show a snackbar or any other UI feedback here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard!',
            style: TextStyle(
              color: Colors.cyanAccent,
            )),
        duration: Duration(seconds: 2), // Adjust the duration as needed
      ),
    );
    if (kDebugMode) {
      print('Text copied to clipboard: ${widget.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.black12,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
            child: Text(
              softWrap: true,
              widget.message,
              style: TextStyle(
                  color:
                      widget.isUserMessage ? Colors.white : Colors.cyanAccent),
            ),
          ),
          if (!widget.isUserMessage)
            Positioned(
              bottom: 5,
              right: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: isSpeaking
                          ? const Icon(Icons.stop_circle_outlined)
                          : const Icon(Icons.spatial_audio_off),
                      color: Colors.cyan,
                      onPressed: () {
                        if (isSpeaking) {
                          _stopSpeaking();
                        } else {
                          _startSpeaking();
                        }
                        setState(() {
                          isSpeaking = !isSpeaking;
                        });
                      }),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    color: Colors.cyan,
                    onPressed: _copyToClipboard,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const geminiAppKey = 'AIzaSyBC5_z9zV-mz6SlnDrZku2GCbz5WpFkvLo';

class GeminiAPI {
  // create a header
  static Future<Map<String, String>> getHeader() async {
    return {
      'Content-Type': 'application/json',
    };
  }

  // create request
  static Future<String> getData(message) async {
    try {
      final header = await getHeader();

      final Map<String, dynamic> requestbody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$message'}
            ]
          }
        ],
        'generationConfig': {
          'top_p': 1,
          'top_k': 1,
          'stopSequences': [],
          'temperature': 0.9, //it may vary from 0 to 1
          'maxOutputTokens': 2048, //it's the max token to generate a request
        },
        'safety_settings': [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
        ]
      };

      // copy the link from gemini and edit
      String url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$geminiAppKey ';

      // send request by using import http
      var response = await http.post(
        Uri.parse(url),
        headers: header,
        body: jsonEncode(requestbody),
      );
      if (kDebugMode) {
        print("GeminiAPI,//n ${response.body}");
      } //to fix any bugs

      if (response.statusCode == 200) {
        // 200 for success response
        var jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        // this will return the response from the gemini api
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return '';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      return '';
    }
  }
}
