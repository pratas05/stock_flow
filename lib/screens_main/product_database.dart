//MVVM
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:stockflow/utils/colors_utils.dart';

// [1. MODEL]
class ProductModel {
  final String? id;
  final String name, description, category, subCategory, brand, model;
  final int stockMax, stockCurrent, stockOrder, stockMin, wareHouseStock, stockBreak;
  final double lastPurchasePrice, salePrice;
  final String vatCode, storeNumber, productLocation;
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
    required this.salePrice,
    required this.vatCode,
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
      salePrice: data['salePrice']?.toDouble() ?? 0.0,
      vatCode: data['vatCode'] ?? '',
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
      'salePrice': salePrice,
      'vatCode': vatCode,
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

  Future<void> updateProduct(String productId, ProductModel product) async {
    await _firestore.collection('products').doc(productId).update(product.toMap());
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

class _ProductDatabasePageState extends State<ProductDatabasePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductViewModel _viewModel = ProductViewModel();

  // Controllers for product registration
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _stockMaxController = TextEditingController();
  final _wareHouseStockController = TextEditingController(text: "0");
  final _stockCurrentController = TextEditingController(text: "0");
  final _stockOrderController = TextEditingController(text: "0"); // Default value 0
  final _stockMinController = TextEditingController();
  final _stockBreakController = TextEditingController(text: "0");
  final _lastPurchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController(text: "0");
  final _vatCodeController = TextEditingController();
  final _productLocationController = TextEditingController();

  // Controller for search functionality
  final _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
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
    _showSnackBar("Please fill all required fields: ${emptyFields.join(', ')}"); return;
  }

    final vatCode = _vatCodeController.text;

    int stockMax = int.tryParse(_stockMaxController.text) ?? 0;
    int stockMin = int.tryParse(_stockMinController.text) ?? 0;
    int stockOrder = int.tryParse(_stockOrderController.text) ?? 0; // Will be 0 if empty

    if (stockMin >= stockMax) return _showSnackBar("Stock Min must be less than Stock Max");
    if (stockOrder > stockMax) return _showSnackBar("You cannot order more stock than your warehouse is capable of");

