// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io'; 

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:start_app/login_screen.dart';
import 'package:start_app/onboarding_screen.dart'; 
import 'package:start_app/database_halper.dart';
import 'package:start_app/custom_app_loader.dart';
import 'package:start_app/connectivity_service.dart';
import 'package:start_app/loader_utils.dart'; 



// This is Theme set
const Color kPrimaryColor = Color(0xFF75E5E2); // Light Cyan
const Color kSecondaryColor = Color(0xFF41938F); // Teal Green
const Color kTertiaryColor = Color(0xFF0D1D20); // Very Dark Teal
const Color kInputBgColor = Color(0xFF282828); // Dark Grey/Black
const MaterialColor kPrimarySwatch = MaterialColor(0xFF41938F, <int, Color>{
  50: Color(0xFFE2F0EF),
  100: Color(0xFFB5D8D7),
  200: Color(0xFF86BCBB),
  300: Color(0xFF56A19F),
  400: Color(0xFF328B88),
  500: Color(0xFF41938F),
  600: Color(0xFF287977),
  700: Color(0xFF1D5E5C),
  800: Color(0xFF124342),
  900: Color(0xFF0D1D20),
});




final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();


void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const MyApp());}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityService.instance.initialize(context);
    });
  }

  @override
  void dispose() {
    ConnectivityService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEVAJ TEC',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      home: const StartupScreen(),
    );
  }


  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: kPrimarySwatch,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: kTertiaryColor, // Dark background
      fontFamily: 'Raleway',
      appBarTheme: const AppBarTheme(
        backgroundColor: kTertiaryColor,elevation: 0,
        titleTextStyle: TextStyle(
          color: kPrimaryColor,fontSize: 20,fontWeight: FontWeight.w600,fontFamily: 'Raleway',),
        iconTheme: IconThemeData(color: kPrimaryColor),
      ),




      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor, // Primary color for the button
          foregroundColor: kTertiaryColor, // Tertiary color for the text
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(  borderRadius: BorderRadius.circular(12),),
          textStyle: const TextStyle(
            fontSize: 18,
            fontFamily: 'Raleway',
            fontWeight: FontWeight.bold,
          ),
          elevation: 8,
          shadowColor: kPrimaryColor.withOpacity(0.4),
        ),
      ),
      // Input Field Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSecondaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSecondaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
        filled: true,
        fillColor: kInputBgColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: kPrimaryColor, // Primary color for labels
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: kSecondaryColor, // Secondary color for hints
          fontStyle: FontStyle.italic,
        ),
        prefixIconColor: kPrimaryColor,
        suffixIconColor: kPrimaryColor,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STARTUP SCREEN (Connection check)
// -----------------------------------------------------------------------------
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkConnectionAndNavigate();
  }

  // Function to check saved connection details and navigate accordingly
  Future<void> _checkConnectionAndNavigate() async {
    final savedDetails = await DatabaseHelper.instance.getConnectionDetails();

    // Check if widget is still mounted before navigation
    if (!mounted) return;

    if (savedDetails != null &&
        savedDetails['ip'] != null &&
        savedDetails['ip'].isNotEmpty) {
      // Details found, navigate to LoginScreen
      final tiltId = int.tryParse(savedDetails['tiltId'] ?? "0") ?? 0;
      final tiltName = savedDetails['tiltName'] ?? "";

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(tiltId: tiltId, tiltName: tiltName),
        ),
      );
    } else {
      // No details, navigate to OnboardingScreen (ConnectionForm)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppLoader(message: "Initializing..."),
    );
  }
}

// -----------------------------------------------------------------------------
// ONBOARDING SCREEN
// -----------------------------------------------------------------------------
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold body only shows ConnectionForm
    return const Scaffold(body: ConnectionForm());
  }
}

// -----------------------------------------------------------------------------
// CONNECTION FORM
// -----------------------------------------------------------------------------
class ConnectionForm extends StatefulWidget {
  const ConnectionForm({super.key});

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm>
    with TickerProviderStateMixin {
  // Form Keys & Controllers
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _dbNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '1433');

  // State Variables
  bool _isConnecting = false;
  bool _obscurePassword = true;
  int? _selectedTiltId;
  String? _selectedTiltName;
  Future<List<Map<String, dynamic>>>? _tiltsFuture; // Future for Tilts list

