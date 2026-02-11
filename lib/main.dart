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
  // --- STATE VARIABLES ---
  String userName = "User ${Random().nextInt(1000)}";
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};

  // Location & Markers
  LatLng? _currentLocation;
  List<Marker> _remoteMarkers = []; // Stores Red Siren markers from others
  final MapController _mapController = MapController();

  // Emergency Data
  bool _isSOSActive = false;
  Map<String, dynamic>? _myEmergencyData; // Stores my current SOS info

  // Chat & Logs
  List<Map<String, String>> _chatHistory = [];
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialSetup();
  }

  // --- 1. PERMISSIONS & LOCATION ---
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
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      // Only move map on first load
      if (_remoteMarkers.isEmpty) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // --- 2. SOS INPUT DIALOG ---
  void _showSOSDialog() {
    String selectedType = "Medical";
    String selectedSeverity = "High";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("DECLARE EMERGENCY")]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Describe your situation to broadcast to rescuers."),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ["Medical", "Fire", "Trapped", "Violence", "Other"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 10),
              const Text("Severity Level:", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["Low", "High", "Critical"].map((level) {
                  return ChoiceChip(
                    label: Text(level),
                    selected: selectedSeverity == level,
                    selectedColor: Colors.red[100],
                    onSelected: (b) => setDialogState(() => selectedSeverity = level),
                  );
                }).toList(),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _activateSOS(selectedType, selectedSeverity);
              },
              child: const Text("BROADCAST SOS", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- 3. MESH NETWORK LOGIC ---

  void _activateSOS(String type, String severity) async {
    // 1. Prepare Emergency Payload
    _myEmergencyData = {
      "header": "SOS_ALERT", // Unique header to identify this packet
      "sender": userName,
      "type": type,
      "severity": severity,
      "lat": _currentLocation?.latitude ?? 0.0,
      "lng": _currentLocation?.longitude ?? 0.0,
      "timestamp": DateTime.now().toString(),
    };

    // 2. Start Advertising
    try {
      setState(() => _isSOSActive = true);
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) => _addSystemMessage("SOS Status: $status"),
        onDisconnected: (id) => setState(() => endpointMap.remove(id)),
        serviceId: "com.example.safe",
      );
      _addSystemMessage("SOS ACTIVE: Broadcasting $type ($severity)");
    } catch (e) {
      _addSystemMessage("Error Advertising: $e");
      setState(() => _isSOSActive = false);
    }
  }

  void _startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          _addSystemMessage("Signal Found: $name");
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) => _addSystemMessage("Connection: $status"),
            onDisconnected: (id) => setState(() => endpointMap.remove(id)),
          );
        },
        onEndpointLost: (id) => _addSystemMessage("Lost signal: $id"),
        serviceId: "com.example.safe",
      );
      _addSystemMessage("Scanning for SOS signals...");
    } catch (e) {
      _addSystemMessage("Error Discovering: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    _addSystemMessage("Handshake with ${info.endpointName}...");

    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          String str = utf8.decode(payload.bytes!);

          // CHECK: Is this a JSON SOS packet or a Chat message?
          try {
            if (str.contains("SOS_ALERT")) {
              var data = jsonDecode(str);
              _handleSOSPacket(data);
            } else {
              // Normal chat message
              setState(() {
                _chatHistory.add({"sender": endpointMap[endId]?.endpointName ?? "Unknown", "message": str});
              });
            }
          } catch (e) {
            // Fallback for plain text
            setState(() {
              _chatHistory.add({"sender": endpointMap[endId]?.endpointName ?? "Unknown", "message": str});
            });
          }
        }
      },
    );

    // If I am the SOS sender, AUTO-SEND my emergency data immediately upon connection
    if (_isSOSActive && _myEmergencyData != null) {
      String jsonPayload = jsonEncode(_myEmergencyData);
      Nearby().sendBytesPayload(id, utf8.encode(jsonPayload));
      _addSystemMessage("Sent Emergency Coordinates to Rescuer");
    }

    setState(() {
      endpointMap[id] = info;
    });
  }

  // --- 4. HANDLE RECEIVED SOS DATA ---
  void _handleSOSPacket(Map<String, dynamic> data) {
    double lat = data['lat'];
    double lng = data['lng'];
    String type = data['type'];
    String severity = data['severity'];

    _addSystemMessage("!!! ALERT RECEIVED: $type ($severity) !!!");

    // Add Red Siren Marker
    setState(() {
      _remoteMarkers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 80,
          height: 80,
          child: Column(
            children: [
              // Blinking or static siren icon
              const Icon(Icons.warning_rounded, color: Colors.red, size: 40),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: Text("$type\n$severity",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            ],
          ),
        ),
      );

      // Auto-move map to the emergency
      _mapController.move(LatLng(lat, lng), 16.0);
    });
  }

  // --- 5. CHAT LOGIC ---
  void _sendMessage(String message) {
    if (message.isEmpty) return;
    endpointMap.forEach((key, value) {
      Nearby().sendBytesPayload(key, utf8.encode(message));
    });
    setState(() {
      _chatHistory.add({"sender": "Me", "message": message});
      _msgController.clear();
    });
  }

  void _addSystemMessage(String msg) {
    setState(() {
      _chatHistory.add({"sender": "System", "message": msg});
    });
  }

  // --- 6. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safe Protocol"),
        backgroundColor: _isSOSActive ? Colors.red[900] : Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // MAP LAYER
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
              // LAYER 1: Current User (BLUE)
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Icon(Icons.my_location, color: Colors.blue[700], size: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            color: Colors.white.withOpacity(0.7),
                            child: const Text("Me", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ],
                ),

              // LAYER 2: Remote SOS Signals (RED SIREN)
              MarkerLayer(markers: _remoteMarkers),
            ],
          ),

          // CONTROL PANEL
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // SOS BUTTON
                    ElevatedButton.icon(
                      onPressed: _isSOSActive ? null : _showSOSDialog, // Open Input Dialog
                      icon: _isSOSActive
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_isSOSActive ? "Broadcasting..." : "SOS"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    // SCAN BUTTON
                    ElevatedButton.icon(
                      onPressed: _startDiscovery,
                      icon: const Icon(Icons.search),
                      label: const Text("Scan for Help"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // CHAT TOGGLE (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: _openChatBox,
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.chat, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  // --- REUSED CHAT UI (Same as before) ---
  void _openChatBox() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[800], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Mesh Chat (${endpointMap.length} Connected)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final chat = _chatHistory[index];
                  bool isMe = chat['sender'] == "Me";
                  bool isSys = chat['sender'] == "System";
                  if (isSys) return Center(child: Padding(padding: const EdgeInsets.all(4), child: Text(chat['message']!, style: const TextStyle(fontSize: 10, color: Colors.grey))));
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isMe ? Colors.blue[100] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if(!isMe) Text(chat['sender']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                          Text(chat['message']!)
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 8),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Type...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
                  const SizedBox(width: 8),
                  CircleAvatar(backgroundColor: Colors.blue[800], child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _sendMessage(_msgController.text))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}