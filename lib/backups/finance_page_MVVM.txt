import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/coins.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';
import 'package:stockflow/screens_main/admin.dart';

// [1. MODEL]
class UserModel {
  final String id, name, email;
  final String? adminPermission;
  final String? storeNumber;
  final bool isStoreManager;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.adminPermission,
    this.storeNumber,
    required this.isStoreManager,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();

      if (data == null || !doc.exists) {
        return UserModel(
          id: doc.id,
          name: '',
          email: '',
          adminPermission: null,
          storeNumber: null,
          isStoreManager: false,
        );
      }

      final Map<String, dynamic> dataMap;
      try {
        dataMap = data as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Error casting user data: $e");
        return UserModel(
          id: doc.id,
          name: '',
          email: '',
          adminPermission: null,
          storeNumber: null,
          isStoreManager: false,
        );
      }

      return UserModel(
        id: doc.id,
        name: dataMap['name']?.toString() ?? '',
        email: dataMap['userEmail']?.toString() ?? '',
        storeNumber: dataMap['storeNumber']?.toString(),
        adminPermission: dataMap['adminPermission']?.toString(),
        isStoreManager: dataMap['isStoreManager'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint("Error creating UserModel: $e");
      return UserModel(
        id: doc.id,
        name: '',
        email: '',
        storeNumber: null,
        adminPermission: null,
        isStoreManager: false,
      );
    }
  }
}

class VatModel {
  final String vat0, vat1, vat2, vat3, vat4;

  VatModel({
    required this.vat0,
    required this.vat1,
    required this.vat2,
    required this.vat3,
    required this.vat4,
  });

  factory VatModel.fromMap(Map<String, dynamic> data) {
    return VatModel(
      vat0: data['VAT0']?.toString() ?? '0',
      vat1: data['VAT1']?.toString() ?? '0',
      vat2: data['VAT2']?.toString() ?? '0',
      vat3: data['VAT3']?.toString() ?? '0',
      vat4: data['VAT4']?.toString() ?? '0',
    );
  }

  Map<String, String> toMap() {
    return {
      'VAT0': vat0,
      'VAT1': vat1,
      'VAT2': vat2,
      'VAT3': vat3,
      'VAT4': vat4,
    };
  }

  bool isEqual(VatModel other) {
    return vat0 == other.vat0 &&
           vat1 == other.vat1 &&
           vat2 == other.vat2 &&
           vat3 == other.vat3 &&
           vat4 == other.vat4;
  }
}

// [2. VIEWMODEL]
class FinanceAndHRViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> hasFullAdminAccess() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      
      return user.isStoreManager && user.adminPermission == user.storeNumber;
    } catch (e) {
      debugPrint("Error checking admin access: $e");
      return false;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      debugPrint("Error fetching current user: $e"); return null;
    }
  }

  Future<String?> getStoreNumber() async {
    try {
      final user = await getCurrentUser();
      return user?.storeNumber; // Updated
    } catch (e) {
      debugPrint("Error fetching store number: $e"); return null;
    }
  }

  Future<String?> getCurrentCurrency() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['storeCurrency'] as String?;
    } catch (e) {
      debugPrint("Error fetching current currency: $e"); return null;
    }
  }

  Stream<List<UserModel>> getStoreUsers(String storeNumber) {
    return _firestore
        .collection('users')
        .where('storeNumber', isEqualTo: storeNumber)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Future<VatModel> getVatValues(String? storeNumber) async {
    try {
      if (storeNumber == null || storeNumber.isEmpty) {
        return VatModel(vat0: '0', vat1: '0', vat2: '0', vat3: '0', vat4: '0');
      }

      final doc = await _firestore.collection('iva').doc(storeNumber).get();
      return VatModel.fromMap(doc.data() ?? {});
    } catch (e) {
      debugPrint("Error fetching VAT values: $e");
      return VatModel(vat0: '0', vat1: '0', vat2: '0', vat3: '0', vat4: '0');
    }
  }

  Future<void> updateVatValues(String storeNumber, VatModel vat) async {
    try {
      await _firestore.collection('iva').doc(storeNumber).set(vat.toMap());
    } catch (e) {
      debugPrint("Error updating VAT values: $e"); rethrow;
    }
  }

  Future<void> toggleAdminPermission(
      String userId, bool currentPermission, String adminStoreNumber) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'adminPermission': currentPermission ? "" : adminStoreNumber,
      });
    } catch (e) {
      debugPrint("Error updating admin permission: $e"); rethrow;
    }
  }

  Future<void> updateStoreCurrency(String currencySymbol) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'storeCurrency': currencySymbol,
        });
      }
    } catch (e) {
      debugPrint("Error updating store currency: $e"); rethrow;
    }
  }
}

