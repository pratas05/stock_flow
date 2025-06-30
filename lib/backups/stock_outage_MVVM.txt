import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';

// [1. MODEL] 
class ProductModel {
  final String id, name, brand, model, category, storeNumber;
  final double basePrice;
  final int stockBreak, stockCurrent;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.category,
    required this.storeNumber,
    required this.basePrice,
    required this.stockBreak,
    required this.stockCurrent,
  });

  factory ProductModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      category: data['category'] ?? '',
      storeNumber: data['storeNumber'] ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      stockBreak: (data['stockBreak'] ?? 0).toInt(),
      stockCurrent: (data['stockCurrent'] ?? 0).toInt(),
    );
  }
}

// [2. VIEWMODEL] 
class StockBreakViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'error': 'User not logged in'};

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return {'error': 'User document not found'};

      return {
        'storeNumber': userDoc.data()?['storeNumber'],
        'isStoreManager': userDoc.data()?['isStoreManager'] ?? false,
        'adminPermission': userDoc.data()?['adminPermission'] ?? '',
        'isPending': userDoc.data()?['isPending'] ?? false, // Add this line
      };
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      return {'error': 'Error fetching user data'};
    }
  }

  Stream<List<ProductModel>> getProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ProductModel.fromDocument(doc)).toList());
  }

  Future<void> transferStock({
    required String productId,
    required int transferQuantity,
    required int currentStockBreak,
    required int currentStockCurrent,
  }) async {
    try {
      final updatedStockBreak = currentStockBreak - transferQuantity;
      final updatedStockCurrent = currentStockCurrent + transferQuantity;

      await _firestore.collection('products').doc(productId).update({
        'stockBreak': updatedStockBreak,
        'stockCurrent': updatedStockCurrent,
      });
    } catch (e) {
      debugPrint("Error transferring stock: $e"); rethrow;
    }
  }

  Future<void> returnProductFromBreakage({
    required String productId,
    required String productName,
    required int breakageQty,
    required String breakageType,
    required String breakageNotificationId,
  }) async {
    try {
      // Fetch the product document
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (!productDoc.exists) {throw Exception("Product not found");}

      final productData = productDoc.data() as Map<String, dynamic>;

      // Determine the stock field based on breakageType
      String stockField = breakageType == 'stockCurrent' ? 'stockCurrent' : 'wareHouseStock';

      // Update the stock in the products collection
      int currentStock = productData[stockField] ?? 0;
      await FirebaseFirestore.instance.collection('products').doc(productId).update({
        stockField: currentStock + breakageQty, // Add the returned quantity to stock
      });

      // Fetch the breakage document
      final breakageDoc = await FirebaseFirestore.instance.collection('breakages').doc(breakageNotificationId).get();
      if (!breakageDoc.exists) {
        throw Exception("Breakage document not found");
      }

      final breakageData = breakageDoc.data() as Map<String, dynamic>;
      int currentBreakageQty = breakageData['breakageQty'] ?? 0;

      // Update or delete the breakage document
      if (currentBreakageQty > breakageQty) {
        // Reduce the breakageQty in the breakages collection
        await FirebaseFirestore.instance.collection('breakages').doc(breakageNotificationId).update({
          'breakageQty': currentBreakageQty - breakageQty,
        });
      } else {
        // Delete the breakage document if all breakages are returned
        await FirebaseFirestore.instance.collection('breakages').doc(breakageNotificationId).delete();
      }
    } catch (e) {
      debugPrint("Error returning product from breakage: $e"); rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getBreakagesStream(String storeNumber) {
    return _firestore
        .collection('breakages')
        .where('storeNumber', isEqualTo: storeNumber)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'productId': data['productId'],
                'productName': data['productName'],
                'breakageQty': data['breakageQty'],
                'breakageType': data['breakageType'],
                'timestamp': data['timestamp'],
              };
            }).toList());
  }

  List<ProductModel> filterProducts({
    required List<ProductModel> products,
    required String nameFilter,
    required String brandFilter,
    required String categoryFilter,
    required String storeNumberFilter,
    required String? priceRange,
    required String userStoreNumber,
  }) {
    double minPrice = 0;
    double maxPrice = double.infinity;

    if (priceRange != null) {
      if (priceRange == '5000+') {
        minPrice = 5000;
      } else {
        final range = priceRange.split('-');
        minPrice = double.tryParse(range[0]) ?? 0;
        maxPrice = double.tryParse(range[1]) ?? double.infinity;
      }
    }

    return products.where((product) {
      if (product.stockBreak < 1) return false;
      
      return product.storeNumber.toLowerCase() == userStoreNumber.toLowerCase() &&
          product.name.toLowerCase().contains(nameFilter.toLowerCase()) &&
          product.brand.toLowerCase().contains(brandFilter.toLowerCase()) &&
          product.category.toLowerCase().contains(categoryFilter.toLowerCase()) &&
          product.basePrice >= minPrice &&
          product.basePrice <= maxPrice;
    }).toList();
  }
}

