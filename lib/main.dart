import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SafeProtocolHome(),
  ));
}

class SafeProtocolHome extends StatefulWidget {
  const SafeProtocolHome({super.key});

  @override
  State<SafeProtocolHome> createState() => _SafeProtocolHomeState();
}

class _SafeProtocolHomeState extends State<SafeProtocolHome> {
  final String userName = "Unit ${Random().nextInt(99)}";
  final Strategy strategy = Strategy.P2P_STAR;

  Map<String, ConnectionInfo> endpointMap = {};
  LatLng? _currentLocation;
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];

  // FIXED: Use ValueNotifier so chat updates instantly without keyboard
  final ValueNotifier<List<Map<String, String>>> _chatNotifier = ValueNotifier([]);
  final TextEditingController _msgController = TextEditingController();

  final MapController _mapController = MapController();

  // App State
  bool _isSOSActive = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initialSetup();
  }

  Future<void> _initialSetup() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMyMarker();
      });
      if (_markers.length <= 1) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
    }
  }

  void _updateMyMarker() {
    if (_currentLocation == null) return;
    _markers.removeWhere((m) => m.key == const Key("me"));
    _markers.add(
      Marker(
        key: const Key("me"),
        point: _currentLocation!,
        width: 80,
        height: 80,
        child: _buildCustomMarker(
          icon: _isSOSActive ? Icons.warning_amber_rounded : Icons.navigation,
          color: _isSOSActive ? Colors.red : Colors.blue,
          label: "YOU",
        ),
      ),
    );
  }

  Widget _buildCustomMarker({required IconData icon, required Color color, String? label}) {
    return Column(
      children: [
        if (label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [const BoxShadow(blurRadius: 4, color: Colors.black26)],
            ),
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [const BoxShadow(blurRadius: 6, color: Colors.black38)],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  // --- EMERGENCY INPUT DIALOG ---
  void _showEmergencyInput() {
    String selectedType = "Medical";
    String selectedSeverity = "High";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [Icon(Icons.report_problem, color: Colors.red), SizedBox(width: 10), Text("Emergency Details")]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Emergency Type:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ["Medical", "Fire", "Trapped", "Violence", "Other"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 15),
              const Text("Severity:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ["Low", "High", "Critical"].map((level) {
                  return ChoiceChip(
                    label: Text(level),
                    selected: selectedSeverity == level,
                    selectedColor: Colors.red[100],
                    labelStyle: TextStyle(color: selectedSeverity == level ? Colors.red[900] : Colors.black),
                    onSelected: (b) => setDialogState(() => selectedSeverity = level),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _startAdvertising(type: selectedType, severity: selectedSeverity);
              },
              child: const Text("BROADCAST SOS"),
            )
          ],
        ),
      ),
    );
  }

  // --- MESH LOGIC ---

  void _handleEmergencyButton() {
    if (_isSOSActive) {
      _stopAll(); // Cancel SOS
    } else {
      _showEmergencyInput(); // Ask for details first
    }
  }

  void _handleViewAlerts() {
    if (_isScanning) {
      _stopAll();
    } else {
      _startDiscovery();
    }
  }

  void _stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    setState(() {
      _isSOSActive = false;
      _isScanning = false;
      _updateMyMarker();
    });
  }

  void _startAdvertising({required String type, required String severity}) async {
    try {
      await Nearby().stopDiscovery();
      setState(() {
        _isSOSActive = true;
        _updateMyMarker();
        if (_currentLocation != null) {
          _circles.add(CircleMarker(point: _currentLocation!, color: Colors.red.withOpacity(0.3), borderStrokeWidth: 2, borderColor: Colors.red, radius: 100, useRadiusInMeter: true));
        }
      });

      // Store emergency data to send on connection
      var emergencyPayload = jsonEncode({
        "type": "SOS_ALERT",
        "lat": _currentLocation?.latitude ?? 0.0,
        "lng": _currentLocation?.longitude ?? 0.0,
        "e_type": type,
        "severity": severity
      });

      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (id, info) => _onConnectionInit(id, info, initialPayload: emergencyPayload),
        onConnectionResult: (id, status) => debugPrint("Status: $status"),
        onDisconnected: (id) => setState(() => endpointMap.remove(id)),
        serviceId: "com.example.safe",
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _startDiscovery() async {
    try {
      await Nearby().stopAdvertising();
      setState(() {
        _isScanning = true;
      });
      await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) => _onConnectionInit(id, info),
            onConnectionResult: (id, status) => debugPrint("Status: $status"),
            onDisconnected: (id) => setState(() => endpointMap.remove(id)),
          );
        },
        onEndpointLost: (id) => debugPrint("Lost: $id"),
        serviceId: "com.example.safe",
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info, {String? initialPayload}) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          String str = utf8.decode(payload.bytes!);
          if (str.contains("SOS_ALERT")) {
            var data = jsonDecode(str);
            _addAlertMarker(data['lat'], data['lng'], data['e_type'], data['severity']);
          } else {
            // Chat Message: Update the Notifier, not just SetState
            final currentChats = List<Map<String, String>>.from(_chatNotifier.value);
            currentChats.add({"sender": endpointMap[endId]?.endpointName ?? "Unknown", "message": str});
            _chatNotifier.value = currentChats;
          }
        }
      },
    );
    setState(() => endpointMap[id] = info);

    // Auto-send emergency payload if I am the Host
    if (initialPayload != null) {
      Nearby().sendBytesPayload(id, utf8.encode(initialPayload));
    }
  }

  void _addAlertMarker(double lat, double lng, String type, String severity) {
    setState(() {
      _markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 80, height: 80,
            child: _buildCustomMarker(icon: Icons.notification_important, color: Colors.red, label: "$type\n$severity"),
          )
      );
      _circles.add(CircleMarker(point: LatLng(lat, lng), color: Colors.orange.withOpacity(0.3), borderStrokeWidth: 2, borderColor: Colors.orange, radius: 100, useRadiusInMeter: true));
    });
  }

  // --- CHAT LOGIC ---
  void _sendMessage(String message) {
    if (message.isEmpty) return;
    endpointMap.forEach((key, value) {
      Nearby().sendBytesPayload(key, utf8.encode(message));
    });

    // Update Notifier
    final currentChats = List<Map<String, String>>.from(_chatNotifier.value);
    currentChats.add({"sender": "Me", "message": message});
    _chatNotifier.value = currentChats;

    _msgController.clear();
  }

  void _openChatBox() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [const Icon(Icons.chat, color: Colors.white), const SizedBox(width: 10), Text("Mesh Chat (${endpointMap.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),

            // FIXED: Using ValueListenableBuilder to update UI instantly
            Expanded(
              child: ValueListenableBuilder<List<Map<String, String>>>(
                valueListenable: _chatNotifier,
                builder: (context, chatHistory, child) {
                  return ListView.builder(
                    itemCount: chatHistory.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Align(
                        alignment: chatHistory[i]['sender'] == "Me" ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: chatHistory[i]['sender'] == "Me" ? Colors.blue[100] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: Text(chatHistory[i]['message']!),
                        ),
                      ),
                      subtitle: Text(chatHistory[i]['sender']!, textAlign: chatHistory[i]['sender'] == "Me" ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 10)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 10, left: 10, right: 10),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: "Message..."))),
                  IconButton(icon: const Icon(Icons.send), onPressed: () => _sendMessage(_msgController.text))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. MAP LAYER
          FlutterMap(
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
              CircleLayer(circles: _circles),
              MarkerLayer(markers: _markers),
            ],
          ),

          // 2. GRADIENT OVERLAY
          Positioned(
            bottom: 0, left: 0, right: 0, height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // 3. CHAT BUTTON
          Positioned(
            top: 50, right: 20,
            child: FloatingActionButton(
              onPressed: _openChatBox,
              backgroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            ),
          ),

          // 4. BOTTOM CONTROLS
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _handleEmergencyButton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD30000),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSOSActive
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.warning_amber_rounded, size: 28),
                    label: Text(_isSOSActive ? "CANCEL SOS" : "REPORT EMERGENCY", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _handleViewAlerts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.sensors),
                          label: const Text("VIEW ALERTS", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    // SETTINGS BUTTON REMOVED as requested
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}