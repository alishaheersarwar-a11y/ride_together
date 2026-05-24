import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isDriver;
  final DateTime time;
  ChatMessage({required this.text, required this.isDriver, required this.time});
}

class RideProvider extends ChangeNotifier {
  bool _isRideAccepted = false;
  final List<ChatMessage> _messages = [];

  bool get isRideAccepted => _isRideAccepted;
  List<ChatMessage> get messages => _messages;

  void acceptRide() {
    _isRideAccepted = true;
    notifyListeners();
  }

  void sendMessage(String text, bool isDriver) {
    _messages.insert(0, ChatMessage(text: text, isDriver: isDriver, time: DateTime.now()));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}