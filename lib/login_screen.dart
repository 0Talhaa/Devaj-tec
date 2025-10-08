import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sql_conn/sql_conn.dart';
import 'package:start_app/dashboard_screen.dart';
import 'package:start_app/database_halper.dart';
import 'package:start_app/main.dart'; // ConnectionForm ke liye import karna zaroori hai

class LoginScreen extends StatefulWidget {
  final int tiltId;
  final String tiltName;
  const LoginScreen({super.key, required this.tiltId, required this.tiltName});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
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
    // Animation ko sabse pehle initialize karen,
    // taaki koi bhi setState() call hone par error na aaye.
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

  Future<void> _loadConnectionDetails() async {
    final details = await DatabaseHelper.instance.getConnectionDetails();
    if (details != null) {
      setState(() {
        _connectionDetails = details;
      });
      await _fetchUsers();
    } else {
      if (mounted) {
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
  }

  Future<void> _fetchUsers() async {
    if (_connectionDetails == null) return;

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
      );

      final result = await SqlConn.readData("SELECT username FROM tbl_user");
      final parsedResult = jsonDecode(result) as List<dynamic>;
      final users = parsedResult
          .map((row) => (row as Map<String, dynamic>)['username'] as String)
          .toList();

      setState(() {
        _users = users;
        _selectedUser = users.isNotEmpty ? users.first : null;
      });

      SqlConn.disconnect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error fetching users: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

Future<void> _login() async {
  if (_formKey.currentState!.validate() &&
      _selectedUser != null &&
      _connectionDetails != null) {
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
      );

      final loginQuery =
          "SELECT username FROM tbl_user WHERE username = '$_selectedUser' AND pwd = '${_passwordController.text}'";
      final loginResult = await SqlConn.readData(loginQuery);

      // ✅ Agar login success hua
      if (jsonDecode(loginResult).isNotEmpty) {
        // ❌ Admin ko allow mat karo
        if (_selectedUser?.toLowerCase() == "admin") {
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

        // ✅ Pehle purana user delete + naya save karo
        await DatabaseHelper.instance.saveLoggedInUser(_selectedUser!);

        // ✅ Sync aur dashboard pe jao
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
      print('Error during login: $e');
    } finally {
      SqlConn.disconnect();
      setState(() {
        _isConnecting = false;
      });
    }
  }
}


  String _cleanString(String text) {
    return text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').replaceAll(r'\', '');
  }

Future<void> _syncDataAndLogin() async {
  try {
    final categoriesEmpty = await DatabaseHelper.instance.isCategoriesTableEmpty();
    final itemsEmpty = await DatabaseHelper.instance.isItemsTableEmpty();

    if (categoriesEmpty || itemsEmpty) {
      final categoryResult = await SqlConn.readData(
        "SELECT id, category_name FROM CategoryPOS",
      );
      final cleanedCategoryResult = _cleanString(categoryResult);
      final categories = (jsonDecode(cleanedCategoryResult) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      await DatabaseHelper.instance.saveCategories(categories);
      print('Categories saved locally successfully.');

      final itemQuery = """
        SELECT i.id, i.item_name, i.sale_price, i.codes, c.category_name, c.is_tax_apply
        FROM itempos i
        LEFT JOIN categorypos c ON i.category_name = c.category_name
        WHERE i.status = '1';
      """;

      final itemResult = await SqlConn.readData(itemQuery);
      final cleanedItemResult = _cleanString(itemResult);
      final items = (jsonDecode(cleanedItemResult) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      await DatabaseHelper.instance.saveItems(items);
      print('Items saved locally successfully.');
    } else {
      print('Data already exists locally, skipping synchronization.');
    }

    // ✅ Ab navigation karo
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
    print('Error during data synchronization: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data synchronization failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D1D20), // Tertiary color
              Color(0xFF153337), // Darker shade for gradient
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // Screen size ke hisaab se layout chunenge
        child: isLargeScreen
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(21.0),
                  child: _buildLargeScreenLayout(),
                ),
              )
            // Chhoti screen ke liye, SingleChildScrollView istemal karenge
            // taki keyboard aane par overflow na ho
            : SingleChildScrollView(
                padding: const EdgeInsets.all(21.0),
                child: Center(child: _buildSmallScreenLayout()),
              ),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Card(
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF282828),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Side: Logo and text
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF75E5E2).withOpacity(0.8),
                      const Color(0xFF41938F).withOpacity(0.8),
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
                          'assets/devaj_logo.png', // Aapki company ka logo
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
                          color: Color(0xFF0D1D20),
                          fontFamily: 'Raleway',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Welcome to the future of data management.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF0D1D20),
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
      color: const Color(0xFF282828),
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
                    height:
                        logoHeight, // Logo ki height ko orientation ke hisab se adjust karein
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
                color: Color(0xFF75E5E2),
                fontFamily: 'Raleway',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing), // Spacing ko bhi adjust karein
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
              prefixIcon: Icon(Icons.person),
            ),
            style: const TextStyle(
              color: Color(0xFF75E5E2),
              fontFamily: 'Raleway',
            ),
            dropdownColor: const Color(0xFF282828),
            items: _users.map((user) {
              return DropdownMenuItem<String>(
                value: user,
                child: Text(
                  user,
                  style: const TextStyle(color: Color(0xFF75E5E2)),
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
              color: Color(0xFF75E5E2),
              fontFamily: 'Raleway',
            ),
            decoration: InputDecoration(
              labelText: 'Password',
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
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isConnecting ? null : _login,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              backgroundColor: const Color(0xFF75E5E2),
              foregroundColor: const Color(0xFF0D1D20),
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
                      valueColor: AlwaysStoppedAnimation(Color(0xFF0D1D20)),
                    ),
                  )
                : const Text('Login'),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              // Purani details clear karo
              await DatabaseHelper.instance.clearConnectionDetails();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false, // saari purani routes hata do
                );
              }
            },
            child: const Text(
              'Change Connection Details',
              style: TextStyle(
                color: Color(0xFF41938F),
                fontFamily: 'Raleway',
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