// [3. VIEW]
class FinanceAndHumanResourcesPage extends StatefulWidget {
  const FinanceAndHumanResourcesPage({Key? key}) : super(key: key);

  @override
  _FinanceAndHumanResourcesPageState createState() => _FinanceAndHumanResourcesPageState();
}

class _FinanceAndHumanResourcesPageState
    extends State<FinanceAndHumanResourcesPage>
    with SingleTickerProviderStateMixin {
  late final FinanceAndHRViewModel _viewModel;
  late TabController _tabController;
  String? _storeNumber;
  late VatModel _initialVatValues;
  bool _isStoreManager = false;
  bool _isLoading = true;
  String? _selectedCurrency;
  bool _hasFullPermission = false;


  @override
  void initState() {
    super.initState();
    _viewModel = FinanceAndHRViewModel();
    _loadUserData();
    _tabController = TabController(length: 3, vsync: this);
    _initialVatValues = VatModel(vat0: '0', vat1: '0', vat2: '0', vat3: '0', vat4: '0');
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    setState(() => _isLoading = true);
    _hasFullPermission = await _viewModel.hasFullAdminAccess();
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _viewModel.getCurrentUser();
      if (user != null) {
        setState(() {
          _storeNumber = user.storeNumber;
          _isStoreManager = user.isStoreManager;
        });

        if (_storeNumber != null && _storeNumber!.isNotEmpty) {
          final vatValues = await _viewModel.getVatValues(_storeNumber);
          setState(() => _initialVatValues = vatValues);
        }
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
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
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_storeNumber == null || _storeNumber!.isEmpty) {
      return ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Store Access Required",
        message: "Your account is not associated with any store. Please contact admin.",
      );
    }

    if (!_isStoreManager || !_hasFullPermission) {
      return ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Access Denied",
        message: "You don't have permissions to access this page.",
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Finance & Human Resources', style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                hexStringToColor("CB2B93"),
                hexStringToColor("9546C4"),
                hexStringToColor("5E61F4"),
              ],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white, // cor do texto selecionado
          unselectedLabelColor:Colors.white70, // cor do texto não selecionado (mais suave)
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Human Resources'),
            Tab(text: 'Finance'),
            Tab(text: 'Administration'),
          ],
        ),
      ),
      body: Container(
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildHRTab(_storeNumber!, FirebaseAuth.instance.currentUser?.uid),
            _buildFinanceTab(_storeNumber!),
            const StoreDashboardPage()
          ],
        ),
      ),
    );
  }

  Widget _buildHRTab(String storeNumber, String? currentUserId) {
    return StreamBuilder<List<UserModel>>(
      stream: _viewModel.getStoreUsers(storeNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading users.', style: TextStyle(fontSize: 18, color: Colors.white)),
          );
        }

        final users = snapshot.data?.where((user) => user.id != currentUserId).toList() ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Text('No users found for this store.', style: TextStyle(fontSize: 18, color: Colors.white)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final hasAdminPermission = user.adminPermission?.isNotEmpty ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Profile Icon with gradient
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.8),
                                  Colors.blue.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.person, color: Colors.white, size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          // Admin Toggle
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: hasAdminPermission
                                    ? [
                                        Colors.blue.withOpacity(0.8),
                                        Colors.lightBlue.withOpacity(0.8),
                                      ]
                                    : [
                                        Colors.grey.withOpacity(0.5),
                                        Colors.grey.withOpacity(0.3),
                                      ],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                hasAdminPermission
                                    ? Icons.admin_panel_settings
                                    : Icons.person_outline,
                                color: Colors.white, size: 28,
                              ),
                              onPressed: () => _toggleAdminPermission(user.id, hasAdminPermission, storeNumber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinanceTab(String storeNumber) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<(VatModel, String?)>(
        future: Future.wait([
          _viewModel.getVatValues(storeNumber),
          _viewModel.getCurrentCurrency(),
        ]).then((results) => (results[0] as VatModel, results[1] as String?)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Error to load financial data', style: TextStyle(fontSize: 18, color: Colors.white)),
            );
          }

          final vat = snapshot.data?.$1 ?? VatModel(vat0: '0', vat1: '0', vat2: '0', vat3: '0', vat4: '0');
          final currentCurrency = snapshot.data?.$2;
          _initialVatValues = vat;
          _selectedCurrency = currentCurrency;

          final controllers = {
            'VAT0': TextEditingController(text: vat.vat0),
            'VAT1': TextEditingController(text: vat.vat1),
            'VAT2': TextEditingController(text: vat.vat2),
            'VAT3': TextEditingController(text: vat.vat3),
            'VAT4': TextEditingController(text: vat.vat4),
          };

          return SingleChildScrollView(
            child: Column(
              children: [
                // VAT Section
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'VAT Configuration', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        // VAT0 - Read only field
                        AbsorbPointer(
                          child: TextField(
                            controller: controllers['VAT0'],
                            decoration: InputDecoration(
                              labelText: 'VAT0 (No Tax)',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            style: TextStyle(color: Colors.grey[700]),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // VAT1-VAT4 - Editable fields
                        for (var entry in controllers.entries)
                          if (entry.key != 'VAT0')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: TextField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: entry.key,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 179, 67, 199),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          onPressed: () => _updateVatValues(storeNumber, controllers),
                          child: const Text('Save VAT Rates', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Currency Section
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Store Currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (currentCurrency != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                                children: [
                                  const TextSpan(
                                      text: 'Current Currency: ',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: currentCurrency),
                                ],
                              ),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: InputDecoration(
                            labelText: 'Select New Currency',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          items: CurrencyConstants.currencyMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.value,
                              child: Text(entry.key),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value == null || value == _selectedCurrency) return;

                            final previousValue = _selectedCurrency;

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Currency Change'),
                                content: Text('This will change the currency to $value for all financial calculations. Continue?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Confirm', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) {
                              setState(() {_selectedCurrency = previousValue;});
                              return;
                            }

                            setState(() { _selectedCurrency = value;});

                            try {
                              await _viewModel.updateStoreCurrency(value);
                              CustomSnackbar.show(
                                context: context,
                                message: 'Currency changed to $value',
                                backgroundColor: Colors.green,
                              );
                            } catch (_) {
                              setState(() { _selectedCurrency = previousValue;});
                              CustomSnackbar.show(
                                context: context,
                                message: 'Error saving currency',
                                backgroundColor: Colors.red,
                              );
                            }
                          },
                          menuMaxHeight: 300,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleAdminPermission(
      String userId, bool currentPermission, String storeNumber) async {
    try {
      await _viewModel.toggleAdminPermission(
          userId, currentPermission, storeNumber);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentPermission
              ? 'Admin permission removed!'
              : 'Admin permission granted!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      );
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Error updating admin permission.',
      );
      debugPrint("Error updating admin permission: $e");
    }
  }

  Future<void> _updateVatValues(String storeNumber,
      Map<String, TextEditingController> controllers) async {
    try {
      final newVat = VatModel(
        vat0: _initialVatValues.vat0, 
        vat1: controllers['VAT1']!.text,
        vat2: controllers['VAT2']!.text,
        vat3: controllers['VAT3']!.text,
        vat4: controllers['VAT4']!.text,
      );

      Map<String, String> changedFields = {};
      if (newVat.vat1 != _initialVatValues.vat1) {
        changedFields['VAT1'] = '${_initialVatValues.vat1} → ${newVat.vat1}';
      }
      if (newVat.vat2 != _initialVatValues.vat2) {
        changedFields['VAT2'] = '${_initialVatValues.vat2} → ${newVat.vat2}';
      }
      if (newVat.vat3 != _initialVatValues.vat3) {
        changedFields['VAT3'] = '${_initialVatValues.vat3} → ${newVat.vat3}';
      }
      if (newVat.vat4 != _initialVatValues.vat4) {
        changedFields['VAT4'] = '${_initialVatValues.vat4} → ${newVat.vat4}';
      }

      if (changedFields.isEmpty) {
        CustomSnackbar.show(
          context: context,
          message: 'No changes detected in VAT values.', backgroundColor: Colors.red,
        );
        return;
      }

      await _viewModel.updateVatValues(storeNumber, newVat);
      setState(() {
        _initialVatValues = newVat;
      });

      final messageBuffer = StringBuffer("VAT codes updated:\n");
      changedFields.forEach((key, value) {
        messageBuffer.write('$key: $value   ');
      });

      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final notificationId =
          FirebaseFirestore.instance.collection('notifications').doc().id;

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set({
        'message': messageBuffer.toString(),
        'notificationId': notificationId,
        'notificationType': 'Update',
        'storeNumber': storeNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      });

      CustomSnackbar.show(
        context: context,
        message: 'VAT values updated successfully.', backgroundColor: Colors.green
      );
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Error updating VAT values.', backgroundColor: Colors.red
      );
    }
  }
}