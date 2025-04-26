import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';
import 'package:stockflow/reusable_widgets/vat_manager.dart';

// [1. MODEL]
class ProductModel {
  final String? id;
  final String name, description, category, subCategory, brand, model, vatCode, storeNumber, productLocation;
  final int stockMax, stockCurrent, stockOrder, stockMin, wareHouseStock, stockBreak;
  final double lastPurchasePrice, basePrice, vatPrice;
  final Timestamp createdAt;

  ProductModel({
    this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.subCategory,
    required this.brand,
    required this.model,
    required this.stockMax,
    required this.stockCurrent,
    required this.stockOrder,
    required this.stockMin,
    required this.wareHouseStock,
    required this.stockBreak,
    required this.lastPurchasePrice,
    required this.basePrice,
    required this.vatCode,
    required this.vatPrice,
    required this.storeNumber,
    required this.productLocation,
    required this.createdAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      subCategory: data['subCategory'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      stockMax: data['stockMax'] ?? 0,
      stockCurrent: data['stockCurrent'] ?? 0,
      stockOrder: data['stockOrder'] ?? 0,
      stockMin: data['stockMin'] ?? 0,
      wareHouseStock: data['wareHouseStock'] ?? 0,
      stockBreak: data['stockBreak'] ?? 0,
      lastPurchasePrice: data['lastPurchasePrice']?.toDouble() ?? 0.0,
      basePrice: data['basePrice']?.toDouble() ?? 0.0,
      vatCode: data['vatCode'] ?? '',
      vatPrice: data['vatPrice']?.toDouble() ?? 0.0,
      storeNumber: data['storeNumber'] ?? '',
      productLocation: data['productLocation'] ?? 'Not Located',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'subCategory': subCategory,
      'brand': brand,
      'model': model,
      'stockMax': stockMax,
      'stockCurrent': stockCurrent,
      'stockOrder': stockOrder,
      'stockMin': stockMin,
      'wareHouseStock': wareHouseStock,
      'stockBreak': stockBreak,
      'lastPurchasePrice': lastPurchasePrice,
      'basePrice': basePrice,
      'vatCode': vatCode,
      'vatPrice': vatPrice,
      'storeNumber': storeNumber,
      'productLocation': productLocation,
      'createdAt': createdAt,
    };
  }
}

// [1. VIEWMODEL]
class ProductViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentReference> saveProduct(ProductModel product) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user is logged in.");

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final storeNumber = userDoc.data()?['storeNumber'];
      if (storeNumber == null) throw Exception("Store information is missing for the user.");

      return await _firestore.collection('products').add(product.toMap());
    } catch (e) {
      print("Error saving product: $e"); throw e;
    }
  }

  Future<double> _getVatRate(String vatCode, String storeNumber) async {
    try {
      final doc = await _firestore
          .collection('iva')
          .doc(storeNumber)
          .get();

      if (!doc.exists) return 0.0;

      final data = doc.data() ?? {};
      final rateKeys = [
        'VAT$vatCode', 'vat$vatCode', 'IVA$vatCode'
      ];

      for (final key in rateKeys) {
        if (data.containsKey(key)) {
          final rateValue = data[key];
          final double rate = rateValue is int ? rateValue.toDouble() :
                          rateValue is double ? rateValue :
                          rateValue is String ? double.tryParse(rateValue) ?? 0.0 :
                          0.0;
          return rate / 100;
        }
      }
      return 0.0;
    } catch (e) {print('Error getting VAT rate: $e'); return 0.0;}
  }

  Future<void> updateProductsVatPrices(String storeNumber, String vatCode, double newRate) async {
    try {
      // Busca todos os produtos com este VAT code
      final products = await _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: storeNumber)
          .where('vatCode', isEqualTo: vatCode)
          .get();

      // Atualiza cada produto
      for (final productDoc in products.docs) {
        final productData = productDoc.data();
        final basePrice = productData['basePrice']?.toDouble() ?? 0.0;
        final newVatPrice = basePrice * (1 + newRate);

        await productDoc.reference.update({
          'vatPrice': newVatPrice,
        });
      }
    } catch (e) {print('Error updating products VAT prices: $e'); throw e;}
  }

  Future<void> updateProduct(String productId, ProductModel product) async {
    try {
      final storeNumber = await getUserStoreNumber();
      final vatRate = await _getVatRate(product.vatCode, storeNumber);
      
      final updatedProduct = product.toMap();
      updatedProduct['vatPrice'] = product.basePrice * (1 + vatRate);
      
      await _firestore.collection('products').doc(productId).update(updatedProduct);
    } catch (e) {
      print("Error updating product: $e"); throw e;
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  Future<void> createNotification({
    required String message,
    required String notificationType,
    required String productId,
    required String storeNumber,
    required String userId,
  }) async {
    await _firestore.collection('notifications').add({
      'message': message,
      'notificationId': _firestore.collection('notifications').doc().id,
      'notificationType': notificationType,
      'productId': productId,
      'storeNumber': storeNumber,
      'timestamp': Timestamp.now(),
      'userId': userId,
    });
  }

  // Data Retrieval
  Future<String> getUserStoreNumber() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user is logged in.");

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['storeNumber'] ?? '';
  }

  Stream<QuerySnapshot> getProductsStream(String storeNumber) {
    return _firestore
        .collection('products')
        .where('storeNumber', isEqualTo: storeNumber)
        .snapshots();
  }
}

