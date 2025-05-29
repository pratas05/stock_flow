import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stockflow/reusable_widgets/account_settings_style.dart';
import 'package:stockflow/reusable_widgets/coins.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:intl/intl.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/privacy_policy.dart';

// (1. MODEL)
class UserData {
  final String? name;
  final String? storeNumber;
  final String? email;
  final String? userId;
  final String? storeName;
  final String? storeEmail;
  final String? userPhone;
  final String? storeLocation;
  final String? storePostalCode;
  final String? storeCity;
  final String? storeCountry;
  final String? storeCurrency;
  final bool? isStoreManager;
  final String? adminPermission;

  UserData({
    this.name,
    this.storeNumber,
    this.email,
    this.userId,
    this.storeName,
    this.storeEmail,
    this.userPhone,
    this.storeLocation,
    this.storePostalCode,
    this.storeCity,
    this.storeCountry,
    this.isStoreManager,
    this.storeCurrency,
    this.adminPermission,
  });
}

// (2. VIEWMODEL)
class AccountSettingsViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> hasActivityPermission(String? storeNumber) async {
    if (storeNumber == null) return false;
    
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) return false;

    final isStoreManager = snapshot.data()?['isStoreManager'] ?? false;
    final adminPermission = snapshot.data()?['adminPermission'] as String?;

    return isStoreManager && adminPermission == storeNumber;
  }

  Future<UserData?> loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists || snapshot.data()?['storeNumber'] == null) return null;

    return UserData(
      name: snapshot.data()?['name'],
      storeNumber: snapshot.data()?['storeNumber'],
      email: user.email,
      userId: user.uid,
      storeName: snapshot.data()?['storeName'],
      storeEmail: snapshot.data()?['storeEmail'],
      userPhone: snapshot.data()?['userPhone'],
      storeLocation: snapshot.data()?['storeLocation'],
      storePostalCode: snapshot.data()?['storePostalCode'],
      storeCity: snapshot.data()?['storeCity'],
      storeCountry: snapshot.data()?['storeCountry'],
      isStoreManager: snapshot.data()?['isStoreManager'] ?? false,
      adminPermission: snapshot.data()?['adminPermission'],
    );
  }

  Future<void> saveUserSetup({
    required String storeNumber,
    required String nickname,
    required String storeName,
    required String storeEmail,
    required String userPhone,
    required String storeLocation,
    required String storePostalCode,
    required String storeCity,
    required String storeCountry,
    required String storeCurrency,
    bool isStoreManager = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (isStoreManager) {
      // For store managers - verify store number doesn't exist
      final existingStoreQuery = await _firestore
          .collection('users')
          .where('storeNumber', isEqualTo: storeNumber)
          .where('isStoreManager', isEqualTo: true)
          .get();

      if (existingStoreQuery.docs.isNotEmpty) {
        throw Exception('A store already exists with the store number $storeNumber');
      }
    } 

    await _firestore.collection('users').doc(user.uid).set({
      'storeNumber': storeNumber,
      'name': nickname,
      'storeName': isStoreManager ? storeName : null,
      'storeEmail': isStoreManager ? storeEmail : null,
      'userPhone': isStoreManager ? userPhone : null,
      'storeLocation': isStoreManager ? storeLocation : null,
      'storePostalCode': isStoreManager ? storePostalCode : null,
      'storeCity': isStoreManager ? storeCity : null,
      'storeCountry': isStoreManager ? storeCountry : null,
      'storeCurrency': isStoreManager ? storeCurrency : null,
      'userEmail': user.email,
      'userId': user.uid,
      'isStoreManager': isStoreManager,
      'adminPermission': isStoreManager ? storeNumber : "",
    }, SetOptions(merge: true));
  }

  Future<void> updateStoreNumber(String newStoreNumber) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'storeNumber': newStoreNumber,
    });
  }

  Future<void> updateNickname(String newNickname) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'name': newNickname,
      'userId': user.uid,
      'userEmail': user.email,
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  Future<Map<String, List<Map<String, dynamic>>>> getActivitiesForDate(String storeNumber, DateTime date) async {
    final activityRef = _firestore.collection('user_activity');
    final userRef = _firestore.collection('users');
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final usersSnapshot = await userRef.where('storeNumber', isEqualTo: storeNumber).get();
    final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
    if (userIds.isEmpty) return {};

    final snapshot = await activityRef
        .where('userId', whereIn: userIds)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .get();

    final activitiesByUser = <String, List<Map<String, dynamic>>>{};
    for (var doc in snapshot.docs) {
      final timestamp = (doc['timestamp'] as Timestamp).toDate();
      final userId = doc['userId'];
      final userDoc = await userRef.doc(userId).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown User';
      activitiesByUser.putIfAbsent(userName, () => []).add({
        'action': doc['action'],
        'time': DateFormat('HH:mm').format(timestamp),
        'timestamp': timestamp,
      });
    }
    return activitiesByUser;
  }

  Future<Set<DateTime>> getDaysWithActivities(String storeNumber) async {
    final activityRef = _firestore.collection('user_activity');
    final userRef = _firestore.collection('users');
    final limitDate = DateTime.now().subtract(const Duration(days: 30));

    // Primeiro, limpe as atividades antigas
    await _cleanOldActivities(storeNumber, limitDate);

    // Depois obtenha as atividades recentes
    final usersSnapshot = await userRef.where('storeNumber', isEqualTo: storeNumber).get();
    final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
    if (userIds.isEmpty) return {};

    final snapshot = await activityRef
        .where('userId', whereIn: userIds)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(limitDate))
        .orderBy('timestamp', descending: true)
        .get();

    final daysWithActivities = <DateTime>{};
    for (var doc in snapshot.docs) {
      final date = (doc['timestamp'] as Timestamp).toDate();
      daysWithActivities.add(DateTime(date.year, date.month, date.day));
    }
    return daysWithActivities;
  }

  Future<void> scheduleActivityCleanup() async {
    await _cleanOldActivitiesForAllStores(); // Executar uma vez por dia
  }

  Future<void> _cleanOldActivitiesForAllStores() async {
    try {
      final limitDate = DateTime.now().subtract(const Duration(days: 30));
      final storesSnapshot = await _firestore.collection('users')
          .where('isStoreManager', isEqualTo: true)
          .get();

      for (var storeDoc in storesSnapshot.docs) {
        final storeNumber = storeDoc.data()['storeNumber'] as String?;
        if (storeNumber != null) {
          await _cleanOldActivities(storeNumber, limitDate);
        }
      }
    } catch (e) {
      debugPrint('Error in periodic activity cleanup: $e');
    }
  }

  Future<void> _cleanOldActivities(String storeNumber, DateTime limitDate) async {
    try {
      final userRef = _firestore.collection('users');
      final activityRef = _firestore.collection('user_activity');
      
      // Obter todos os usuários da loja
      final usersSnapshot = await userRef.where('storeNumber', isEqualTo: storeNumber).get();
      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      
      if (userIds.isEmpty) return;

      // Consultar atividades antigas
      final query = activityRef
          .where('userId', whereIn: userIds)
          .where('timestamp', isLessThan: Timestamp.fromDate(limitDate));

      // Obter um lote de atividades antigas (para não sobrecarregar)
      final snapshot = await query.limit(500).get();

      // Excluir em lotes para evitar timeout
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Log para debug (opcional)
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Removed ${snapshot.docs.length} old activities for store $storeNumber');
      }
    } catch (e) {
      debugPrint('Error cleaning old activities: $e');
    }
  }
}

