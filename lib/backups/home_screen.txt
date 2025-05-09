import 'package:flutter/material.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/screens/login_screen.dart';
import 'package:stockflow/screens_main/account_settings.dart';
import 'package:stockflow/screens_main/finance_Page.dart';
import 'package:stockflow/screens_main/z_help_page.dart';
import 'package:stockflow/screens_main/product_database.dart';
import 'package:stockflow/screens_main/stock_outage.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/screens_main/warehouse_management.dart';
import 'package:stockflow/screens_main/buy_trade.dart';
import '../screens_main/notificationPage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedOption = '';
  Widget _currentContent = Container();
  bool _isLocked = false;
  String _appPassword = '';
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _isLocked ? _buildLockScreen() : _buildMainScreen());
  }

  Widget _buildMainScreen() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            hexStringToColor("CB2B93"),
            hexStringToColor("9546C4"),
            hexStringToColor("5E61F4"),
          ],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * (1 / 4),
              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.5)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset("assets/images/logo.png", width: 50, height: 50),
                        const SizedBox(width: 8),
                        const Text(
                          "Stock Flow",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.home, color: Colors.white),
                          tooltip: 'Lock Application',
                          onPressed: _lockApplication,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildAdminBox(
                      "Buy and Trades",
                      Icons.shopping_cart,
                      "Purchasing management, suppliers and negotiation control.",
                      () {
                        setState(() {
                          _selectedOption = "Buy and Trades";
                          _currentContent = BuyTradePage();
                        });
                      },
                      _selectedOption == "Buy and Trades",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Account Settings",
                      Icons.account_circle,
                      "Manage your account settings.",
                      () {
                        setState(() {
                          _selectedOption = "Account Settings";
                          _currentContent = AccountSettings();
                        });
                      },
                      _selectedOption == "Account Settings",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Product & Database Management",
                      Icons.inventory,
                      "Creation and Editing of Products and Management of the Relational Database.",
                      () {
                        setState(() {
                          _selectedOption = "Product & Database Management";
                          _currentContent = const ProductDatabasePage();
                        });
                      },
                      _selectedOption == "Product & Database Management",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Transfers & Management of Warehouses",
                      Icons.local_shipping,
                      "Warehouse configuration and transfer control.",
                      () {
                        setState(() {
                          _selectedOption = "Transfers & Management of Warehouses";
                          _currentContent = const WarehouseManagementPage();
                        });
                      },
                      _selectedOption == "Transfers & Management of Warehouses",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Stock Break Management",
                      Icons.warning,
                      "Review of recorded breakages and authorization for stock adjustments.",
                      () {
                        setState(() {
                          _selectedOption = "Stock Break Management";
                          _currentContent = StockBreakFilteredPage();
                        });
                      },
                      _selectedOption == "Stock Break Management",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Finance & Human Resources Management",
                      Icons.people,
                      "Browse through employees and configure financial options.",
                      () {
                        setState(() {
                          _selectedOption = "Finance & Human Resources Management";
                          _currentContent = const FinanceAndHumanResourcesPage();
                        });
                      },
                      _selectedOption == "Finance & Human Resources Management",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Critical Stock Notifications and Alerts",
                      Icons.notifications,
                      "Setting up alerts for stock levels and outages.",
                      () {
                        setState(() {
                          _selectedOption = "Critical Stock Notifications and Alerts";
                          _currentContent = const NotificationsStockAlert();
                        });
                      },
                      _selectedOption == "Critical Stock Notifications and Alerts",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Help",
                      Icons.help,
                      "To provide information and support for new people",
                      () {
                        setState(() {
                          _selectedOption = "Help";
                          _currentContent = HelpPage();
                        });
                      },
                      _selectedOption == "Help",
                    ),
                    _buildDivider(),
                    _buildAdminBox(
                      "Log Out",
                      Icons.exit_to_app,
                      "Monitoramento de setores críticos e auditoria de processos.",
                      confirmLogOut,
                      _selectedOption == "Security and System Quality",
                    ),
                    _buildDivider(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0, left: MediaQuery.of(context).size.width * (1 / 4), right: 0, bottom: 0,
            child: Container(padding: const EdgeInsets.all(0.0), child: _currentContent),
          ),
        ],
      ),
    );
  }

  Widget _buildLockScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            hexStringToColor("CB2B93"),
            hexStringToColor("9546C4"),
            hexStringToColor("5E61F4"),
          ],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter 6-digit Password", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                keyboardType: TextInputType.number, maxLength: 6,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_appPassword.isEmpty) {
                        // First time setting password
                        if (_passwordController.text.length == 6) {
                          setState(() {
                            _appPassword = _passwordController.text;
                            _isLocked = false;
                            _passwordController.clear();
                          });
                        } else {
                          CustomSnackbar.show(
                            context: context, message: 'Password must be 6 digits', duration: Duration(seconds: 2),
                          );
                        }
                      } else {
                        // Verifying password
                        if (_passwordController.text == _appPassword) {
                          setState(() {
                            _isLocked = false;
                            _passwordController.clear();
                          });
                        } else {
                          CustomSnackbar.show(
                            context: context, message: 'Incorrect Password', duration: Duration(seconds: 2),
                          );
                        }
                      }
                    },
                    child: Text(_appPassword.isEmpty ? 'Set Password' : 'Unlock'),
                  ),
                  if (_appPassword.isEmpty) // Mostrar botão Cancel apenas quando não há senha configurada
                    TextButton(
                      onPressed: () {
                        _passwordController.clear();
                        setState(() {
                          _isLocked = false;
                        });
                      },
                      child: Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _lockApplication() {
    if (_appPassword.isEmpty) {
      // First time locking - need to set password
      setState(() {_isLocked = true;});
    } else {
      // Already has password - just lock
      setState(() {
        _isLocked = true;
        _passwordController.clear();
      });
    }
  }

  Widget _buildAdminBox(String title, IconData icon, String description, VoidCallback onTap, bool isSelected) {
    return GestureDetector(
      onTap: _isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 5),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.black, size: 23),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                style: TextStyle(color: isSelected ? Colors.blue : Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.withOpacity(0.5), thickness: 1, height: 30);
  }

  void confirmLogOut() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Log Out"),
          content: Text("Do you really want to log out of your account?"),
          actions: [
            TextButton(onPressed: () {Navigator.of(context).pop();}, child: Text("No")),
            TextButton(
              onPressed: () {Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignInScreen()));},
              child: Text('Yes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}