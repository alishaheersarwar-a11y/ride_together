import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class CommonMethods {
  static Future<bool> checkConnectivity(BuildContext context) async {
    List<ConnectivityResult> connectionStatus =
    await Connectivity().checkConnectivity();

    if (connectionStatus.contains(ConnectivityResult.none)) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("your Internet is not available. Check your connection. Try Again."),
        ),
      );
      return false;
    }
    return true;
  }
  displaySnackBar(String messageText, BuildContext context) {
    var snackBar = SnackBar(content: Text(messageText));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}