import 'dart:math';
import 'dart:convert'; // <--- ADDED THIS IMPORT
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  runApp(const MaterialApp(home: SafeProtocolHome()));
}

class SafeProtocolHome extends StatefulWidget {
  const SafeProtocolHome({super.key});

  @override
  State<SafeProtocolHome> createState() => _SafeProtocolHomeState();
}

class _SafeProtocolHomeState extends State<SafeProtocolHome> {
  // --- STATE VARIABLES ---
  String userName = Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};
  LatLng? _currentLocation;
  List<String> _logs = [];

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initialSetup();
  }

  // --- 1. PERMISSIONS & LOCATION ---
  Future<void> _initialSetup() async {
    _log("Checking permissions...");

    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    if (statuses[Permission.location]!.isGranted) {
      _getCurrentLocation();
    } else {
      _log("Location permission denied.");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation!, 15.0);
      _log("Location found: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      _log("Error getting location: $e");
    }
  }

  // --- 2. MESH NETWORK LOGIC ---

  void _startAdvertising() async {
    try {
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) => _log("Connection result: $status"),
        onDisconnected: (id) {
          setState(() {
            endpointMap.remove(id);
          });
          _log("Disconnected: $id");
        },
        serviceId: "com.example.safe",
      );
      _log("Advertising Started: $a");
    } catch (e) {
      _log("Advertising Error: $e");
    }
  }

  void _startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          _log("Found User: $name ($id)");
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) => _log("Connection: $status"),
            onDisconnected: (id) {
              setState(() {
                endpointMap.remove(id);
              });
            },
          );
        },
        onEndpointLost: (id) => _log("Lost Endpoint: $id"),
        serviceId: "com.example.safe",
      );
      _log("Discovery Started: $a");
    } catch (e) {
      _log("Discovery Error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    _log("Connection Initiated with ${info.endpointName}");
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) {
        // FIXED: Using utf8 directly from dart:convert
        if (payload.type == PayloadType.BYTES) {
          String message = utf8.decode(payload.bytes!);
          _log("Message from $endId: $message");
        }
      },
    );
    setState(() {
      endpointMap[id] = info;
    });
  }

  // --- HELPER: Send Data ---
  void _sendMessage(String message) {
    endpointMap.forEach((key, value) {
      // FIXED: Removed 'dart.convert.' prefix
      Nearby().sendBytesPayload(key, utf8.encode(message));
    });
  }

  void _log(String msg) {
    print(msg);
    setState(() {
      _logs.insert(0, msg);
    });
  }

  // --- 3. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Safe Protocol (Mesh)")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? const LatLng(28.6139, 77.2090),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.safe',
                ),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _startAdvertising,
                        icon: const Icon(Icons.sos),
                        label: const Text("SOS (Advertise)"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                      ),
                      ElevatedButton.icon(
                        onPressed: _startDiscovery,
                        icon: const Icon(Icons.search),
                        label: const Text("Rescue (Scan)"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100]),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text("Connection Logs:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) => Text(
                        _logs[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
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