    try {
      final storeNumber = await _viewModel.getUserStoreNumber();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _showSnackBar("No user is logged in.");

      final product = ProductModel(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        subCategory: _subCategoryController.text,
        brand: _brandController.text,
        model: _modelController.text,
        stockMax: stockMax,
        stockCurrent: int.tryParse(_stockCurrentController.text) ?? 0,
        stockOrder: stockOrder,
        stockMin: stockMin,
        wareHouseStock: int.tryParse(_wareHouseStockController.text) ?? 0,
        stockBreak: 0,
        lastPurchasePrice: double.tryParse(_lastPurchasePriceController.text) ?? 0.0,
        salePrice: double.tryParse(_salePriceController.text) ?? 0.0,
        vatCode: vatCode,
        storeNumber: storeNumber,
        productLocation: _productLocationController.text.isNotEmpty 
            ? _productLocationController.text 
            : 'Not Located',
        createdAt: Timestamp.now(),
      );

      final DocumentReference productRef = await _viewModel.saveProduct(product);
      
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
      print("Error saving product: $e");
      _showSnackBar("Error saving product.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearFields() {
    _nameController.clear();
    _descriptionController.clear();
    _categoryController.clear();
    _subCategoryController.clear();
    _brandController.clear();
    _modelController.clear();
    _stockMaxController.clear();
    _stockOrderController.text = "0"; // Reset to default value
    _stockMinController.clear();
    _stockBreakController.clear();
    _lastPurchasePriceController.clear();
    _vatCodeController.clear();
    _productLocationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Products Management", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, elevation: 0,
        flexibleSpace: _buildGradientContainer(),
        bottom: TabBar(
          controller: _tabController,
          tabs: _buildTabs(),
        ),
      ),
      body: _buildGradientContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProductForm(),
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
    return [
      Tab(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 5),
          child: Text("Register Products", style: TextStyle(color: Colors.white)),
        ),
      ),
      Tab(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 5),
          child: Text("Edit & Search Products", style: TextStyle(color: Colors.white)),
        ),
      ),
    ];
  }

  Widget _buildProductForm({bool isEditing = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          ..._buildProductFields(),
          SizedBox(height: 20),
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
      _buildTextField(_productLocationController, "Product Location (default: Not Located)"),

      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(width: 1000,
          child: TextFormField(
            controller: TextEditingController(text: "0"),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'WareHouse Stock',
              labelStyle: TextStyle(color: Colors.black),
              filled: true,
              fillColor: Colors.grey[300],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(width: 1000,
          child: TextFormField(
            controller: TextEditingController(text: "0"),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Current Stock',
              labelStyle: TextStyle(color: Colors.black),
              filled: true,
              fillColor: Colors.grey[300],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(width: 1000,
          child: TextFormField(
            controller: TextEditingController(text: "0"),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Stock Break',
              labelStyle: TextStyle(color: Colors.black),
              filled: true,
              fillColor: Colors.grey[300],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
      ),

      _buildTextField(_stockOrderController, "Order Stock", isNumber: true),
      _buildTextField(_lastPurchasePriceController, "Last Purchase Price", isNumber: true),
      _buildTextField(_salePriceController, "Sale Price", isNumber: true),
      _buildTextField(_vatCodeController, "VAT Code (1, 2, 3, or 4)", 
        isNumber: true,
        maxLength: 1, 
      ),
    ];
  }

  Widget _buildButton(String label, VoidCallback onPressed, {Color? color, double? width}) {
    return Container(
      width: width,
      child: ElevatedButton(
        onPressed: onPressed, style: ElevatedButton.styleFrom(foregroundColor: color),
        child: Text(label),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, int maxLength = 0}) {
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
          onChanged: (value) {
            if (controller.text.isEmpty &&
                ["Sale Price", "Current Stock", "WareHouse Stock", "Order Stock"].contains(label)) {
              controller.text = "0";
              controller.selection = TextSelection.collapsed(offset: controller.text.length);
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
      "Max Stock": '[0-9]',
      "Order Stock": '[0-9]',
      "Min Stock": '[0-9]',
      "Last Purchase Price": '[0-9]',
      "VAT Code (1, 2, 3, or 4)": r'[1-4]', 
      "Product Location": '[a-zA-Z0-9 ]',
      "Sale Price": '[0-9]',
    };
    return filters.containsKey(label)
        ? [FilteringTextInputFormatter.allow(RegExp(filters[label]!))]
        : [];
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      fillColor: Colors.grey[100],
      filled: true,
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox.shrink();
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
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
              if (!storeSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              if (storeSnapshot.data!.isEmpty) {
                return Center(child: Text("Store information not available.", style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0))));}

              return StreamBuilder<QuerySnapshot>(
                stream: _viewModel.getProductsStream(storeSnapshot.data!),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

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
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          elevation: 2.0,
          child: ListTile(
            contentPadding: EdgeInsets.all(12.0),
            title: Text( 
              product['name'], 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brand: ${product['brand'] ?? ''}', 
                  style: TextStyle(fontSize: 14), 
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.euro_symbol, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      '${product['salePrice']}',
                      style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 6),
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
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => _editProduct(product),
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () async {
            if (await _showDeleteConfirmationDialog(context)) {
              await _viewModel.deleteProduct(product.id);
            }
          },
        ),
      ],
    );
  }

  Future<void> _showProductDetailsDialog(BuildContext context, DocumentSnapshot product) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color highlightColor = Colors.blueAccent;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 10,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.grey[50]!, Colors.grey[100]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "📦 Product Details",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [primaryColor.withOpacity(0.3), Colors.transparent]),
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
                        _buildProductInfoSection(product, highlightColor),
                        SizedBox(height: 16),
                        _buildStockInfoSection(product, highlightColor),
                        SizedBox(height: 16),
                        _buildPricingSection(product, highlightColor),
                        SizedBox(height: 16),
                        _buildAdditionalInfoSection(product, highlightColor),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
      ),
    );
  }

  Widget _buildProductInfoSection(DocumentSnapshot product, Color highlightColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(Icons.shopping_bag, "Product Name", product['name'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.description, "Description", product['description'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.category, "Category", product['category'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.subtitles, "Subcategory", product['subCategory'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.branding_watermark, "Brand", product['brand'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.model_training, "Model", product['model'], highlightColor),
        ],
      ),
    );
  }

  Widget _buildStockInfoSection(DocumentSnapshot product, Color highlightColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.1), shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory, size: 20, color: highlightColor),
              ),
              SizedBox(width: 16),
              Text(
                "Stock Information",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildStockRow("Max Stock", product['stockMax'].toString(), Colors.blue),
          Divider(height: 16, thickness: 1),
          _buildStockRow("Warehouse Stock", product['wareHouseStock'].toString(), Colors.green),
          Divider(height: 16, thickness: 1),
          _buildStockRow(
            "Current Stock", 
            product['stockCurrent'].toString(), 
            product['stockCurrent'] <= product['stockMin'] ? Colors.orange : Colors.green
          ),
          Divider(height: 16, thickness: 1),
          _buildStockRow("Order Stock", product['stockOrder'].toString(), Colors.blue),
          Divider(height: 16, thickness: 1),
          _buildStockRow("Min Stock", product['stockMin'].toString(), Colors.blue),
          Divider(height: 16, thickness: 1),
          _buildStockRow("Stock Break", product['stockBreak'].toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildPricingSection(DocumentSnapshot product, Color highlightColor) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.attach_money, size: 20, color: highlightColor),
              ),
              SizedBox(width: 16),
              Text(
                "Pricing Information",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildPriceRow("Sale Price", product['salePrice']?.toString() ?? '0', Colors.green),
          Divider(height: 16, thickness: 1),
          _buildPriceRow("Last Purchase Price", product['lastPurchasePrice']?.toString() ?? '0', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection(DocumentSnapshot product, Color highlightColor) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(Icons.confirmation_number, "VAT Code", product['vatCode'], highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.location_on, "Product Location", product['productLocation'] ?? 'Not Located', highlightColor),
          Divider(height: 24, thickness: 1),
          _buildDetailRow(Icons.calendar_today, "Created At", _formatDate(product['createdAt']), highlightColor),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color highlightColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlightColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: highlightColor),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
        SizedBox(width: 40),
        Expanded(flex: 2,
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(
          flex: 1,
          child: Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, Color color) {
    return Row(
      children: [
        SizedBox(width: 40),
        Expanded(flex: 2,
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(
          flex: 1,
          child: Text(
            "€$value", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
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

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text("Confirm Deletion"),
            content: Text("Are you sure you want to delete this product?"),
            actions: _buildDeleteDialogActions(context),
          ),
        )) ??
        false;
  }

  List<Widget> _buildDeleteDialogActions(BuildContext context) {
    return [
      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("No")),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true), 
          child: Text("Yes", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  Future<void> _editProduct(DocumentSnapshot product) async {
    _populateFormFields(product);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Product"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildProductFields(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                final vatCode = _vatCodeController.text;

                final storeNumber = await _viewModel.getUserStoreNumber();
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception("No user is logged in.");

                final oldProduct = ProductModel.fromFirestore(product);
                final updatedProduct = ProductModel(
                  id: product.id,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  category: _categoryController.text,
                  subCategory: _subCategoryController.text,
                  brand: _brandController.text,
                  model: _modelController.text,
                  stockMax: int.tryParse(_stockMaxController.text) ?? 0,
                  stockCurrent: int.tryParse(_stockCurrentController.text) ?? 0,
                  stockOrder: int.tryParse(_stockOrderController.text) ?? 0,
                  stockMin: int.tryParse(_stockMinController.text) ?? 0,
                  wareHouseStock: int.tryParse(_wareHouseStockController.text) ?? 0,
                  stockBreak: int.tryParse(_stockBreakController.text) ?? 0,
                  lastPurchasePrice: double.tryParse(_lastPurchasePriceController.text) ?? 0.0,
                  salePrice: double.tryParse(_salePriceController.text) ?? 0.0,
                  vatCode: vatCode,
                  storeNumber: storeNumber,
                  productLocation: _productLocationController.text.isNotEmpty 
                      ? _productLocationController.text 
                      : 'Not Located',
                  createdAt: oldProduct.createdAt,
                );

                final changes = _getFieldChanges(oldProduct, updatedProduct);
                if (changes.isEmpty) {
                  _showSnackBar("No changes detected. Modify at least one field to save.");
                  return;
                }

                await _viewModel.updateProduct(product.id, updatedProduct);

                await _viewModel.createNotification(
                  message: "Product - ${updatedProduct.name}. The following fields were updated: ${changes.join(', ')}.",
                  notificationType: "Edit",
                  productId: product.id,
                  storeNumber: storeNumber,
                  userId: user.uid,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Product updated successfully!")));
                Navigator.of(context).pop();
              } catch (e) {
                print("Error updating product: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating product.")));
              }
            },
            child: Text("Save Product"),
          ),
        ],
      ),
    );
  }

  void _populateFormFields(DocumentSnapshot product) {
    final fields = {
      _nameController: product['name'],
      _descriptionController: product['description'],
      _categoryController: product['category'],
      _subCategoryController: product['subCategory'],
      _brandController: product['brand'],
      _modelController: product['model'],
      _stockMaxController: product['stockMax'].toString(),
      _stockCurrentController: product['stockCurrent'].toString(),
      _stockOrderController: product['stockOrder'].toString(),
      _stockMinController: product['stockMin'].toString(),
      _stockBreakController: product['stockBreak'].toString(),
      _lastPurchasePriceController: product['lastPurchasePrice'].toString(),
      _salePriceController: product['salePrice'].toString(),
      _vatCodeController: product['vatCode'],
      _productLocationController: product['productLocation'] ?? 'Not Located',
    };
    fields.forEach((controller, value) => controller.text = value);
  }

  List<String> _getFieldChanges(ProductModel oldProduct, ProductModel newProduct) {
    final changes = <String>[];
    
    if (oldProduct.name != newProduct.name) changes.add('name: "${oldProduct.name}" → "${newProduct.name}"');
    if (oldProduct.description != newProduct.description) changes.add('description: "${oldProduct.description}" → "${newProduct.description}"');
    if (oldProduct.category != newProduct.category) changes.add('category: "${oldProduct.category}" → "${newProduct.category}"');
    if (oldProduct.subCategory != newProduct.subCategory) changes.add('subCategory: "${oldProduct.subCategory}" → "${newProduct.subCategory}"');
    if (oldProduct.brand != newProduct.brand) changes.add('brand: "${oldProduct.brand}" → "${newProduct.brand}"');
    if (oldProduct.model != newProduct.model) changes.add('model: "${oldProduct.model}" → "${newProduct.model}"');
    if (oldProduct.stockMax != newProduct.stockMax) changes.add('stockMax: "${oldProduct.stockMax}" → "${newProduct.stockMax}"');
    if (oldProduct.stockCurrent != newProduct.stockCurrent) changes.add('stockCurrent: "${oldProduct.stockCurrent}" → "${newProduct.stockCurrent}"');
    if (oldProduct.stockOrder != newProduct.stockOrder) changes.add('stockOrder: "${oldProduct.stockOrder}" → "${newProduct.stockOrder}"');
    if (oldProduct.stockMin != newProduct.stockMin) changes.add('stockMin: "${oldProduct.stockMin}" → "${newProduct.stockMin}"');
    if (oldProduct.lastPurchasePrice != newProduct.lastPurchasePrice) changes.add('lastPurchasePrice: "${oldProduct.lastPurchasePrice}" → "${newProduct.lastPurchasePrice}"');
    if (oldProduct.salePrice != newProduct.salePrice) changes.add('salePrice: "${oldProduct.salePrice}" → "${newProduct.salePrice}"');
    if (oldProduct.vatCode != newProduct.vatCode) changes.add('vatCode: "${oldProduct.vatCode}" → "${newProduct.vatCode}"');
    if (oldProduct.productLocation != newProduct.productLocation) changes.add('productLocation: "${oldProduct.productLocation}" → "${newProduct.productLocation}"');
    
    return changes;
  }
}