  // Animation Controllers & Animations
  late final AnimationController _headerAnimationController;
  late final Animation<Offset> _headerSlideAnimation;
  late final Animation<double> _headerFadeAnimation;
  late final AnimationController _cardAnimationController;
  late final Animation<double> _cardFadeAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSavedConnectionDetails();
    // Initial fetch for tilts
    _tiltsFuture = _fetchTilts();
  }

  void _initAnimations() {
    // Header Animation
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    );
    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Card/Form Animation
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _cardFadeAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    );

    // Logo Pulse Animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardAnimationController.dispose();
    _pulseController.dispose();
    _ipController.dispose();
    _dbNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  // --- Data & Logic Methods ---

  Future<void> _loadSavedConnectionDetails() async {
    final savedDetails = await DatabaseHelper.instance.getConnectionDetails();
    if (savedDetails != null) {
      setState(() {
        _ipController.text = savedDetails['ip'] as String? ?? '';
        _dbNameController.text = savedDetails['dbName'] as String? ?? '';
        _usernameController.text = savedDetails['username'] as String? ?? '';
        _passwordController.text = savedDetails['password'] as String? ?? '';
        _portController.text = savedDetails['port'] as String? ?? '1433';
        // Load saved TiltId/Name for dropdown initial value
        _selectedTiltId = int.tryParse(
          savedDetails['tiltId'] as String? ?? '0',
        );
        _selectedTiltName = savedDetails['tiltName'] as String? ?? '';
      });
      // Re-fetch tilts after loading details
      _tiltsFuture = _fetchTilts();
    }
  }

  // Common logic to fetch Tilt list from SQL Server
  Future<List<Map<String, dynamic>>> _fetchTilts() async {
    try {
      final ip = _ipController.text.trim();
      final port = _portController.text.trim();
      final dbName = _dbNameController.text.trim();
      final user = _usernameController.text.trim();
      final pass = _passwordController.text.trim();

      if (ip.isEmpty ||
          port.isEmpty ||
          dbName.isEmpty ||
          user.isEmpty ||
          pass.isEmpty) {
        debugPrint("⚠️ _fetchTilts: Connection details incomplete.");
        // Return empty list if details are missing
        return [];
      }

      // Connect if not already connected
      if (!await SqlConn.isConnected) {
        debugPrint("🔗 _fetchTilts: Connecting to $ip:$port/$dbName...");
        await SqlConn.connect(
          ip: ip,
          port: port,
          databaseName: dbName,
          username: user,
          password: pass,
        );
      }

      // Query for Tilt table
      const query = "SELECT id, TilitName FROM Tilt"; // Note: Typo in column name? 'TilitName' -> 'TiltName'?
      final result = await SqlConn.readData(query);
      debugPrint("📥 _fetchTilts: Raw result: $result");

      // Parse JSON and convert to List<Map>
      if (result.isEmpty) {
        return [];
      }
      final decoded = jsonDecode(result);
      if (decoded is! List) {
        throw Exception('Unexpected result format: not a list');
      }
      final tilts = decoded.cast<Map<String, dynamic>>();

      // Do not disconnect here; let the connect button handle it if needed

      return tilts;
    } catch (e) {
      debugPrint("❌ Error fetching Tilts: $e");
      return [];
    }
  }

  Future<void> _connectToSqlServer() async {
    if (!_formKey.currentState!.validate() || _selectedTiltId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a Tilt.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!LoaderUtils.hasConnection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Step 1: Connect to SQL
      if (!await SqlConn.isConnected) {
        await SqlConn.connect(
          ip: _ipController.text,
          port: _portController.text,
          databaseName: _dbNameController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        );
        debugPrint("✅ SQL Connected!");
      }

      // Step 2: Fetch device info
      final deviceInfo = await DeviceHelper.getDeviceInfo(); // Removed context dependency
      final deviceName = deviceInfo["DeviceName"] ?? "Unknown Device";

      // Step 3: Save details including deviceName
      await DatabaseHelper.instance.saveConnectionDetails(
        ip: _ipController.text,
        serverName: 'Your_Default_Server_Name', // Consider making this configurable
        dbName: _dbNameController.text,
        username: _usernameController.text,
        password: _passwordController.text, // Security note: Consider using flutter_secure_storage for passwords
        port: _portController.text,
        tiltId: _selectedTiltId.toString(),
        tiltName: _selectedTiltName ?? 'N/A',
        deviceName: deviceName,
        isCashier: 1,
      );

      debugPrint("✅ Connection details + DeviceName ($deviceName) saved to DB");

      // Step 4: Clear users & navigate
      await DatabaseHelper.instance.clearTblUser(); // Why clear users? Add comment if intentional

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected successfully! Device: $deviceName'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              tiltId: _selectedTiltId!,
              tiltName: _selectedTiltName ?? '',
            ),
          ),
        );
      }

      await SqlConn.disconnect();
    } catch (e) {
      debugPrint('❌ Connection or Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kTertiaryColor, Color(0xFF153337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(23.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ), // Max width for large screens
            child: isLargeScreen
                ? _buildLargeScreenLayout()
                : _buildSmallScreenLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return FadeTransition(
      opacity: _cardFadeAnimation,
      child: Card(
        elevation: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: kInputBgColor,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left side - Branding/Welcome
              Expanded(child: _buildBrandingPanel(isLarge: true)),
              // Right side - Form
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _buildForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallScreenLayout() {
    return Card(
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: kInputBgColor,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrandingPanel(isLarge: false),
            const SizedBox(height: 40),
            _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingPanel({required bool isLarge}) {
    final textColor = isLarge ? kTertiaryColor : kPrimaryColor;
    final titleSize = isLarge ? 28.0 : 24.0;
    final subtitleSize = isLarge ? 16.0 : 14.0;

    final brandingContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Image.asset(
            'assets/devaj_logo.png', // Ensure this asset exists in pubspec.yaml
            width: isLarge ? 150 : 120,
            height: isLarge ? 150 : 120,
          ),
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: _headerSlideAnimation,
          child: FadeTransition(
            opacity: _headerFadeAnimation,
            child: Text(
              'Devaj Technology',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                color: textColor,
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (isLarge) ...[
          const SizedBox(height: 10),
          Text(
            'Welcome to the future of data management.',
            style: TextStyle(
              fontSize: subtitleSize,
              color: textColor,
              fontFamily: 'Raleway',
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isLarge) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          gradient: LinearGradient(
            colors: [
              kPrimaryColor.withOpacity(0.8),
              kSecondaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: brandingContent,
        ),
      );
    } else {
      return brandingContent;
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // IP Address
          _buildTextField(
            controller: _ipController,
            label: 'IP Address',
            hint: 'e.g., 192.168.1.100',
            icon: Icons.network_check,
          ),
          const SizedBox(height: 17),

          // Database Name
          _buildTextField(
            controller: _dbNameController,
            label: 'Database Name',
            hint: 'e.g., my_database',
            icon: Icons.storage,
          ),
          const SizedBox(height: 17),

          // SQL Username
          _buildTextField(
            controller: _usernameController,
            label: 'SQL Username',
            hint: 'e.g., sa',
            icon: Icons.person,
          ),
          const SizedBox(height: 17),

          // SQL Password
          TextFormField(
            controller: _passwordController,
            style: const TextStyle(color: kPrimaryColor),
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'SQL Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) =>
                value!.isEmpty ? 'Please enter password' : null,
          ),
          const SizedBox(height: 17),

          // Port
          _buildTextField(
            controller: _portController,
            label: 'Port',
            hint: 'e.g., 1433',
            icon: Icons.settings_ethernet,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          // Tilt Dropdown
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _tiltsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: AppLoader(size: 30, message: "Loading Tilts..."),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  "Error loading Tilts: ${snapshot.error}",
                  style: const TextStyle(color: Colors.redAccent),
                );
              }

              final tilts = snapshot.data ?? [];

              if (tilts.isNotEmpty && _selectedTiltId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedTiltId = tilts.first['id'] as int;
                      _selectedTiltName = tilts.first['TilitName'].toString();
                    });
                  }
                });
              }

              return DropdownButtonFormField<int>(
                value: _selectedTiltId,
                items: tilts.map((t) {
                  return DropdownMenuItem<int>(
                    value: t['id'] as int,
                    child: Text(t['TilitName'].toString()), // Note: Typo in DB column? 'TilitName'
                  );
                }).toList(),
                onChanged: (val) async {
                  setState(() {
                    _selectedTiltId = val ?? 0;
                    _selectedTiltName = tilts
                        .firstWhere((t) => t['id'] == val)['TilitName']
                        .toString();
                  });

                  debugPrint(
                      "🎯 Tilt Changed => $_selectedTiltId ($_selectedTiltName)");
                },
                validator: (value) =>
                    value == null ? 'Please select a Tilt' : null,
              );
            },
          ),

          const SizedBox(height: 32),

          // Connect Button
          ElevatedButton(
            onPressed: _isConnecting ? null : _connectToSqlServer,
            child: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(kTertiaryColor),
                    ),
                  )
                : const Text('Connect to Server'),
          ),
          const SizedBox(height: 10),
          // Test button to re-fetch tilts
          TextButton(
            onPressed: _isConnecting
                ? null
                : () {
                    setState(() {
                      _tiltsFuture = _fetchTilts();
                    });
                  },
            child: Text(
              'Test/Refresh Connection',
              style: TextStyle(color: kSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // Common Text Field Widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: kPrimaryColor),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
    );
  }
}

// -----------------------------------------------------------------------------
// DEVICE HELPER (Separate class)
// -----------------------------------------------------------------------------
class DeviceHelper {
  static Future<Map<String, String>> getDeviceInfo() async { // Removed context; use Platform instead
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      debugPrint(
        "🔥 DeviceInfo (Android): id=${androidInfo.id}, model=${androidInfo.model}",
      );
      return {"TiltId": androidInfo.id, "DeviceName": androidInfo.model};
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      debugPrint(
        "🍏 DeviceInfo (iOS): id=${iosInfo.identifierForVendor}, model=${iosInfo.utsname.machine}",
      );
      return {
        "TiltId": iosInfo.identifierForVendor ?? "Unknown",
        "DeviceName": iosInfo.utsname.machine,
      };
    } else {
      debugPrint("⚠ Unsupported platform for DeviceInfo");
      return {"TiltId": "Unsupported", "DeviceName": "Unsupported Device"};
    }
  }
}