// [3. VIEW] 
class StockBreakFilteredPage extends StatefulWidget {
  @override
  _StockBreakFilteredPageState createState() => _StockBreakFilteredPageState();
}

class _StockBreakFilteredPageState extends State<StockBreakFilteredPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _storeNumberController = TextEditingController();

  late final StockBreakViewModel _viewModel;
  bool _isLoading = true;
  String? _storeNumber;
  bool _isStoreManager = false;
  String? _selectedBreakageType;
  String? _adminPermission;
  bool _isPending = false; 
  
  @override
  void initState() {
    super.initState();
    _viewModel = StockBreakViewModel();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userData = await _viewModel.getUserData();
    
    if (userData.containsKey('error')) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _storeNumber = userData['storeNumber']?.toString();
      _isStoreManager = userData['isStoreManager'] ?? false;
      _adminPermission = userData['adminPermission']?.toString();
      _isPending = userData['isPending'] ?? false; // Add this line
      _isLoading = false;
      
      if (_storeNumber != null) {
        _storeNumberController.text = _storeNumber!;
      }
    });
  }
  
  bool get _hasModificationPermission {
    // Se não é store manager, não tem permissão
    if (!_isStoreManager) return false;
    
    // Se adminPermission é igual ao storeNumber, tem permissão total
    if (_adminPermission == _storeNumber) return true;
    
    // Caso contrário, não tem permissão
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {return _buildLoadingScreen();}

    if (_storeNumber == null || _storeNumber!.isEmpty) {
      return ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Store Access Required",
        message: "Your account is not associated with any store. Please contact admin.",
      );
    }

    if (_isPending) {
      return ErrorScreen(
        icon: Icons.hourglass_top,
        title: "Pending Approval",
        message: "Your account is pending approval. Please wait for admin authorization.",
      );
    }

    return _buildMainContent();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("CB2B93"),
              hexStringToColor("9546C4"),
              hexStringToColor("5E61F4"),
            ],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(     
      appBar: AppBar(
        title: Text("Stock Break Management", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, elevation: 0,       
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(            
              colors: [
                hexStringToColor("CB2B93"),
                hexStringToColor("9546C4"),
                hexStringToColor("5E61F4"),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              hexStringToColor("CB2B93"),
              hexStringToColor("9546C4"),
              hexStringToColor("5E61F4"),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildFilterControls(),
            Expanded(child: _buildProductList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 0)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header do Filtro
                  Row(
                    children: [
                      Icon(Icons.filter_alt_rounded, color: Colors.white.withOpacity(0.9), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "Filter Breakages",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Clear filters',
                        child: IconButton(
                          icon: Icon(Icons.clear_all,  color: Colors.white.withOpacity(0.7)),
                          onPressed: () {
                            setState(() {
                              _nameController.clear();
                              _selectedBreakageType = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de Pesquisa
                  _buildGlassmorphicTextField(
                    controller: _nameController,
                    hintText: "Search by product name...",
                    icon: Icons.search,
                  ),
                  const SizedBox(height: 12),
                  
                  // Dropdown de Tipo
                  _buildGlassmorphicDropdown(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1, color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1, color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedBreakageType,
          dropdownColor: hexStringToColor("5E61F4").withOpacity(0.95),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.8)),
          style: TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (value) => setState(() => _selectedBreakageType = value),
          items: [
            DropdownMenuItem(
              value: null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("All Breakage Types", style: TextStyle(color: Colors.white70)),
              ),
            ),
            DropdownMenuItem(
              value: 'stockCurrent',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.store, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text("Shop Stock", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'wareHouseStock',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.warehouse, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text("Warehouse Stock", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _viewModel.getBreakagesStream(_storeNumber!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No breakages found.', style: TextStyle(color: Colors.white70, fontSize: 18)),
          );
        }

        final breakages = snapshot.data!;

        final filteredBreakages = breakages.where((breakage) {
          final nameFilter = _nameController.text.toLowerCase();
          final productName = breakage['productName'].toLowerCase();
          
          // Filtro por nome
          final nameMatches = productName.contains(nameFilter);
          
          // Filtro por tipo de breakage (se selecionado)
          final typeMatches = _selectedBreakageType == null || breakage['breakageType'] == _selectedBreakageType;
          
          return nameMatches && typeMatches;
        }).toList();

        if (filteredBreakages.isEmpty) {
          return Center(
            child: Text('No breakages match the filter.', style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          );
        } 

        return ListView.builder(
          itemCount: filteredBreakages.length,
          itemBuilder: (context, index) {
            final breakage = filteredBreakages[index];
            return Container(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_isStoreManager) {_showReturnBreakageDialog(context, breakage);
                    } else {
                      CustomSnackbar.show(
                        context: context,
                        icon: Icons.warning_amber_rounded,
                        message: "You don't have permission to modify stock.",
                        backgroundColor: Colors.red
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                breakage['productName'],
                                style: TextStyle(
                                  color: hexStringToColor("9546C4"),
                                  fontWeight: FontWeight.bold, fontSize: 18,
                                ),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey[300], thickness: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Tooltip(
                              message: 'Stock Location',
                              child: Row(
                                children: [
                                  Icon(
                                    breakage['breakageType'] == 'stockCurrent'
                                        ? Icons.store
                                        : Icons.warehouse,
                                    color: hexStringToColor("5E61F4"),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    breakage['breakageType'] == 'stockCurrent'
                                        ? 'Shop Stock'
                                        : 'WareHouse Stock',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            Tooltip(
                              message: 'Amount of broken stock',
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hexStringToColor("5E61F4").withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: hexStringToColor("5E61F4"), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      color: hexStringToColor("5E61F4"),
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${breakage['breakageQty']} units',
                                      style: TextStyle(
                                        color: hexStringToColor("5E61F4"),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _showReturnBreakageDialog(BuildContext context, Map<String, dynamic> breakage) {
    final TextEditingController quantityController = TextEditingController();
    String? message;
    Color messageColor = Colors.transparent;

    if (!_hasModificationPermission) {
      CustomSnackbar.show(
        context: context,
        icon: Icons.warning_amber_rounded,
        message: "You don't have permission to modify breakage stock.",
        backgroundColor: Colors.red,
      ); return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Return Product from Breakage'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Product Name: ${breakage['productName']}"),
                  Text("Breakage Quantity: ${breakage['breakageQty']}"),
                  Text("Breakage Type: ${breakage['breakageType']}"),
                  SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantity to return",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(message!, style: TextStyle(color: messageColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final returnQuantity = int.tryParse(quantityController.text) ?? 0;

                    if (returnQuantity <= 0) {
                      setState(() {
                        message = "Quantity must be greater than zero.";
                        messageColor = Colors.red;
                      });return;
                    }

                    if (returnQuantity > breakage['breakageQty']) {
                      setState(() {
                        message = "Quantity exceeds available breakage.";
                        messageColor = Colors.red;
                      }); return;
                    }

                    try {
                      await _viewModel.returnProductFromBreakage(
                        productId: breakage['productId'],
                        productName: breakage['productName'],
                        breakageQty: returnQuantity,
                        breakageType: breakage['breakageType'],
                        breakageNotificationId: breakage['id'],
                      );

                      Navigator.of(context).pop();
                      CustomSnackbar.show(
                        context: context,
                        icon: Icons.check_circle,
                        message: "Product returned successfully!",
                        backgroundColor: Colors.green,
                      );
                    } catch (e) {
                      CustomSnackbar.show(
                        context: context,
                        icon: Icons.error,
                        message: "Error returning product: $e",
                        backgroundColor: Colors.red,
                      );
                    }
                  },
                  child: Text('Return'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}