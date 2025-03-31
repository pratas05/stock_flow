import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stockflow/utils/colors_utils.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// [1. MODEL]
class UserData {
  final String? name;
  final String? storeNumber;
  final String? email;
  final String? userId;

  UserData({
    this.name,
    this.storeNumber,
    this.email,
    this.userId,
  });
}

// [2. VIEWMODEL]
class AccountSettingsViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserData?> loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists || snapshot.data()?['storeNumber'] == null) {
      return null;
    }
    return UserData(
      name: snapshot.data()?['name'],
      storeNumber: snapshot.data()?['storeNumber'],
      email: user.email,
      userId: user.uid,
    );
  }

  Future<void> saveUserSetup({
    required String storeNumber,
    required String nickname,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'storeNumber': storeNumber,
      'name': nickname,
      'userEmail': user.email,
      'adminPermission': storeNumber,
      'userId': user.uid,
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

  Future<Map<String, List<Map<String, dynamic>>>> getActivitiesForDate(
      String storeNumber, DateTime date) async {
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

// [3. VIEW]
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
      _isLoading = false;
    });

    if ((_nickname == null || _storeNumber == null) && _showSetupDialogOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog(context);
        setState(() => _showSetupDialogOnLoad = false);
      });
    } else if (_storeNumber != null) {
      _loadDaysWithActivities();
    }
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

  Widget _buildLoadingScreen() {return const Center();}

  Widget _buildMainContent() {
    final buttons = [
      _buildQuickActionButton(
        "See Store Number",
        Icons.store,
        "Have access to your store number.",
        onPressed: () => _showEditStoreNumberDialog(context),
      ),
      _buildQuickActionButton(
        "Edit Account Information",
        Icons.person,
        "Update your personal information.",
        onPressed: () => _showEditPersonalInfoDialog(context),
      ),
      _buildQuickActionButton(
        "Change Password",
        Icons.lock,
        "Change your credentials, via email",
        onPressed: () => _showChangePasswordDialog(context),
      ),
      _buildQuickActionButton(
        "Activity History",
        Icons.history,
        "View employee schedules by date",
        onPressed: isSetupComplete
            ? () => _showCalendarDialog(context)
            : () => _showSetupSnackBar(context),
        isEnabled: isSetupComplete,
      ),
      _buildQuickActionButton(
        "Privacy Policy",
        Icons.privacy_tip,
        "View our terms and conditions",
        onPressed: () => _showTermsAndConditions(context),
      ),
    ];
    
    return Stack(
      children: [Positioned(right: 0, top: 0, bottom: 0, child: _buildButtonsContainer(buttons))],
    );
  }

  Widget _buildButtonsContainer(List<Widget> buttons) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            ..._buildButtonListWithSpacing(buttons),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtonListWithSpacing(List<Widget> buttons) {
    return buttons
        .expand((button) => [button, const SizedBox(height: 20)])
        .toList();
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    String description, {
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    bool _isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = isEnabled),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * 0.4,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.blue[100]
                    : Colors.white.withOpacity(isEnabled ? 1.0 : 0.6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.2),
                    spreadRadius: 2, blurRadius: 10,
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                ],
                border: Border.all(color: _isHovered ? Colors.black : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _isHovered ? 1.5 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(icon, color: Colors.black.withOpacity(isEnabled ? 1.0 : 0.6), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                                color: Colors.black
                                    .withOpacity(isEnabled ? 1.0 : 0.6)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 300),
                          child: Text(description,
                              style: TextStyle(fontSize: 14,
                                  color: Colors.black.withOpacity(isEnabled ? 0.7 : 0.5))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCalendarDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.7; // 80% da largura da tela

    await showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: SizedBox(
            width: dialogWidth, // Largura controlada
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Store $_storeNumber - ',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const TextSpan(
                            text: 'Select Date',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 30)),
                      lastDay: DateTime.now(),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        Navigator.pop(context);
                        _showActivitiesForDate(selectedDay);
                      },
                      calendarStyle: CalendarStyle(
                        cellMargin: const EdgeInsets.all(1),
                        defaultTextStyle: const TextStyle(fontSize: 12),
                        todayTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        selectedTextStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        defaultDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
                        selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(
                            color: Colors.purpleAccent, width: 1.5,
                          ),
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        headerMargin: EdgeInsets.only(bottom: 4),
                        titleTextStyle: TextStyle(fontSize: 14),
                        leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                        rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: 10),
                        weekendStyle: TextStyle(fontSize: 10),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final hasActivity = _daysWithActivities.contains(
                              DateTime(day.year, day.month, day.day));
                          return Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasActivity ? Colors.blue : Colors.grey[300]!, width: hasActivity ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(fontSize: 12,
                                  color: isSameDay(_selectedDay, day)
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      rowHeight: 36, daysOfWeekHeight: 24,
                    ),
                    const SizedBox(height: 8),
                    TextButton( onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showActivitiesForDate(DateTime date) async {
    if (_storeNumber == null) return;

    setState(() => _isLoading = true);
    try {
      final activitiesByUser = await _viewModel.getActivitiesForDate(_storeNumber!, date);
      setState(() => _isLoading = false);

      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = screenWidth * 0.5;

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SizedBox(
            width: dialogWidth,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center( // Centraliza apenas o título
                    child: Text(
                      'Activities for ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activitiesByUser.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Alinha à esquerda
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Text('No activities found for this date'),
                        ),
                        const Divider(height: 16),
                      ],
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...activitiesByUser.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4),
                                  child: Text(entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                ...entry.value.map((activity) => Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 4),
                                      child: Text(
                                        '• ${activity['action']} at ${activity['time']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )),
                                const Divider(height: 16),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Center( // Centraliza os botões
                    child: Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCalendarDialog(context);
                          },
                          child: const Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog(context, 'Error', 'Failed to load activities: ${e.toString()}');
    }
  }

  void _showSetupSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please complete your setup first")),
    );
  }

  Future<void> _showSetupDialog(BuildContext context) async {
    final storeNumberController = TextEditingController();
    final nicknameController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Complete Your Setup"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter store number and username."),
            const SizedBox(height: 8),
            TextField(
              controller: storeNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Store Number"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showSetupDialogOnLoad = false);
              },
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final storeNumber = storeNumberController.text.trim();
              final nickname = nicknameController.text.trim();

              if (storeNumber.isEmpty || nickname.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill out all fields!")));
                return;
              }

              try {
                await _viewModel.saveUserSetup(
                  storeNumber: storeNumber,
                  nickname: nickname,
                );

                setState(() {
                  _storeNumber = storeNumber;
                  _nickname = nickname;
                  _showSetupDialogOnLoad = false;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Setup completed successfully!")),
                );
                _loadDaysWithActivities();
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: ${e.toString()}")),
                );
              }
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditStoreNumberDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final storeNumberController = TextEditingController(text: _storeNumber);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Store Number"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user != null) Text("Email: ${user.email ?? 'N/A'}"),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: storeNumberController,
                enabled: false,
                decoration: const InputDecoration(labelText: "Store Number"),
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close"))],
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
                  Text("Current Name: $_nickname",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(
                        labelText: "New Name", errorText: errorMessage),
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
                            setState(() => errorMessage =
                                "Failed to update name: ${e.toString()}");
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
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Send Email',
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
                  TextSpan(text: email,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: " to reset your password."),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending email: ${e.toString()}")),
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
            child: Column(
              children: const [
                Text('''Your terms and conditions text here'''),
              ],
            ),
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