// (3. VIEW)
class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final _viewModel = AccountSettingsViewModel();
  String? _nickname;
  String? _storeNumber;
  bool _isLoading = true;
  bool _showSetupDialogOnLoad = true;
  Set<DateTime> _daysWithActivities = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool get isSetupComplete => _storeNumber != null && _nickname != null;
  bool _isStoreManager = false;
  bool _hasActivityPermission = false;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startCleanupTimer();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _startCleanupTimer() {
    // Executar a limpeza imediatamente e depois a cada 24 horas
    _viewModel.scheduleActivityCleanup();
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _viewModel.scheduleActivityCleanup();
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userData = await _viewModel.loadUserData();
    if (userData != null) {
      final hasPermission = await _viewModel.hasActivityPermission(userData.storeNumber);
      setState(() {
        _nickname = userData.name;
        _storeNumber = userData.storeNumber;
        _isStoreManager = userData.isStoreManager ?? false;
        _hasActivityPermission = hasPermission;
      });
    }

    if ((_nickname == null || _storeNumber == null) && _showSetupDialogOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog(context);
        setState(() => _showSetupDialogOnLoad = false);
      });
    } else if (_storeNumber != null) {_loadDaysWithActivities();}
  }

  Future<void> _loadDaysWithActivities() async {
    if (_storeNumber == null) return;
    setState(() => _isLoading = true);
    _daysWithActivities = await _viewModel.getDaysWithActivities(_storeNumber!);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
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
        child: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingScreen() => const Center();

  Widget _buildMainContent() {
    return Stack(children: [Positioned(right: 0, top: 0, bottom: 0, child: _buildButtonsContainer(context))]);
  }

  Widget _buildButtonsContainer(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            ...AccountSettingsWidgets.buildButtonList(
              context: context,
              isSetupComplete: isSetupComplete,
              storeNumber: _storeNumber,
              nickname: _nickname,
              daysWithActivities: _daysWithActivities,
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              onStoreNumberPressed: () => _showEditStoreNumberDialog(context),
              onPersonalInfoPressed: () => _showEditPersonalInfoDialog(context),
              onPasswordPressed: () => _showChangePasswordDialog(context),
              onActivitiesPressed: isSetupComplete
                  ? () => _showCalendarDialog(context)
                  : () => _showSetupSnackBar(context),
              onTermsPressed: () => _showTermsAndConditions(context),
              onCalendarDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                Navigator.pop(context); _showActivitiesForDate(selectedDay);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalendarDialog(BuildContext context) async {
    if (_isStoreManager == false) {_showNoPermissionSnackBar(); return;}

    if (!_hasActivityPermission) {_showNoPermissionSnackBar(); return;}

    await showDialog(
      context: context,
      builder: (context) => AccountSettingsWidgets.calendarDialog(
        context: context,
        storeNumber: _storeNumber,
        daysWithActivities: _daysWithActivities,
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          Navigator.pop(context); _showActivitiesForDate(selectedDay);
        },
      ),
    );
  }

  void _showNoPermissionSnackBar() {
    CustomSnackbar.show(
      context: context,
      message: "You don't have permission to view activities.",
    );
  }

  Future<void> _showActivitiesForDate(DateTime date) async {
    if (_isStoreManager == false || _storeNumber == null) {_showNoPermissionSnackBar(); return;}

    setState(() => _isLoading = true);
    try {
      final activitiesByUser = await _viewModel.getActivitiesForDate(_storeNumber!, date);
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AccountSettingsWidgets.activitiesDialog(
          context: context,
          date: date,
          activitiesByUser: activitiesByUser,
          onBackPressed: () {
            Navigator.pop(context);
            _showCalendarDialog(context);
          },
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog(context, 'Error', 'Failed to load activities: ${e.toString()}');
    }
  }

  void _showSetupSnackBar(BuildContext context) {
    CustomSnackbar.show(context: context, message: "Please complete your setup first.", backgroundColor: Colors.red);
  }

  Future<void> _showSetupDialog(BuildContext context) async {
    final storeNumberController = TextEditingController();
    final nicknameController = TextEditingController();
    final storeNameController = TextEditingController();
    final storeEmailController = TextEditingController();
    final userPhoneController = TextEditingController();
    final storeLocationController = TextEditingController();
    final storePostalCodeController = TextEditingController();
    final storeCityController = TextEditingController();
    final storeCountryController = TextEditingController();

    String? selectedCurrency;
    bool isStoreManager = true;

    // ignore: unused_local_variable
    bool dialogDismissed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Complete Your Setup", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text("Choose if you are an admin or an employee."),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text("I'm the store manager"),
                        value: isStoreManager,
                        onChanged: (value) => setState(() => isStoreManager = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: storeNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: "Store Number"),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nicknameController,
                        decoration: const InputDecoration(labelText: "Your Name"),
                      ),
                      const SizedBox(height: 8),
                      if (isStoreManager) ...[
                        TextField(
                          controller: storeNameController,
                          decoration: const InputDecoration(labelText: "Store Name"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: storeEmailController,
                          decoration: const InputDecoration(labelText: "Store Email"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: userPhoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: "Phone Number"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: storeLocationController,
                          decoration: const InputDecoration(labelText: "Store Address"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: storePostalCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Postal Code"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: storeCityController,
                          decoration: const InputDecoration(labelText: "City"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: storeCountryController,
                          decoration: const InputDecoration(labelText: "Country"),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: "Store Currency",
                            border: OutlineInputBorder(),
                          ),
                          items: CurrencyConstants.currencyMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.value,
                              child: Text(entry.key),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedCurrency = value),
                          validator: (value) {
                            if (isStoreManager && (value == null || value.isEmpty)) {
                              return 'Please select a currency';
                            }
                            return null;
                          },
                          menuMaxHeight: 160,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogDismissed = true;
                    Navigator.pop(context);
                    setState(() => _showSetupDialogOnLoad = false);
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    final storeNumber = storeNumberController.text.trim();
                    final nickname = nicknameController.text.trim();
                    
                    // For employees, only check store number and nickname
                    if (!isStoreManager) {
                      if (storeNumber.isEmpty || nickname.isEmpty) {
                        CustomSnackbar.show(
                          context: context,
                          message: "Please fill store number and your name",
                          backgroundColor: Colors.red,
                        );
                        return;
                      }
                    } 
                    // For store managers, check all fields
                    else {
                      final storeName = storeNameController.text.trim();
                      final storeEmail = storeEmailController.text.trim();
                      final userPhone = userPhoneController.text.trim();
                      final storeLocation = storeLocationController.text.trim();
                      final storePostalCode = storePostalCodeController.text.trim();
                      final storeCity = storeCityController.text.trim();
                      final storeCountry = storeCountryController.text.trim();

                      if (storeName.isEmpty ||
                          storeEmail.isEmpty ||
                          userPhone.isEmpty ||
                          storeLocation.isEmpty ||
                          storePostalCode.isEmpty ||
                          storeCity.isEmpty ||
                          storeCountry.isEmpty ||
                          selectedCurrency == null) {
                        CustomSnackbar.show(
                          context: context,
                          message: "Please fill all fields first",
                          backgroundColor: Colors.red,
                        );
                        return;
                      }
                    }

                    try {
                      await _viewModel.saveUserSetup(
                        storeNumber: storeNumber,
                        nickname: nickname,
                        storeName: isStoreManager ? storeNameController.text.trim() : '',
                        storeEmail: isStoreManager ? storeEmailController.text.trim() : '',
                        userPhone: isStoreManager ? userPhoneController.text.trim() : '',
                        storeLocation: isStoreManager ? storeLocationController.text.trim() : '',
                        storePostalCode: isStoreManager ? storePostalCodeController.text.trim() : '',
                        storeCity: isStoreManager ? storeCityController.text.trim() : '',
                        storeCountry: isStoreManager ? storeCountryController.text.trim() : '',
                        storeCurrency: isStoreManager ? selectedCurrency ?? '' : '',
                        isStoreManager: isStoreManager,
                      );

                      CustomSnackbar.show(
                        context: context,
                        message: "Setup completed successfully",
                      );

                      Navigator.pop(context);

                      setState(() {
                        _nickname = nickname;
                        _storeNumber = storeNumber;
                        _isStoreManager = isStoreManager;
                      });
                    } catch (e) {
                      print(e);
                      CustomSnackbar.show(
                        context: context,
                        message: 'Error to complete your setup: ${e.toString()}',
                        backgroundColor: Colors.red,
                      );
                    }
                  },
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditStoreNumberDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final storeNumberController = TextEditingController(text: _storeNumber);
    String? errorMessage;
    bool isSaving = false;
    
    // Se não tem storeNumber configurado, mostre mensagem e redirecione para setup
    if (_storeNumber == null) {
      CustomSnackbar.show(
        context: context,
        message: "You need to affiliate with a store first",
        backgroundColor: Colors.red,
      );
      _showSetupDialog(context); return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Store Number"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user != null) Text("Email: ${user.email ?? 'N/A'}"),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: storeNumberController,
                    enabled: !_isStoreManager, // Desabilita se for manager
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Store Number",
                      errorText: errorMessage,
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  if (!_isStoreManager)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "You can change your store number",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
                if (!_isStoreManager)
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newStoreNumber = storeNumberController.text.trim();
                            if (newStoreNumber.isEmpty || newStoreNumber == _storeNumber) {
                              setState(() => errorMessage = newStoreNumber.isEmpty
                                  ? "Store number cannot be empty"
                                  : "Store number must be different");
                              return;
                            }

                            setState(() {
                              isSaving = true;
                              errorMessage = null;
                            });

                            try {
                              await _viewModel.updateStoreNumber(newStoreNumber);
                              setState(() {
                                _storeNumber = newStoreNumber;
                              });
                              Navigator.of(context).pop();
                              CustomSnackbar.show(
                                context: context,
                                message: "Store number updated successfully",
                              );
                            } catch (e) {
                              setState(() => errorMessage = "Error: ${e.toString()}");
                            } finally {
                              setState(() => isSaving = false);
                            }
                          },
                    child: isSaving
                        ? const CircularProgressIndicator()
                        : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditPersonalInfoDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_storeNumber == null) {
      CustomSnackbar.show(
        context: context,
        message: "Please complete your setup first.", backgroundColor: Colors.red,
      );
      _showSetupDialog(context); return;
    }

    final nicknameController = TextEditingController(text: _nickname);
    String? errorMessage;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Personal Information"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Email: ${user.email ?? 'N/A'}"),
                  const SizedBox(height: 8.0),
                  Text("Current Name: $_nickname", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(labelText: "New Name", errorText: errorMessage),
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nickname = nicknameController.text.trim();
                          if (nickname.isEmpty || nickname == _nickname) {
                            setState(() => errorMessage = nickname.isEmpty
                                ? "Name cannot be empty."
                                : "Name must be different.");
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            await _viewModel.updateNickname(nickname);
                            setState(() {
                              _nickname = nickname;
                            });
                          } catch (e) {
                            setState(() => errorMessage = "Failed to update name: ${e.toString()}");
                          } finally {
                            setState(() => isSaving = false);
                          }
                        },
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Password Reset"),
        content: const Text("Are you sure you want to reset your password?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Send Email',
            style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _viewModel.sendPasswordResetEmail();
        final email = FirebaseAuth.instance.currentUser?.email;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Password Reset Email Sent"),
            content: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Check your email "),
                  TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: " to reset your password."),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
      } catch (e) {
        CustomSnackbar.show(
          context: context,
          message: "Failed to send password reset email: ${e.toString()}", backgroundColor: Colors.red,
        );
      }
    }
  }

  void _showTermsAndConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Terms and Conditions"),
          content: SingleChildScrollView(
            child: Column(children: const [Text(PrivacyPolicy.privacyPolicyText)]),
          ),
          actions: <Widget>[TextButton(child: const Text("Close"), onPressed: () => Navigator.of(context).pop())],
        );
      },
    );
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        );
      },
    );
  }
}