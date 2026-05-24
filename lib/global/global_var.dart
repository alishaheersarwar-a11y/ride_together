import 'package:google_maps_flutter/google_maps_flutter.dart';

// User Info
String userName = "";
String userEmail = "";
String userPhone = "";
String userID = "";

// Google Map API Key (Maps SDK — used by google_maps_flutter)
String googleMapKey = "AIzaSyAmrSOZtBCqLNkVtJP7lK78FJ5YIYyEaSA";

// Google Directions API Key — used by RouteService for the driver↔passenger
// polyline + ETA.
String directionsApiKey = "AIzaSyAmrSOZtBCqLNkVtJP7lK78FJ5YIYyEaSA";

// Single Camera Position — Peshawar
const CameraPosition googlePlexInitialPosition = CameraPosition(
  target: LatLng(33.9989, 71.5341),
  zoom: 14,
);


