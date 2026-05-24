import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:ride_together/services/background_location_handler.dart';
import 'package:ride_together/services/location_share_service.dart';
import 'package:ride_together/splash_screen.dart';
import 'package:ride_together/app_charges/app_wallet.dart';
import 'package:ride_together/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
        'FLUTTER_ERROR: ${details.exceptionAsString()}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PLATFORM_ERROR: $error\n$stack');
    return true;
  };

  // Force the latest Google Maps renderer on Android.
  final GoogleMapsFlutterPlatform mapsImpl =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    try {
      await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
    } catch (e) {
      debugPrint('Maps renderer init failed: $e');
    }
  }

  await Firebase.initializeApp();

  // Point firebase_database at the correct RTDB instance.
  FirebaseDatabase.instance.databaseURL =
  'https://carpooling-app-2f56f-default-rtdb.firebaseio.com';

  await initializeLocationShareBackgroundService();

  // Stop location sharing when user logs out.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null && LocationShareService.isSharing) {
      LocationShareService.stop();
    }
  });

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // SplashScreen is always the entry point — it decides where to go next.
      home: const SplashScreen(),

      // ── Named routes so Navigator.pushNamedAndRemoveUntil works ───────────
      routes: {
        '/login':  (_) => const LoginScreen(),
        '/wallet': (_) => const AppWalletScreen(),
      },

      // ── Unknown route fallback ─────────────────────────────────────────────
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }
}





// import 'dart:ui';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
// import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
// import 'package:ride_together/services/background_location_handler.dart';
// import 'package:ride_together/services/location_share_service.dart';
// import 'package:ride_together/splash_screen.dart';
//
// Future<void> main() async
// {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   FlutterError.onError = (details) {
//     FlutterError.presentError(details);
//     debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}\n${details.stack}');
//   };
//   PlatformDispatcher.instance.onError = (error, stack) {
//     debugPrint('PLATFORM_ERROR: $error\n$stack');
//     return true;
//   };
//
//   // Force the latest Google Maps renderer on Android. The legacy renderer
//   // crashes the maps screens on Android 5–8 devices.
//   final GoogleMapsFlutterPlatform mapsImpl = GoogleMapsFlutterPlatform.instance;
//   if (mapsImpl is GoogleMapsFlutterAndroid) {
//     try {
//       await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
//     } catch (e) {
//       debugPrint('Maps renderer init failed: $e');
//     }
//   }
//
//   await Firebase.initializeApp();
//
//   // Point firebase_database at the RTDB instance. The android google-services.json
//   // shipped with this project doesn't carry a firebase_url entry, so without
//   // this line every RTDB read/write throws "Database URL not specified" — which
//   // was the actual cause of the crash on entering the driver/passenger home.
//   FirebaseDatabase.instance.databaseURL =
//       'https://carpooling-app-2f56f-default-rtdb.firebaseio.com';
//
//   await initializeLocationShareBackgroundService();
//
//   // Stop location sharing if the user logs out mid-ride. Without this, the
//   // foreground service keeps streaming GPS to a node the new auth context
//   // can't write to, draining battery and producing silent permission errors.
//   FirebaseAuth.instance.authStateChanges().listen((user) {
//     if (user == null && LocationShareService.isSharing) {
//       LocationShareService.stop();
//     }
//   });
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget
// {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context)
//   {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       // title: 'Animated Onboarding',
//       //  theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
//       home: SplashScreen(),
//     );
//   }
// }
