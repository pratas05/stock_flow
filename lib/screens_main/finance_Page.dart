// MVVM
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/utils/colors_utils.dart';

// [1. MODEL]
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? adminPermission;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.adminPermission,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['userEmail'] ?? '',
      adminPermission: data['adminPermission'],
    );
  }
}

class VatModel {
  final String vat1;
  final String vat2;
  final String vat3;
  final String vat4;

  VatModel({
    required this.vat1,
    required this.vat2,
    required this.vat3,
    required this.vat4,
  });

  factory VatModel.fromMap(Map<String, dynamic> data) {
    return VatModel(
      vat1: data['VAT1']?.toString() ?? '0',
      vat2: data['VAT2']?.toString() ?? '0',
      vat3: data['VAT3']?.toString() ?? '0',
      vat4: data['VAT4']?.toString() ?? '0',
    );
  }

  Map<String, String> toMap() {
    return {
      'VAT1': vat1,
      'VAT2': vat2,
      'VAT3': vat3,
      'VAT4': vat4,
    };
  }
}

// [1. VIEWMODEL]
class FinanceAndHRViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> getStoreNumber() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['storeNumber'] as String?;
    } catch (e) {
      debugPrint("Error fetching store number: $e");
      return null;
    }
  }

  Stream<List<UserModel>> getStoreUsers(String storeNumber) {
    return _firestore
        .collection('users')
        .where('storeNumber', isEqualTo: storeNumber)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  Future<VatModel> getVatValues(String storeNumber) async {
    try {
      final doc = await _firestore.collection('iva').doc(storeNumber).get();
      return VatModel.fromMap(doc.data() ?? {});
    } catch (e) {
      debugPrint("Error fetching VAT values: $e");
      return VatModel(vat1: '0', vat2: '0', vat3: '0', vat4: '0');
    }
  }

  Future<void> updateVatValues(String storeNumber, VatModel vat) async {
    try {
      await _firestore.collection('iva').doc(storeNumber).set(vat.toMap());
    } catch (e) {
      debugPrint("Error updating VAT values: $e");
      rethrow;
    }
  }

  Future<void> toggleAdminPermission(String userId, bool currentPermission, String adminStoreNumber) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'adminPermission': currentPermission ? "" : adminStoreNumber,
      });
    } catch (e) {
      debugPrint("Error updating admin permission: $e"); rethrow;
    }
  }
}

// [3. VIEW]
class FinanceAndHumanResourcesPage extends StatefulWidget {
  const FinanceAndHumanResourcesPage({Key? key}) : super(key: key);

  @override
  _FinanceAndHumanResourcesPageState createState() =>
      _FinanceAndHumanResourcesPageState();
}

class _FinanceAndHumanResourcesPageState
    extends State<FinanceAndHumanResourcesPage> with SingleTickerProviderStateMixin {
  late final FinanceAndHRViewModel _viewModel;
  late TabController _tabController;
  late Future<String?> _storeNumberFuture;

  @override
  void initState() {
    super.initState();
    _viewModel = FinanceAndHRViewModel();
    _storeNumberFuture = _viewModel.getStoreNumber();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: FutureBuilder<String?>(
          future: _storeNumberFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text(
                  'You are not connected to any store. Please contact your Admin.',
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
              );
            }

            final storeNumber = snapshot.data!;
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            return Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      child: Text('Human Resources', style: TextStyle(color: Colors.white)),
                    ),
                    Tab(
                      child: Text('Finance', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHRTab(storeNumber, currentUserId),
                      _buildFinanceTab(storeNumber),
                    ],
                  ),
                ),
              ],
            );
          },
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
            child: Text('Erro ao buscar os usuários.', style: TextStyle(fontSize: 18, color: Colors.black)),
          );
        }

        final users = snapshot.data?.where((user) => user.id != currentUserId).toList() ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Text('Nenhum usuário encontrado para esta loja.', style: TextStyle(fontSize: 18, color: Colors.black)),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final hasAdminPermission = user.adminPermission?.isNotEmpty ?? false;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              elevation: 5,
              child: ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle, color: Colors.purple),
                    IconButton(
                      icon: Icon(
                        hasAdminPermission
                            ? Icons.remove_circle_outline
                            : Icons.admin_panel_settings,
                        color: hasAdminPermission ? Colors.red : Colors.blue,
                      ),
                      onPressed: () => _toggleAdminPermission(user.id, hasAdminPermission, storeNumber),
                    ),
                  ],
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
      child: FutureBuilder<VatModel>(
        future: _viewModel.getVatValues(storeNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error to load IVA values', style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            );
          }

          final vat = snapshot.data ?? VatModel(vat1: '0', vat2: '0', vat3: '0', vat4: '0');
          final controllers = {
            'VAT1': TextEditingController(text: vat.vat1),
            'VAT2': TextEditingController(text: vat.vat2),
            'VAT3': TextEditingController(text: vat.vat3),
            'VAT4': TextEditingController(text: vat.vat4),
          };

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var entry in controllers.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () => _updateVatValues(storeNumber, controllers),
                      child: const Text('Save VAT'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(width: double.infinity, height: MediaQuery.of(context).size.height / 2),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleAdminPermission(String userId, bool currentPermission, String storeNumber) async {
    try {
      await _viewModel.toggleAdminPermission(userId, currentPermission, storeNumber);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentPermission
              ? 'Admin permission removed!'
              : 'Admin permission granted!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating admin permissions.')),
      );
    }
  }

  Future<void> _updateVatValues(String storeNumber, Map<String, TextEditingController> controllers) async {
    try {
      final vat = VatModel(
        vat1: controllers['VAT1']!.text,
        vat2: controllers['VAT2']!.text,
        vat3: controllers['VAT3']!.text,
        vat4: controllers['VAT4']!.text,
      );
      await _viewModel.updateVatValues(storeNumber, vat);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VAT values updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error to update VAT values.')),
      );
    }
  }
}