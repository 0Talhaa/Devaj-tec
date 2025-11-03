import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/dashboard_screen.dart';
import 'package:start_app/main.dart'; // For ConnectionForm
import 'package:start_app/database_halper.dart';
import 'package:start_app/custom_app_loader.dart';
import 'package:start_app/loader_utils.dart';

class LoginScreen extends StatefulWidget {
  final int tiltId;
  final String tiltName;
  const LoginScreen({super.key, required this.tiltId, required this.tiltName});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isConnecting = false;
  String? _selectedUser;
  List<String> _users = [];
  Map<String, dynamic>? _connectionDetails;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation first to avoid issues with setState
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadConnectionDetails();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Load saved connection details from SQLite
  Future<void> _loadConnectionDetails() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details != null) {
      setState(() {
        _connectionDetails = details;
      });
      await _fetchUsers();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved connection details found.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ConnectionForm()),
      );
    }
  }

  // Fetch usernames from SQL Server tbl_user
  Future<void> _fetchUsers() async {
    if (_connectionDetails == null) return;

    AppLoaderOverlay.show(context, message: "Fetching users...");
    setState(() {
      _isConnecting = true;
    });

    try {
      await SqlConn.connect(
        ip: _connectionDetails!['ip'] as String,
        port: _connectionDetails!['port'] as String,
        databaseName: _connectionDetails!['dbName'] as String,
        username: _connectionDetails!['username'] as String,
        password: _connectionDetails!['password'] as String,
        timeout: 10, // Added timeout for better error handling
      );

      // Get database name from SQLite
      final savedDbName = await DatabaseHelper.instance.getSavedDatabaseName();
      final dbName = savedDbName ?? 'HNFOODMULTAN_';
      
      final query = "SELECT username FROM $dbName.dbo.tbl_user";
      final result = await SqlConn.readData(query);
      final parsedResult = jsonDecode(result) as List<dynamic>;
      final users = parsedResult
          .map((row) => (row as Map<String, dynamic>)['username'] as String)
          .toList();

      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
      });

      print('🟢 Fetched ${users.length} users: $users');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error fetching users: $e');
    } finally {
      await SqlConn.disconnect();
      AppLoaderOverlay.hide();
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // Perform login and sync data
  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user and enter a password.'),
          backgroundColor: Colors.orange,
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

    AppLoaderOverlay.show(context, message: "Logging in...");
    setState(() {
      _isConnecting = true;
    });

    try {
      await SqlConn.connect(
        ip: _connectionDetails!['ip'] as String,
        port: _connectionDetails!['port'] as String,
        databaseName: _connectionDetails!['dbName'] as String,
        username: _connectionDetails!['username'] as String,
        password: _connectionDetails!['password'] as String,
        timeout: 10, // Added timeout
      );

      // Get database name from SQLite
      final savedDbName = await DatabaseHelper.instance.getSavedDatabaseName();
      final dbName = savedDbName ?? 'HNFOODMULTAN_';
      
      // Use formatted query
      final loginQuery =
          "SELECT username FROM $dbName.dbo.tbl_user WHERE username = '$_selectedUser' AND pwd = '${_passwordController.text}'";
      final loginResult = await SqlConn.readData(loginQuery);

      if (jsonDecode(loginResult).isNotEmpty) {
        // Restrict admin login
        if (_selectedUser!.toLowerCase() == "admin") {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Admin login is not allowed."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Save logged-in user
        await DatabaseHelper.instance.saveLoggedInUser(_selectedUser!);
        print('🟢 Logged in user: $_selectedUser');

        // Sync data and navigate
        if (mounted) {
          await _syncDataAndLogin();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed: Invalid username or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error during login: $e');
    } finally {
      await SqlConn.disconnect();
      AppLoaderOverlay.hide();
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // Sync categories and items from SQL Server to SQLite
  Future<void> _syncDataAndLogin() async {
    AppLoaderOverlay.hide(); // Hide login loader
    AppLoaderOverlay.show(context, message: "Syncing data...");
    try {
      final categoriesEmpty = await DatabaseHelper.instance.isCategoriesTableEmpty();
      final itemsEmpty = await DatabaseHelper.instance.isItemsTableEmpty();

      if (categoriesEmpty || itemsEmpty) {
        // Get database name from SQLite
        final savedDbName = await DatabaseHelper.instance.getSavedDatabaseName();
        final dbName = savedDbName ?? 'HNFOODMULTAN_';
        
        // Fetch categories
        final categoryQuery = "SELECT id, category_name FROM $dbName.dbo.CategoryPOS";
        final categoryResult = await SqlConn.readData(categoryQuery);
        final categories = (jsonDecode(categoryResult) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        await DatabaseHelper.instance.saveCategories(categories);
        print('🟢 Saved ${categories.length} categories locally');

        // Fetch items with join
        final itemQuery = """
          SELECT i.id, i.item_name, i.sale_price, i.codes, c.category_name, c.is_tax_apply
          FROM $dbName.dbo.itempos i
          LEFT JOIN $dbName.dbo.CategoryPOS c ON i.category_name = c.category_name
          WHERE i.status = '1'
        """;
        final itemResult = await SqlConn.readData(itemQuery);
        final items = (jsonDecode(itemResult) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        await DatabaseHelper.instance.saveItems(items);
        print('🟢 Saved ${items.length} items locally');
      } else {
        print('ℹ️ Data already exists locally, skipping synchronization');
      }

      // Navigate to Dashboard
      AppLoaderOverlay.hide();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: _selectedUser!,
              tiltId: widget.tiltId,
              tiltName: widget.tiltName,
            ),
          ),
        );
      }
    } catch (e) {
      AppLoaderOverlay.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data synchronization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error during data synchronization: $e');
    }
  }

  // Removed _cleanString as it's not needed with proper SQL handling

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kTertiaryColor, Color(0xFF153337)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLargeScreen
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildLargeScreenLayout(),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(child: _buildSmallScreenLayout()),
              ),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Card(
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: kInputBgColor,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Side: Branding
            Expanded(
              child: Container(
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Image.asset(
                          'assets/devaj_logo.png',
                          width: 150,
                          height: 150,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Devaj Technology',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: kTertiaryColor,
                          fontFamily: 'Raleway',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcome to the future of data management.',
                        style: TextStyle(
                          fontSize: 16,
                          color: kTertiaryColor,
                          fontFamily: 'Raleway',
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Right Side: Login Form
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallScreenLayout() {
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    final logoHeight = isPortrait ? 120.0 : 80.0;
    final spacing = isPortrait ? 40.0 : 20.0;

    return Card(
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: kInputBgColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Image.asset(
                    'assets/devaj_logo.png',
                    height: logoHeight,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Devaj Technology',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: kPrimaryColor,
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing),
            _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedUser,
            decoration: const InputDecoration(
              labelText: 'Select User',
              prefixIcon: Icon(Icons.person, color: kPrimaryColor),
            ),
            style: const TextStyle(
              color: kPrimaryColor,
              fontFamily: 'Raleway',
            ),
            dropdownColor: kInputBgColor,
            items: _users.map((user) {
              return DropdownMenuItem<String>(
                value: user,
                child: Text(
                  user,
                  style: const TextStyle(color: kPrimaryColor),
                ),
              );
            }).toList(),
            onChanged: _isConnecting
                ? null
                : (value) {
                    setState(() {
                      _selectedUser = value;
                    });
                  },
            validator: (value) => value == null ? 'Please select a user' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              color: kPrimaryColor,
              fontFamily: 'Raleway',
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock, color: kPrimaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: kPrimaryColor,
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
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isConnecting ? null : _login,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              textStyle: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.bold,
              ),
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(kTertiaryColor),
                    ),
                  )
                : const Text('Login'),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              await DatabaseHelper.instance.clearConnectionDetails();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Change Connection Details',
              style: TextStyle(
                color: kSecondaryColor,
                fontFamily: 'Raleway',
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}