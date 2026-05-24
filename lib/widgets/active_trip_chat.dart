import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ActiveTripChat extends StatelessWidget {
  const ActiveTripChat({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("In-App Chat", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Expanded(
            child: Center(child: Text("No messages yet. Coordinate the pickup!", style: TextStyle(color: Colors.white38))),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      fillColor: Colors.white10,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const CircleAvatar(backgroundColor: Colors.cyanAccent, child: Icon(LucideIcons.send, size: 18, color: Colors.black)),
              ],
            ),
          )
        ],
      ),
    );
  }
}