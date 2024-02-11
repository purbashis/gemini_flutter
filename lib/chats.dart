import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gemini_flutter/api_key.dart';
import 'package:gemini_flutter/chat_model.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatModel> chatList = [];
  final TextEditingController controller = TextEditingController();
  File? image;
  bool isSending = false;
  bool isGenerating = false; // Track if data is being generated

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onSendMessage() async {
    if (controller.text.trim().isEmpty && image == null) {
      return; // Prevent sending empty message
    }

    setState(() {
      isSending = true;
    });

    ChatModel model;

    if (image == null) {
      model = ChatModel(isMe: true, message: controller.text);
    } else {
      final imageBytes = await image!.readAsBytes();
      String base64EncodedImage = base64Encode(imageBytes);

      model = ChatModel(
        isMe: true,
        message: controller.text,
        base64EncodedImage: base64EncodedImage,
      );
    }

    chatList.insert(0, model);
    controller.clear();

    setState(() {
      isGenerating = true; // Set generating status
    });

    final geminiModel = await sendRequestToGemini(model);

    chatList.insert(0, geminiModel);

    setState(() {
      isSending = false;
      isGenerating = false; // Reset generating status
    });

    // Scroll to the latest message
    _scrollToLatestMessage();
  }

  void _scrollToLatestMessage() {
    Future.delayed(Duration(milliseconds: 100), () {
      _controller.animateTo(
        _controller.position.minScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void selectImage() async {
    final picker = await ImagePicker.platform
        .getImageFromSource(source: ImageSource.gallery);

    if (picker != null) {
      setState(() {
        image = File(picker.path);
      });
    }
  }

  Future<ChatModel> sendRequestToGemini(ChatModel model) async {
    String url = "";
    Map<String, dynamic> body = {};

    if (model.base64EncodedImage == null) {
      url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${GeminiApiKey.api_key}";

      body = {
        "contents": [
          {
            "parts": [
              {"text": model.message},
            ],
          },
        ],
      };
    } else {
      url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=${GeminiApiKey.api_key}";

      body = {
        "contents": [
          {
            "parts": [
              {"text": model.message},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": model.base64EncodedImage,
                }
              }
            ],
          },
        ],
      };
    }

    Uri uri = Uri.parse(url);

    final result = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );

    final decodedJson = json.decode(result.body);

    String message =
        decodedJson['candidates'][0]['content']['parts'][0]['text'];

    ChatModel geminiModel = ChatModel(isMe: false, message: message);

    return geminiModel;
  }

  ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "D4ntZ-Gemini",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.blue[100],
        elevation: 0,
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 10,
              child: Stack(
                children: [
                  Container(
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: _controller,
                      reverse: true,
                      itemCount: chatList.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: Align(
                            alignment: chatList[index].isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: chatList[index].isMe
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.all(12),
                              child: chatList[index].base64EncodedImage != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Image.memory(
                                          base64Decode(chatList[index]
                                              .base64EncodedImage!),
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          chatList[index].message,
                                          style: TextStyle(
                                            color: chatList[index].isMe
                                                ? Colors.blue
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      chatList[index].message,
                                      style: TextStyle(
                                        color: chatList[index].isMe
                                            ? Colors.blue
                                            : Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Visibility(
                    visible: isGenerating,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: isGenerating ? 1.0 : 0.0,
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: Text(
                          "Generating results...",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: isSending ? null : () => onSendMessage(),
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.send, color: Colors.white),
                      elevation: 0,
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: selectImage,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.camera_alt, color: Colors.white),
                      elevation: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
