import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stockflow/reusable_widgets/account_settings_style.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:intl/intl.dart';
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
  final bool? isStoreManager;

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
  });
}

// (2. VIEWMODEL)
class AccountSettingsViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    bool isStoreManager = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (isStoreManager) {
      // Verificar se já existe uma loja com esse número
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
      'userEmail': user.email,
      'userId': user.uid,
      'isStoreManager': isStoreManager,
    });
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
    final limitDate = DateTime.now().subtract(Duration(days: 30));

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userData = await _viewModel.loadUserData();
    setState(() {
      _nickname = userData?.name;
      _storeNumber = userData?.storeNumber;
      _isStoreManager = userData?.isStoreManager ?? false;
      _isLoading = false;
    });

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access this feature.'),
        duration: Duration(seconds: 2)),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please complete your setup first")));
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
              title: const Text("Complete Your Setup"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Choose if you are an admin or an employee."),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("I'm the store manager"),
                      value: isStoreManager,
                      onChanged: (value) {setState(() => isStoreManager = value);},
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: storeNumberController,
                      keyboardType: TextInputType.number,
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
                        decoration: const InputDecoration(labelText: "Phone Number"),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: storeLocationController,
                        decoration: const InputDecoration(labelText: "Store Adrress"),
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
                    ],
                  ],
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
                    final storeName = storeNameController.text.trim();
                    final storeEmail = storeEmailController.text.trim();
                    final userPhone = userPhoneController.text.trim();
                    final storeLocation = storeLocationController.text.trim();
                    final storePostalCode = storePostalCodeController.text.trim();
                    final storeCity = storeCityController.text.trim();
                    final storeCountry = storeCountryController.text.trim();

                    if (storeNumber.isEmpty || nickname.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill in the required fields."))); return;
                    }

                    if (isStoreManager &&
                        (storeName.isEmpty ||
                            storeEmail.isEmpty ||
                            userPhone.isEmpty ||
                            storeLocation.isEmpty ||
                            storePostalCode.isEmpty ||
                            storeCity.isEmpty ||
                            storeCountry.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fill in all store details.")),
                      ); return;
                    }

                    try {
                      await _viewModel.saveUserSetup(
                        storeNumber: storeNumber,
                        nickname: nickname,
                        storeName: storeName,
                        storeEmail: storeEmail,
                        userPhone: userPhone,
                        storeLocation: storeLocation,
                        storePostalCode: storePostalCode,
                        storeCity: storeCity,
                        storeCountry: storeCountry,
                        isStoreManager: isStoreManager,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Registration completed successfully!")),
                      );

                      Navigator.pop(context);

                      setState(() {
                        _nickname = nickname;
                        _storeNumber = storeNumber;
                        _isStoreManager = isStoreManager;
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: ${e.toString()}")),
                      );
                    }
                  },
                  child: const Text("Save",style: TextStyle(fontWeight: FontWeight.bold)),
                )
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Store number updated successfully")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete your setup first")),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sending email: ${e.toString()}")));
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