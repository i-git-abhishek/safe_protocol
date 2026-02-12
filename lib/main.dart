import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // ADDED for calls

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AppRoot(),
  ));
}

// --- ROOT WIDGET ---
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.containsKey('userName');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _isLoggedIn! ? const SafeProtocolHome() : const LoginPage();
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = "Male";
  String _bloodGroup = "O+";

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nameCtrl.text);
      await prefs.setString('userAge', _ageCtrl.text);
      await prefs.setString('userGender', _gender);
      await prefs.setString('userBlood', _bloodGroup);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SafeProtocolHome()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(title: const Text("Setup Profile"), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              _buildTextField(_nameCtrl, "Full Name"),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(_ageCtrl, "Age", isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Gender"),
                      items: ["Male", "Female", "Other"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _bloodGroup,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Blood Group"),
                items: ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _bloodGroup = v!),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveUser,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                  child: const Text("SAVE & CONTINUE"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextField(TextEditingController ctrl, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}

// --- SETTINGS PAGE (NEW) ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _offlineMode = true;
  bool _notifications = true;
  String _language = "English";

  final List<Map<String, String>> _contacts = [
    {"name": "Emergency Hotline", "number": "112"},
    {"name": "Disaster Management", "number": "108"},
    {"name": "Medical Emergency", "number": "102"},
  ];

  void _makeCall(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: const Text("SETTINGS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Offline Mode Card
          _buildCard(
            child: SwitchListTile(
              title: const Text("Offline Mode", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text("Peer-to-peer communication", style: TextStyle(color: Colors.grey, fontSize: 12)),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange[600], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.wifi_tethering, color: Colors.white),
              ),
              value: _offlineMode,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _offlineMode = val),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Notifications Card
          _buildCard(
            child: SwitchListTile(
              title: const Text("Emergency Alerts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text("Receive notifications", style: TextStyle(color: Colors.grey, fontSize: 12)),
              secondary: const Icon(Icons.notifications, color: Colors.orange),
              value: _notifications,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _notifications = val),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Emergency Contacts
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.phone, color: Colors.orange),
                      SizedBox(width: 10),
                      Text("Emergency Contacts", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ..._contacts.map((c) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[800]!)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Text("Tap to call", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _makeCall(c['number']!),
                        child: Text(c['number']!),
                      )
                    ],
                  ),
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Language
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.language, color: Colors.orange),
              title: const Text("Language", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: DropdownButton<String>(
                value: _language,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                underline: Container(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: ["English", "Hindi", "Spanish", "French"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _language = v!),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 5. About
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.orange),
                      SizedBox(width: 10),
                      Text("About SAFE", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "SAFE (Secure Alerts For Emergencies) is an offline disaster management system designed for use during natural disasters.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text("Peer-to-Peer (No Internet)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: child,
    );
  }
}

// --- MAIN HOME PAGE ---
class SafeProtocolHome extends StatefulWidget {
  const SafeProtocolHome({super.key});

  @override
  State<SafeProtocolHome> createState() => _SafeProtocolHomeState();
}

class _SafeProtocolHomeState extends State<SafeProtocolHome> {
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};
  LatLng? _currentLocation;
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];

  String myName = "Unknown";
  String myAge = "--";
  String myGender = "--";
  String myBlood = "--";

  final ValueNotifier<List<Map<String, String>>> _chatNotifier = ValueNotifier([]);
  final TextEditingController _msgController = TextEditingController();
  final MapController _mapController = MapController();

  bool _isSOSActive = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initialSetup();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myName = prefs.getString('userName') ?? "Unit ${Random().nextInt(99)}";
      myAge = prefs.getString('userAge') ?? "--";
      myGender = prefs.getString('userGender') ?? "--";
      myBlood = prefs.getString('userBlood') ?? "--";
    });
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

  Widget _buildCustomMarker({required IconData icon, required Color color, String? label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [const BoxShadow(blurRadius: 4, color: Colors.black26)]),
              child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [const BoxShadow(blurRadius: 6, color: Colors.black38)]),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  void _showEmergencyInput() {
    String selectedType = "Medical";
    String selectedSeverity = "High";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Emergency Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ["Medical", "Fire", "Trapped", "Violence"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ["Low", "High", "Critical"].map((level) {
                  return ChoiceChip(
                    label: Text(level),
                    selected: selectedSeverity == level,
                    selectedColor: Colors.red[100],
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

      var emergencyPayload = jsonEncode({
        "type": "SOS_ALERT",
        "lat": _currentLocation?.latitude ?? 0.0,
        "lng": _currentLocation?.longitude ?? 0.0,
        "e_type": type,
        "severity": severity,
        "p_name": myName,
        "p_age": myAge,
        "p_gender": myGender,
        "p_blood": myBlood
      });

      await Nearby().startAdvertising(
        myName,
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

  void _handleViewAlerts() {
    if (_isScanning) { _stopAll(); } else { _startDiscovery(); }
  }

  void _stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    setState(() { _isSOSActive = false; _isScanning = false; _updateMyMarker(); });
  }

  void _startDiscovery() async {
    try {
      await Nearby().stopAdvertising();
      setState(() { _isScanning = true; });
      await Nearby().startDiscovery(
        myName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            myName,
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
            _addAlertMarker(data);
          } else {
            final currentChats = List<Map<String, String>>.from(_chatNotifier.value);
            currentChats.add({"sender": endpointMap[endId]?.endpointName ?? "Unknown", "message": str});
            _chatNotifier.value = currentChats;
          }
        }
      },
    );
    setState(() => endpointMap[id] = info);
    if (initialPayload != null) {
      Nearby().sendBytesPayload(id, utf8.encode(initialPayload));
    }
  }

  void _addAlertMarker(Map<String, dynamic> data) {
    setState(() {
      _markers.add(
          Marker(
            point: LatLng(data['lat'], data['lng']),
            width: 80, height: 80,
            child: _buildCustomMarker(
                icon: Icons.notification_important,
                color: Colors.red,
                label: "${data['e_type']}\n${data['severity']}",
                onTap: () => _showVictimProfile(data)
            ),
          )
      );
      _circles.add(CircleMarker(point: LatLng(data['lat'], data['lng']), color: Colors.orange.withOpacity(0.3), borderStrokeWidth: 2, borderColor: Colors.orange, radius: 100, useRadiusInMeter: true));
    });
  }

  void _showVictimProfile(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Victim Profile", style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${data['p_name']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text("Age: ${data['p_age']}"),
            Text("Gender: ${data['p_gender']}"),
            Text("Blood Group: ${data['p_blood']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            Text("Emergency: ${data['e_type']}"),
            Text("Severity: ${data['severity']}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _openChatBox(); },
            icon: const Icon(Icons.chat),
            label: const Text("Chat"),
          )
        ],
      ),
    );
  }

  void _sendMessage(String message) {
    if (message.isEmpty) return;
    endpointMap.forEach((key, value) {
      Nearby().sendBytesPayload(key, utf8.encode(message));
    });
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(28.6139, 77.2090),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.safe'),
              CircleLayer(circles: _circles),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(bottom: 0, left: 0, right: 0, height: 300, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent], stops: const [0.0, 1.0])))),
          Positioned(top: 50, right: 20, child: FloatingActionButton(onPressed: _openChatBox, backgroundColor: Colors.white, child: const Icon(Icons.chat_bubble_outline, color: Colors.blue))),

          // BOTTOM CONTROLS
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _isSOSActive ? _stopAll() : _showEmergencyInput(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD30000), foregroundColor: Colors.white, elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: _isSOSActive ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.warning_amber_rounded, size: 28),
                    label: Text(_isSOSActive ? "CANCEL SOS" : "REPORT EMERGENCY", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                icon: const Icon(Icons.sensors),
                                label: const Text("VIEW ALERTS", style: TextStyle(fontWeight: FontWeight.bold))
                            )
                        )
                    ),
                    const SizedBox(width: 12),
                    // SETTINGS BUTTON RESTORED
                    Expanded(
                        child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF263238),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text("SETTINGS", style: TextStyle(fontWeight: FontWeight.bold))
                            )
                        )
                    ),
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