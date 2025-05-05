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
      if (!productDoc.exists) {
        throw Exception("Product not found");
      }

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

      debugPrint("Product returned successfully: $productName");
    } catch (e) {
      debugPrint("Error returning product from breakage: $e");
      rethrow;
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
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _storeNumberController = TextEditingController();
  String? _selectedPriceRange;

  late final StockBreakViewModel _viewModel;
  bool _isLoading = true;
  String? _storeNumber;
  bool _isStoreManager = false;

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
      _isLoading = false;
      
      if (_storeNumber != null) {
        _storeNumberController.text = _storeNumber!;
      }
    });
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
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_nameController, 'Name'),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.clear_all),
                    tooltip: 'Clear filter',
                    onPressed: () {
                      setState(() {
                        _nameController.clear();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
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
          return Center(child: Text('No breakages found.'));
        }

        final breakages = snapshot.data!;

        // Apply the name filter
        final filteredBreakages = breakages.where((breakage) {
          final nameFilter = _nameController.text.toLowerCase();
          final productName = breakage['productName'].toLowerCase();
          return productName.contains(nameFilter);
        }).toList();

        if (filteredBreakages.isEmpty) {
          return Center(child: Text('No breakages match the filter.'));
        }

        return ListView.builder(
          itemCount: filteredBreakages.length,
          itemBuilder: (context, index) {
            final breakage = filteredBreakages[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(
                  breakage['productName'],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Breakage Quantity: ${breakage['breakageQty']}"),
                    Text("Breakage Type: ${breakage['breakageType']}"),
                  ],
                ),
                onTap: () {
                  if (_isStoreManager) {
                    _showReturnBreakageDialog(context, breakage);
                  } else {
                    CustomSnackbar.show(
                      context: context,
                      message: "You don't have permission to modify stock.",
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      isExpanded: true,
      value: _selectedPriceRange,
      onChanged: (value) => setState(() => _selectedPriceRange = value),
      hint: Text("Select Price Range"),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text("All Prices"),
        ),
        ...['0-100', '100-200', '200-300', '300-400',
          '400-500', '500-600', '600-700', '700-800',
          '800-900', '900-1000', '1000-2000', '2000-3000',
          '3000-4000', '4000-5000', '5000+'
        ].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ],
    );
  }

  void _showProductDetailsDialog(BuildContext context, ProductModel product) {
    final TextEditingController quantityController = TextEditingController();
    String? message;
    Color messageColor = Colors.transparent;
    int currentStockBreak = product.stockBreak;
    int currentStockCurrent = product.stockCurrent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Transfer Product'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Product Name: ${product.name}"),
                  Text("Brand: ${product.brand}"),
                  Text("Model: ${product.model}"),
                  Text("Category: ${product.category}"),
                  Text("Stock Break: $currentStockBreak"),
                  Text("Current Stock: $currentStockCurrent"),
                  SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantity to transfer",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: messageColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), 
                  child: Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: () async {
                    final transferQuantity = int.tryParse(quantityController.text) ?? 0;
                    
                    if (transferQuantity <= 0) {
                      setState(() {
                        message = "Quantity must be greater than zero";
                        messageColor = Colors.red;
                      }); 
                      return;
                    }
                    
                    if (transferQuantity > currentStockBreak) {
                      setState(() {
                        message = "Quantity exceeds available stock break";
                        messageColor = Colors.red;
                      });
                      return;
                    }

                    try {
                      await _viewModel.transferStock(
                        productId: product.id,
                        transferQuantity: transferQuantity,
                        currentStockBreak: currentStockBreak,
                        currentStockCurrent: currentStockCurrent,
                      );

                      // Atualiza os valores e limpa o campo
                      setState(() {
                        currentStockBreak -= transferQuantity;
                        currentStockCurrent += transferQuantity;
                        message = "Stock transferred successfully!";
                        messageColor = Colors.green;
                        quantityController.clear(); // Limpa o campo de texto
                      });

                      Future.delayed(Duration(seconds: 3), () { 
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      });
                    } catch (e) {
                      setState(() {
                        message = "Error transferring stock: ${e.toString()}";
                        messageColor = Colors.red;
                      });
                    }
                  },
                  child: Text('Transfer'),
                ),
              ],
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
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: messageColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final returnQuantity = int.tryParse(quantityController.text) ?? 0;

                    if (returnQuantity <= 0) {
                      setState(() {
                        message = "Quantity must be greater than zero.";
                        messageColor = Colors.red;
                      });
                      return;
                    }

                    if (returnQuantity > breakage['breakageQty']) {
                      setState(() {
                        message = "Quantity exceeds available breakage.";
                        messageColor = Colors.red;
                      });
                      return;
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
                        message: "Product returned successfully!",
                      );
                    } catch (e) {
                      CustomSnackbar.show(
                        context: context,
                        message: "Error returning product: $e",
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