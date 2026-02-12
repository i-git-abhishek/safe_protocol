import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
      backgroundColor: const Color(0xFF0F172A),
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

// --- NAVIGATION MENU DRAWER ---
class NavDrawer extends StatelessWidget {
  final String currentScreen;
  final Function(String) onNavigate;
  final VoidCallback onLogout;
  final String userName; // ADDED: Variable to hold user name

  const NavDrawer({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
    required this.onLogout,
    required this.userName, // ADDED
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SAFE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text("Rescuer Panel", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Logged in as", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      // CHANGED: Displays dynamic user name
                      Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text("Active", style: TextStyle(color: Colors.green, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildNavItem("dashboard", "Dashboard", Icons.home),
                _buildNavItem("reports", "Report Log", Icons.radio),
                _buildNavItem("chat", "Chat System", Icons.chat),
                _buildNavItem("analytics", "Analytics", Icons.bar_chart),
                _buildNavItem("activity", "Activity Log", Icons.description),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                  onTap: onLogout,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  hoverColor: Colors.red.withOpacity(0.1),
                ),
                const SizedBox(height: 10),
                const Text("SAFE System v2.0.1", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(String id, String label, IconData icon) {
    final bool isActive = currentScreen == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isActive ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEA580C)]) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.grey),
        title: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        onTap: () => onNavigate(id),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
  String _currentScreen = "dashboard";

  String myName = "Loading..."; // Default
  String myAge = "--";
  String myGender = "--";
  String myBlood = "--";

  final ValueNotifier<List<Map<String, String>>> _chatNotifier = ValueNotifier([]);
  final TextEditingController _msgController = TextEditingController();
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  void _handleNavigation(String screen) {
    setState(() => _currentScreen = screen);
    Navigator.pop(context);
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  // --- SOS & MESH ---
  void _showEmergencyInput() {
    String selectedType = "Medical";
    String selectedSeverity = "High";
    final TextEditingController otherCtrl = TextEditingController(); // Controller for "Other" description

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Emergency Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // DROPDOWN
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ["Medical", "Fire", "Trapped", "Violence", "Other"] // ADDED "Other"
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),

              // CONDITIONAL TEXT FIELD FOR "OTHER"
              if (selectedType == "Other")
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: otherCtrl,
                    decoration: const InputDecoration(
                      labelText: "Describe Emergency",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),

              const SizedBox(height: 15),

              // SEVERITY CHIPS
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

                // Determine final type string
                String finalType = selectedType;
                if (selectedType == "Other") {
                  // Use the typed description, or default to "Other (Unspecified)"
                  finalType = otherCtrl.text.isNotEmpty ? "Other: ${otherCtrl.text}" : "Other (Unspecified)";
                }

                _startAdvertising(type: finalType, severity: selectedSeverity);
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
      key: _scaffoldKey,

      // DRAWER IMPLEMENTATION (Dynamic User Name)
      drawer: NavDrawer(
        currentScreen: _currentScreen,
        onNavigate: _handleNavigation,
        onLogout: _handleLogout,
        userName: myName, // PASSING THE USER NAME
      ),

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

          Positioned(
            top: 50, left: 20,
            child: FloatingActionButton(
              heroTag: "menu_btn",
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              backgroundColor: const Color(0xFF1E293B), // Slate 800
              child: const Icon(Icons.menu, color: Colors.white),
            ),
          ),

          Positioned(
            top: 50, right: 20,
            child: FloatingActionButton(
              heroTag: "chat_btn",
              onPressed: _openChatBox,
              backgroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            ),
          ),

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