// [3. VIEW]
class ProductDatabasePage extends StatefulWidget {
  const ProductDatabasePage({Key? key}) : super(key: key);

  @override
  _ProductDatabasePageState createState() => _ProductDatabasePageState();
}

class _ProductDatabasePageState extends State<ProductDatabasePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final ProductViewModel _viewModel = ProductViewModel();
  final VatMonitorService _vatMonitor = VatMonitorService();

  // Controllers for product registration
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _stockMaxController = TextEditingController();
  final _wareHouseStockController = TextEditingController();
  final _stockOrderController = TextEditingController(text: "0"); 
  final _stockMinController = TextEditingController();
  final _lastPurchasePriceController = TextEditingController();
  final _basePriceController = TextEditingController(); 
  final _vatCodeController = TextEditingController();
  final _productLocationController = TextEditingController();

  // Controller for search functionality
  final _searchController = TextEditingController();
  String _searchText = "";
  String? _storeNumber;
  bool _isStoreManager = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() { _searchText = _searchController.text;});
    });
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final storeNumber = await _viewModel.getUserStoreNumber();
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      
      setState(() {
        _storeNumber = storeNumber;
        _isStoreManager = userDoc.data()?['isStoreManager'] ?? false;
      });
      
      // Inicia o monitoramento do VAT após obter o storeNumber
      if (_storeNumber != null && _storeNumber!.isNotEmpty) {
        _vatMonitor.startMonitoring(_storeNumber!);
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    } finally {setState(() => _isLoading = false);}
  }

  @override
  void dispose() {
    _vatMonitor.stopMonitoring();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    // Validate all required fields
    final requiredFields = {
      "Product Name": _nameController.text,
      "Description": _descriptionController.text,
      "Category": _categoryController.text,
      "Subcategory": _subCategoryController.text,
      "Brand": _brandController.text,
      "Model": _modelController.text,
      "Max Stock": _stockMaxController.text,
      "Min Stock": _stockMinController.text,
      "Last Purchase Price": _lastPurchasePriceController.text,
      "VAT Code": _vatCodeController.text,
    };

    final emptyFields = requiredFields.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();

    if (emptyFields.isNotEmpty) {
      _showSnackBar("Please fill all required fields: ${emptyFields.join(', ')}");
      return;
    }

    // Validate VAT Code
    final vatCode = _vatCodeController.text;
    if (!['1', '2', '3', '4'].contains(vatCode)) {
      _showSnackBar("VAT Code must be 1, 2, 3 or 4");
      return;
    }

    // Parse numeric values
    final stockMax = int.tryParse(_stockMaxController.text) ?? 0;
    final stockMin = int.tryParse(_stockMinController.text) ?? 0;
    final stockOrder = int.tryParse(_stockOrderController.text) ?? 0;
    final wareHouseStock = _wareHouseStockController.text.isEmpty
        ? 0
        : int.tryParse(_wareHouseStockController.text) ?? 0;
    final lastPurchasePrice = double.tryParse(_lastPurchasePriceController.text) ?? 0.0;
    final basePrice = double.tryParse(_basePriceController.text) ?? 0.0;

    // Validate stock values
    if (stockMin >= stockMax) {
      _showSnackBar("Stock Min must be less than Stock Max");
      return;
    }
    if (stockOrder > stockMax) {
      _showSnackBar("You cannot order more stock than your warehouse capacity");
      return;
    }
    if (wareHouseStock > stockMax) {
      _showSnackBar("Warehouse Stock cannot exceed Max Stock");
      return;
    }
    if (lastPurchasePrice > basePrice) {
      _showSnackBar("Last Purchase Price cannot exceed Base Price");
      return;
    }
    if (basePrice <= 0) {
      _showSnackBar("Base Price must be greater than 0");
      return;
    }

    try {
      final storeNumber = await _viewModel.getUserStoreNumber();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar("No user is logged in.");
        return;
      }

      // Get VAT rate with proper error handling
      double vatRate;
      try {
        vatRate = await _viewModel._getVatRate(vatCode, storeNumber);
        // print('Retrieved VAT rate: ${vatRate * 100}%'); // Mostra em percentagem
      } catch (e) {
        print('Error getting VAT rate: $e');
        _showSnackBar("Error calculating VAT. Using default rate 0%");
        vatRate = 0.0;
      }

      // Calculate VAT price with rounding to 2 decimal places
      final double vatPrice = double.parse((basePrice * (1 + vatRate)).toStringAsFixed(2));
      // print('Calculated prices - Base: $basePrice, With VAT: $vatPrice');

      final product = ProductModel(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        subCategory: _subCategoryController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        stockMax: stockMax,
        stockCurrent: 0,
        stockOrder: stockOrder,
        stockMin: stockMin,
        wareHouseStock: wareHouseStock,
        stockBreak: 0,
        lastPurchasePrice: lastPurchasePrice,
        basePrice: basePrice,
        vatPrice: vatPrice, // Já arredondado para 2 casas decimais
        vatCode: vatCode,
        storeNumber: storeNumber,
        productLocation: _productLocationController.text.trim().isNotEmpty
            ? _productLocationController.text.trim()
            : 'Not Located',
        createdAt: Timestamp.now(),
      );

      // Save product
      final DocumentReference productRef = await _viewModel.saveProduct(product);
      
      // Create notification with formatted prices
      await _viewModel.createNotification(
        message: "A new product was created: ${_brandController.text} - ${_nameController.text} - ${_modelController.text}.",
        notificationType: "Create",
        productId: productRef.id,
        storeNumber: storeNumber,
        userId: user.uid,
      );

      _showSnackBar("Product saved successfully!");
      _clearFields();
    } catch (e) {
      print("Error in _saveProduct: ${e.toString()}");
      _showSnackBar("Error saving product: ${e.toString()}");
    }
  }

  void _showSnackBar(String message) {
    CustomSnackbar.show(
      context: context, message: message,
    );
  }

  void _clearFields() {
    _nameController.clear();
    _descriptionController.clear();
    _categoryController.clear();
    _subCategoryController.clear();
    _brandController.clear();
    _modelController.clear();
    _stockMaxController.clear();
    _wareHouseStockController.clear(); 
    _stockMinController.clear();
    _lastPurchasePriceController.clear();
    _vatCodeController.clear();
    _productLocationController.clear();
    _basePriceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {return Center(child: CircularProgressIndicator());}

    if (_storeNumber == null || _storeNumber!.isEmpty) {
      return ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Store Access Required",
        message: "Your account is not associated with any store. Please contact admin.",
      );
    }

    int tabCount = _isStoreManager ? 2 : 1; // Configurar o TabController dinamicamente com base em _isStoreManager
    _tabController = TabController(length: tabCount, vsync: this);

    return Scaffold(
      appBar: AppBar(
        title: Text("Products Management", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, elevation: 0, 
        flexibleSpace: _buildGradientContainer(),
        bottom: TabBar(
          controller: _tabController,
          tabs: _buildTabs(),  // Tabs baseadas na condição _isStoreManager
        ),
      ),
      body: _buildGradientContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            if (_isStoreManager) _buildProductForm(),  // Exibe apenas se for Store Manager
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientContainer({Widget? child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            hexStringToColor("CB2B93"),
            hexStringToColor("9546C4"),
            hexStringToColor("5E61F4"),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }

  List<Widget> _buildTabs() {
    List<Widget> tabs = [
      // Exibe sempre o "Edit & Search Products"
      Tab(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 5),
          child: Text("Edit & Search Products", style: TextStyle(color: Colors.white)),
        ),
      ),
    ];

    // Se for Store Manager, adiciona a aba "Register Products"
    if (_isStoreManager) {
      tabs.insert(0,
        Tab(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Text("Register Products", style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }
    return tabs;
  }

  Widget _buildProductForm({bool isEditing = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          ..._buildProductFields(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isEditing)
                _buildButton("Save Product", _saveProduct, width: 140),
              _buildButton("Clear Fields", _clearFields, color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProductFields() {
    return [
      _buildTextField(_nameController, "Product Name"),
      _buildTextField(_descriptionController, "Description", maxLength: 300),
      _buildTextField(_categoryController, "Category"),
      _buildTextField(_subCategoryController, "Subcategory"),
      _buildTextField(_brandController, "Brand"),
      _buildTextField(_modelController, "Model"),
      _buildTextField(_stockMaxController, "Max Stock", isNumber: true),
      _buildTextField(_stockMinController, "Min Stock", isNumber: true),
      _buildTextField(_wareHouseStockController, "WareHouse Stock", isNumber: true),
      // _buildTextField(_stockCurrentController, "Current Stock", isNumber: true, readOnly: true),
      // _buildTextField(_stockBreakController, "Stock Break", isNumber: true, readOnly: true),
      _buildTextField(_stockOrderController, "Order Stock (Default = 0)", isNumber: true),
      _buildTextField(_lastPurchasePriceController, "Last Purchase Price", isNumber: true),
      _buildTextField(_basePriceController, "Base Price", isNumber: true,),
      _buildTextField(_vatCodeController, "VAT Code (1, 2, 3, or 4)", isNumber: true, maxLength: 1),
      _buildTextField(_productLocationController, "Product Location (default: Not Located)"),
    ];
  }

  Widget _buildButton(String label, VoidCallback onPressed, {Color? color, double? width}) {
    return Container(width: width,
      child: ElevatedButton(
        onPressed: onPressed, style: ElevatedButton.styleFrom(foregroundColor: color), child: Text(label),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, int maxLength = 0, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(width: 1000,
        child: TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLength: maxLength > 0 ? maxLength : null,
          inputFormatters: _getInputFormatters(label),
          decoration: _getInputDecoration(label),
          readOnly: readOnly,
          onChanged: (value) {
            if (isNumber && value.isEmpty) {
              controller.text = '';
              controller.selection = TextSelection.collapsed(offset: 0);
            }
          },
        ),
      ),
    );
  }

  List<TextInputFormatter> _getInputFormatters(String label) {
    final filters = {
      "Product Name": '[.,a-zA-Z0-9 ]',
      "Model": '[.,a-zA-Z0-9 ]',
      "Description": '[.,a-zA-Z0-9 ]',
      "Brand": '[a-zA-Z ]',
      "Category": '[a-zA-Z ]',
      "Subcategory": '[a-zA-Z ]',
      "WareHouse Stock": '[0-9]',
      "Max Stock": '[0-9]',
      "Order Stock": '[0-9]',
      "Min Stock": '[0-9]',
      "Last Purchase Price": '[0-9]',
      "VAT Code (1, 2, 3, or 4)": r'[1-4]', 
      "Product Location": '[ -_a-zA-Z0-9]',
      "Base Price": r'[0-9]',
    };
    return filters.containsKey(label)
        ? [FilteringTextInputFormatter.allow(RegExp(filters[label]!))]
        : [];
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label, fillColor: Colors.grey[100], filled: true,
      border: OutlineInputBorder(),
      labelStyle: TextStyle(color: Colors.black),
      hintStyle: TextStyle(color: Colors.grey),
      counterText: label == "Description" ? null : '',
      counterStyle: TextStyle(color: Colors.white),
    );
  }

  Widget _buildProductList() {
    return Column(
      children: [
        _buildSearchBar(),
        FutureBuilder<String>(
          future: _viewModel.getUserStoreNumber(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {return SizedBox.shrink();}
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {return SizedBox.shrink();}
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(alignment: Alignment.centerLeft, // Alinhar a esquerda
                child: Text(
                  'Store Number: ${snapshot.data}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            );
          },
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: _viewModel.getUserStoreNumber(),
            builder: (context, storeSnapshot) {
              if (!storeSnapshot.hasData) {return Center(child: CircularProgressIndicator());}

              if (storeSnapshot.data!.isEmpty) {return Center(child: Text("Store information not available.", 
                style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0))));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _viewModel.getProductsStream(storeSnapshot.data!),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) {return Center(child: CircularProgressIndicator());}

                  var filteredProducts = productSnapshot.data!.docs.where((product) =>
                      product['name'].toString().toLowerCase().contains(_searchText.toLowerCase())).toList();

                  return filteredProducts.isEmpty
                      ? Center(child: Text("No products found"))
                      : ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) =>
                              _buildProductCard(filteredProducts[index]),
                        );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: "Search Product",
              hintText: "Enter product name",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(QueryDocumentSnapshot product) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: Card(
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0), elevation: 2.0,
          child: ListTile(
            contentPadding: EdgeInsets.all(12.0),
            title: Text( product['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brand: ${product['brand'] ?? ''}', style: TextStyle(fontSize: 14)),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.euro_symbol, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '${product['vatPrice'].toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      product['productLocation'] ?? 'Not Located',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildProductActions(product),
            onTap: () => _showProductDetailsDialog(context, product),
          ),
        ),
      ),
    );
  }

  Widget _buildProductActions(QueryDocumentSnapshot product) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isStoreManager)
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final productName = product['name'] ?? 'this product';
              if (await _showDeleteConfirmationDialog(context, productName)) {
                if (await _showSecondConfirmationDialog(context, productName)) {
                  await _viewModel.deleteProduct(product.id);
                  _showSnackBar("'$productName' was permanently deleted");
                }
              }
            },
          ),
      ],
    );
  }

  Future<void> _showProductDetailsDialog(BuildContext context, DocumentSnapshot product) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color highlightColor = Colors.blueAccent;
    bool isEditing = false;
    final productModel = ProductModel.fromFirestore(product);

    final nameController = TextEditingController(text: productModel.name);
    final descriptionController = TextEditingController(text: productModel.description);
    final categoryController = TextEditingController(text: productModel.category);
    final subCategoryController = TextEditingController(text: productModel.subCategory);
    final brandController = TextEditingController(text: productModel.brand);
    final modelController = TextEditingController(text: productModel.model);
    final stockMaxController = TextEditingController(text: productModel.stockMax.toString());
    final stockMinController = TextEditingController(text: productModel.stockMin.toString());
    final stockOrderController = TextEditingController(text: productModel.stockOrder.toString());
    final wareHouseStockController = TextEditingController(text: productModel.wareHouseStock.toString());
    final lastPurchasePriceController = TextEditingController(text: productModel.lastPurchasePrice.toString());
    final basePriceController = TextEditingController(text: productModel.basePrice.toString());
    final vatCodeController = TextEditingController(text: productModel.vatCode);
    final productLocationController = TextEditingController(text: productModel.productLocation);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24), elevation: 10,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Colors.grey[50]!, Colors.grey[100]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "📦 Product Details",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                                if (_isStoreManager) // Só edita se for Admin
                                IconButton(
                                  icon: Icon(isEditing ? Icons.save : Icons.edit, color: isEditing ? Colors.green : Colors.blue),
                                  onPressed: () async {
                                    if (isEditing) { // Create a map to track changed fields
                                      Map<String, Map<String, dynamic>> changedFields = {};
                                      
                                      if (nameController.text != productModel.name) {
                                        changedFields['Name'] = {
                                          'old': productModel.name, 'new': nameController.text
                                        };
                                      }
                                      if (descriptionController.text != productModel.description) {
                                        changedFields['Description'] = {
                                          'old': productModel.description, 'new': descriptionController.text
                                        };
                                      }
                                      if (categoryController.text != productModel.category) {
                                        changedFields['Category'] = {
                                          'old': productModel.category, 'new': categoryController.text
                                        };
                                      }
                                      if (subCategoryController.text != productModel.subCategory) {
                                        changedFields['Sub Category'] = {
                                          'old': productModel.subCategory,'new': subCategoryController.text
                                        };
                                      }
                                      if (brandController.text != productModel.brand) {
                                        changedFields['Brand'] = {
                                          'old': productModel.brand, 'new': brandController.text
                                        };
                                      }
                                      if (modelController.text != productModel.model) {
                                        changedFields['Model'] = {
                                          'old': productModel.model, 'new': modelController.text
                                        };
                                      }
                                      if (int.tryParse(stockMaxController.text) != productModel.stockMax) {
                                        changedFields['Stock Max'] = {
                                          'old': productModel.stockMax.toString(),'new': stockMaxController.text
                                        };
                                      }
                                      if (int.tryParse(stockMinController.text) != productModel.stockMin) {
                                        changedFields['Stock Min'] = {
                                          'old': productModel.stockMin.toString(), 'new': stockMinController.text
                                        };
                                      }
                                      if (int.tryParse(stockOrderController.text) != productModel.stockOrder) {
                                        changedFields['Stock Order'] = {
                                          'old': productModel.stockOrder.toString(), 'new': stockOrderController.text
                                        };
                                      }
                                      if (int.tryParse(wareHouseStockController.text) != productModel.wareHouseStock) {
                                        changedFields['Warehouse Stock'] = {
                                          'old': productModel.wareHouseStock.toString(), 'new': wareHouseStockController.text
                                        };
                                      }
                                      if (double.tryParse(lastPurchasePriceController.text) != productModel.lastPurchasePrice) {
                                        changedFields['Last Purchase Price'] = {
                                          'old': productModel.lastPurchasePrice.toString(), 'new': lastPurchasePriceController.text
                                        };
                                      }
                                      if (double.tryParse(basePriceController.text) != productModel.basePrice) {
                                        changedFields['Base Price'] = {
                                          'old': productModel.basePrice.toString(), 'new': basePriceController.text
                                        };
                                      }
                                      if (vatCodeController.text != productModel.vatCode) {
                                        changedFields['VAT Code'] = {
                                          'old': productModel.vatCode, 'new': vatCodeController.text
                                        };
                                      }
                                      if (productLocationController.text != productModel.productLocation) {
                                        changedFields['Product Location'] = {
                                          'old': productModel.productLocation, 'new': productLocationController.text
                                        };
                                      }

                                      if (changedFields.isEmpty) {
                                        CustomSnackbar.show(context: context, message: 'No changes were made to the product'); return;
                                      }
                                      // Validate all required fields
                                      if (nameController.text.isEmpty ||
                                          descriptionController.text.isEmpty ||
                                          categoryController.text.isEmpty ||
                                          subCategoryController.text.isEmpty ||
                                          brandController.text.isEmpty ||
                                          modelController.text.isEmpty ||
                                          stockMaxController.text.isEmpty ||
                                          stockMinController.text.isEmpty ||
                                          lastPurchasePriceController.text.isEmpty ||
                                          vatCodeController.text.isEmpty) {
                                        CustomSnackbar.show(context: context, message: 'Please fill in all required fields'); return;
                                      }

                                      int stockMax = int.tryParse(stockMaxController.text) ?? 0;
                                      int stockMin = int.tryParse(stockMinController.text) ?? 0;
                                      int stockOrder = int.tryParse(stockOrderController.text) ?? 0;
                                      int wareHouseStock = int.tryParse(wareHouseStockController.text) ?? productModel.wareHouseStock;

                                      if (stockMin >= stockMax) {
                                        CustomSnackbar.show(context: context, message: 'Minimum stock must be less than maximum stock'); return;
                                      }

                                      if (stockOrder > stockMax) {
                                        CustomSnackbar.show(context: context, message: 'You cannot order more stock than your warehouse capacity'); return;
                                      }

                                      try {
                                        final storeNumber = await _viewModel.getUserStoreNumber();
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user == null) throw Exception("No user logged in");

                                        // Get current VAT rate and calculate new vatPrice
                                        final vatRate = await _viewModel._getVatRate(
                                        vatCodeController.text, storeNumber);
                                        final basePrice = double.tryParse(basePriceController.text) ?? 0.0;
                                        final vatPrice = basePrice * (1 + vatRate);

                                        final updatedProduct = ProductModel(
                                          id: product.id,
                                          name: nameController.text,
                                          description: descriptionController.text,
                                          category: categoryController.text,
                                          subCategory: subCategoryController.text,
                                          brand: brandController.text,
                                          model: modelController.text,
                                          stockMax: stockMax,
                                          stockCurrent: productModel.stockCurrent,
                                          stockOrder: stockOrder,
                                          stockMin: stockMin,
                                          wareHouseStock: wareHouseStock,
                                          stockBreak: productModel.stockBreak,
                                          lastPurchasePrice: double.tryParse(lastPurchasePriceController.text) ?? 0.0,
                                          basePrice: double.tryParse(basePriceController.text) ?? 0.0,
                                          vatCode: vatCodeController.text,
                                          vatPrice: vatPrice,
                                          storeNumber: storeNumber,
                                          productLocation: productLocationController.text.isNotEmpty 
                                              ? productLocationController.text 
                                              : 'Not Located',
                                          createdAt: productModel.createdAt,
                                        );

                                        await _viewModel.updateProduct(product.id, updatedProduct);
                                        StringBuffer notificationMessage = StringBuffer();
                                        notificationMessage.write("Product - ${updatedProduct.name} had some fields updated:\n");
                                        
                                        changedFields.forEach((field, values) {
                                          notificationMessage.write(
                                            "• $field: From '${values['old']}' to '${values['new']}';  "
                                          );
                                        });
                                        await _viewModel.createNotification(
                                          message: notificationMessage.toString(),
                                          notificationType: "Edit",
                                          productId: product.id,
                                          storeNumber: storeNumber,
                                          userId: user.uid,
                                        );

                                        CustomSnackbar.show(
                                          context: context, message: "Product updated successfully!",
                                        );
                                        
                                        setState(() => isEditing = false);
                                      } catch (e) {
                                        print("Error updating product: $e");
                                        CustomSnackbar.show(context: context, message: 'Error updating product');
                                      }
                                    } else {setState(() => isEditing = true);}
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Container(height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor.withOpacity(0.3), Colors.transparent],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _buildEditableProductInfoSection(
                                isEditing,
                                nameController,
                                descriptionController,
                                categoryController,
                                subCategoryController,
                                brandController,
                                modelController,
                                highlightColor,
                              ),
                              SizedBox(height: 16),
                              _buildEditableStockInfoSection(
                                isEditing,
                                stockMaxController,
                                stockMinController,
                                stockOrderController,
                                wareHouseStockController,
                                productModel,
                                highlightColor,
                              ),
                              SizedBox(height: 16),
                              _buildEditablePricingSection(
                                isEditing,
                                lastPurchasePriceController,
                                basePriceController,
                                highlightColor,
                                productModel,
                              ),
                              SizedBox(height: 16),
                              _buildEditableAdditionalInfoSection(
                                isEditing,
                                vatCodeController,
                                productLocationController,
                                productModel,
                                highlightColor,
                              ),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: Text("Close", style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditableProductInfoSection(
    bool isEditing,
    TextEditingController nameController,
    TextEditingController descriptionController,
    TextEditingController categoryController,
    TextEditingController subCategoryController,
    TextEditingController brandController,
    TextEditingController modelController,
    Color highlightColor,
  ) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditableDetailRow(
            isEditing,
            Icons.shopping_bag,
            "Product Name",
            nameController,
            highlightColor,
            isRequired: true,
          ),
          Divider(height: 24, thickness: 1),
          _buildEditableDetailRow(
            isEditing,
            Icons.description,
            "Description",
            descriptionController,
            highlightColor,
            isRequired: true, maxLines: 3,
          ),
          Divider(height: 24, thickness: 1),
          _buildEditableDetailRow(
            isEditing,
            Icons.category,
            "Category",
            categoryController,
            highlightColor,
            isRequired: true,
          ),
          Divider(height: 24, thickness: 1),
          _buildEditableDetailRow(
            isEditing,
            Icons.subtitles,
            "Subcategory",
            subCategoryController,
            highlightColor,
            isRequired: true,
          ),
          Divider(height: 24, thickness: 1),
          _buildEditableDetailRow(
            isEditing,
            Icons.branding_watermark,
            "Brand",
            brandController,
            highlightColor,
            isRequired: true,
          ),
          Divider(height: 24, thickness: 1),
          _buildEditableDetailRow(
            isEditing,
            Icons.model_training,
            "Model",
            modelController,
            highlightColor,
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableStockInfoSection(
    bool isEditing,
    TextEditingController stockMaxController,
    TextEditingController stockMinController,
    TextEditingController stockOrderController,
    TextEditingController wareHouseStockController,
    ProductModel productModel,
    Color highlightColor,
  ) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: highlightColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.inventory, size: 20, color: highlightColor),
              ),
              const SizedBox(width: 16),
              Text(
                "Stock Information",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildEditableStockRow(
            isEditing,
            "Max Stock",
            stockMaxController,
            Colors.blue,
            isRequired: true, isNumber: true,
          ),
          Divider(height: 16, thickness: 1),
          _buildEditableStockRow(
            isEditing,
            "Warehouse Stock",
            wareHouseStockController,
            Colors.green,
            isNumber: true, isRequired: true,
          ),
          Divider(height: 16, thickness: 1),
          _buildStockRow(
            "Current Stock",
            productModel.stockCurrent.toString(),
            productModel.stockCurrent <= productModel.stockMin ? Colors.orange : Colors.green,
          ),
          Divider(height: 16, thickness: 1),
          _buildEditableStockRow(
            isEditing,
            "Order Stock",
            stockOrderController,
            Colors.blue,
            isNumber: true, isRequired: true,
          ),
          Divider(height: 16, thickness: 1),
          _buildEditableStockRow(
            isEditing,
            "Min Stock",
            stockMinController,
            Colors.blue,
            isRequired: true, isNumber: true,
          ),
          Divider(height: 16, thickness: 1),
          _buildStockRow("Stock Break", productModel.stockBreak.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildEditablePricingSection(
    bool isEditing,
    TextEditingController lastPurchasePriceController,
    TextEditingController basePriceController,
    Color highlightColor,
    ProductModel product,
  ) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: highlightColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.attach_money, size: 20, color: highlightColor),
              ),
              SizedBox(width: 16),
              Text("Pricing Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditablePriceRow(
            isEditing, "Base Price", basePriceController,Colors.green, isNumber: true,
          ),
          
          _buildPriceRow(
            "Price with VAT (${product.vatCode})",
            "€${product.vatPrice.toStringAsFixed(2)}", Colors.purple,
          ),

         const Divider(height: 16, thickness: 1),
          _buildEditablePriceRow(
            isEditing,
            "Last Purchase Price", lastPurchasePriceController, Colors.blue, isRequired: true, isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color color) {
  return Row(
    children: [
      const SizedBox(width: 40),
      Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
      Expanded(flex: 1,
        child: Text(
          value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

  Widget _buildEditableAdditionalInfoSection(
    bool isEditing,
    TextEditingController vatCodeController,
    TextEditingController productLocationController,
    ProductModel productModel,
    Color highlightColor,
  ) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isEditing
              ? TextFormField(
                  controller: vatCodeController,
                  decoration: InputDecoration(
                    labelText: "VAT Code (1-4)",
                    prefixIcon: Icon(Icons.confirmation_number, color: highlightColor),
                    border: OutlineInputBorder(),
                    hintText: "Enter 1, 2, 3 or 4",
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[1-4]')), // Esta é a linha crucial!
                  LengthLimitingTextInputFormatter(1),
                ],
                  validator: (value) {if (value == null || value.isEmpty) return 'VAT Code is required'; return null;},
                )
              : _buildDetailRow(
                  Icons.confirmation_number,
                  "VAT Code", vatCodeController.text, highlightColor,
                ),
          const Divider(height: 24, thickness: 1),
          
          _buildEditableDetailRow(
            isEditing,
            Icons.location_on,
            "Product Location", productLocationController, highlightColor,
          ),
          Divider(height: 24, thickness: 1),
          
          _buildDetailRow(
            Icons.calendar_today,
            "Created At", _formatDate(productModel.createdAt), highlightColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDetailRow(
    bool isEditing, IconData icon, String label,
    TextEditingController controller,
    Color highlightColor, {
    bool isRequired = false,
    bool isNumber = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: highlightColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: highlightColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRequired ? "$label *" : label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              isEditing
                  ? TextFormField(
                      controller: controller,
                      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                      maxLines: maxLines,
                      maxLength: maxLength,
                      decoration: InputDecoration(isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                    )
                  : Text(
                      controller.text.isNotEmpty ? controller.text : 'Not specified',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableStockRow(
    bool isEditing,
    String label,
    TextEditingController controller,
    Color color, {
    bool isRequired = false,
    bool isNumber = false,
  }) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(flex: 2,
          child: Text(isRequired ? "$label *" : label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(flex: 1,
          child: isEditing
              ? TextFormField(
                  controller: controller,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(),
                  ),
                )
              : Text(
                  controller.text,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  textAlign: TextAlign.right,
                ),
        ),
      ],
    );
  }

  Widget _buildEditablePriceRow(
    bool isEditing,
    String label,
    TextEditingController controller,
    Color color, {
    bool isRequired = false,
    bool isNumber = false,
  }) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(flex: 2,
          child: Text(isRequired ? "$label *" : label,  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(flex: 1,
          child: isEditing
              ? TextFormField(
                  controller: controller,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(),
                    prefixText: isNumber ? '€' : null,
                  ),
                )
              : Text(
                  "€${controller.text}",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  textAlign: TextAlign.right,
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color highlightColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: highlightColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: highlightColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'Not specified',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockRow(String label, String value, Color color) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
        Expanded(flex: 1,
          child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context, productName) async {
    return (await showDialog<bool>(context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text("Confirm Deletion"),
            content: Text("Are you sure you want to delete this product?"),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("No")),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Yes", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        )) ?? false;
  }

  Future<bool> _showSecondConfirmationDialog(BuildContext context, String productName) async {
    return (await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Final Confirmation"),
        content: Text("You are about to permanently delete '$productName'. This action cannot be undone. Are you absolutely sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Delete Permanently", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    )) ?? false;
  }
}