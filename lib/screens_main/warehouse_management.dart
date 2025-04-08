//MVVM
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

// [1. MODEL]
class WarehouseProductModel {
  final String id, name, brand, model, category, description, storeNumber, salePrice;
  final int stockCurrent, stockOrder, stockMin, stockMax, wareHouseStock, stockBreak;
  final String vatCode, subCategory;
  final double lastPurchasePrice;
  final Timestamp createdAt;
  final String productLocation;

  WarehouseProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.category,
    required this.description,
    required this.storeNumber,
    required this.salePrice,
    required this.stockCurrent,
    required this.stockOrder,
    required this.stockMin,
    required this.stockMax,
    required this.wareHouseStock,
    required this.stockBreak,
    required this.vatCode,
    required this.subCategory,
    required this.lastPurchasePrice,
    required this.createdAt,
    required this.productLocation,
  });

  factory WarehouseProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WarehouseProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      storeNumber: data['storeNumber'] ?? '',
      salePrice: (data['salePrice'] ?? 0.0).toDouble(),
      stockCurrent: (data['stockCurrent'] ?? 0).toInt(),
      stockOrder: (data['stockOrder'] ?? 0).toInt(),
      stockMin: (data['stockMin'] ?? 0).toInt(),
      stockMax: (data['stockMax'] ?? 0).toInt(),
      wareHouseStock: (data['wareHouseStock'] ?? 0).toInt(),
      stockBreak: (data['stockBreak'] ?? 0).toInt(),
      vatCode: data['vatCode'] ?? '',
      subCategory: data['subCategory'] ?? '',
      lastPurchasePrice: (data['lastPurchasePrice'] ?? 0.0).toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      productLocation: data['productLocation'] ?? 'Not Located',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'category': category,
      'description': description,
      'storeNumber': storeNumber,
      'salePrice': salePrice,
      'stockCurrent': stockCurrent,
      'stockOrder': stockOrder,
      'stockMin': stockMin,
      'stockMax': stockMax,
      'wareHouseStock': wareHouseStock,
      'stockBreak': stockBreak,
      'vatCode': vatCode,
      'subCategory': subCategory,
      'lastPurchasePrice': lastPurchasePrice,
      'createdAt': createdAt,
      'productLocation': productLocation,
    };
  }
}

// [2. VIEWMODEL]
class WarehouseViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> getCurrentUserStoreNumber() async {
    try {
      final user = _auth.currentUser; if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['storeNumber'] as String?;
    } catch (e) {
      debugPrint("Error fetching store number: $e"); return null;
    }
  }

  Future<List<String>> fetchStores() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => doc.get('storeNumber')?.toString() ?? '')
          .where((storeNumber) => storeNumber.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();
    } catch (e) {
      debugPrint("Error fetching stores: $e");
      return [];
    }
  }

  Future<List<WarehouseProductModel>> fetchProducts(String storeNumber) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: storeNumber)
          .get();
      return snapshot.docs
          .map((doc) => WarehouseProductModel.fromFirestore(doc))
          .toList();
    } catch (e) {debugPrint("Error fetching products: $e"); return [];}
  }

  // In WarehouseViewModel class
  Future<void> transferStockToWarehouse({
    required String productId,
    required int increment,
    required int currentWareHouseStock,
    required int currentShopStock,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'wareHouseStock': currentWareHouseStock + increment,
      'stockCurrent': currentShopStock - increment,
    });
  }

  Future<void> transferStockToShop({
    required String productId,
    required int increment,
    required int currentWareHouseStock,
    required int currentShopStock,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'wareHouseStock': currentWareHouseStock - increment,
      'stockCurrent': currentShopStock + increment,
    });
  }

  Future<void> updateProductPrice({
    required String productId,
    required double newPrice,
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'salePrice': newPrice,
    });
  }

  Future<void> transferBetweenWarehouses({
    required String productName,
    required String fromStore,
    required String toStore,
    required int quantity,
    required Map<String, dynamic> productData,
  }) async {
    try {
      // Get source product
      final fromQuery = await _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: fromStore)
          .where('name', isEqualTo: productName)
          .get();

      if (fromQuery.docs.isEmpty) throw Exception("Product not found in source store");

      final fromDoc = fromQuery.docs.first;
      final currentStock = fromDoc['wareHouseStock'] as int;
      final remainingStock = currentStock - quantity; // Stock que permanece na loja atual

      if (quantity > currentStock) throw Exception("Not enough stock available");

      // Update source warehouse stock
      await fromDoc.reference.update({'wareHouseStock': remainingStock});

      // Check if product exists in destination store
      final toQuery = await _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: toStore)
          .where('name', isEqualTo: productName)
          .get();

      if (toQuery.docs.isEmpty) {
        // Create new product in destination store
        await _firestore.collection('products').add({
          ...productData,
          'storeNumber': toStore,
          'wareHouseStock': quantity,
          'stockCurrent': 0,
          'createdAt': Timestamp.now(),
        });
      } else {
        // Update existing product in destination store
        final toDoc = toQuery.docs.first;
        final currentToStock = toDoc['wareHouseStock'] as int;
        await toDoc.reference.update({
          'wareHouseStock': currentToStock + quantity,
        });
      }

      // Create notification for the transfer
      final user = _auth.currentUser;
      if (user != null) {
        await createNotification(
          message: 'Was sent $quantity $productName from Store $fromStore to Store $toStore. Remaining stock in current store: $remainingStock',
          productId: fromDoc.id,
          storeNumber: fromStore,
          userId: user.uid,
          notificationType: 'Transfer',
        );
      }
    } catch (e) {debugPrint("Error transferring between warehouses: $e"); rethrow;}
  }

  Future<void> createNotification({
    required String message, 
    required String productId,
    required String storeNumber,
    required String userId,
    required String notificationType,
  }) async {
    final notificationRef = await _firestore.collection('notifications').add({
      'message': message,
      'productId': productId,
      'storeNumber': storeNumber,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'notificationType': notificationType,
    });
    await notificationRef.update({'notificationId': notificationRef.id});
  }
}

// [3. VIEW]
class WarehouseManagementPage extends StatefulWidget {
  const WarehouseManagementPage({super.key});

  @override
  _WarehouseManagementPageState createState() => _WarehouseManagementPageState();
}

class _WarehouseManagementPageState extends State<WarehouseManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  bool isPriceEditable = false;
  final WarehouseViewModel _viewModel = WarehouseViewModel();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {_searchText = _searchController.text;});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildWarehouseForm() {
    return FutureBuilder<String?>(
      future: _viewModel.getCurrentUserStoreNumber(),
      builder: (context, AsyncSnapshot<String?> storeSnapshot) {
        if (!storeSnapshot.hasData || storeSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (storeSnapshot.data == null) {return Center(child: Text("No store number assigned to this user."));}
        return Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _viewModel._firestore
                    .collection('products')
                    .where('storeNumber', isEqualTo: storeSnapshot.data!)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var filteredProducts = snapshot.data!.docs.where((product) {
                    return product['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchText.toLowerCase());
                  }).toList();

                  if (filteredProducts.isEmpty) {return Center(child: Text("No products found"));}

                  return ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      var product = filteredProducts[index];
                      return Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          child: Card(
                            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), elevation: 4.0,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16.0),
                              title: Text(
                                product['name'],
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Brand: ${product['brand']}'),
                                  Text('Sale Price: €${product['salePrice']}'),
                                ],
                              ),
                              onTap: () async {await _showProductDetailsDialog(context, product);},
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransferBetweenWarehouses() {
    return Center(
      child: ElevatedButton(
        onPressed: () => _showStoreSelectionDialog(),
        child: Text("Transfer Product"),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white, backgroundColor: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: "Search Product",
              hintText: "Enter Product Name",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProductDetailsDialog(BuildContext context, DocumentSnapshot product) async {
    TextEditingController _incrementController = TextEditingController();
    TextEditingController _salePriceController = TextEditingController(text: product['salePrice'].toString());

    int wareHouseStock = product['wareHouseStock'];
    int stockMin = product['stockMin'];
    int currentStock = product['stockCurrent'];
    String errorMessage = wareHouseStock == 0 ? "You need to order more products" : '';
    String successMessage = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isPriceEditable = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Update Product Details"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Name: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("${product['name']}"),
                    Text("Model: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("${product['model']}"),
                    Text("Current Stock on the Shop: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("$currentStock"),
                    Text("Warehouse Stock: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("$wareHouseStock"),
                    Text("Min Stock on the Shop: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("$stockMin"),
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(errorMessage, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: TextField(
                        controller: _incrementController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Enter Stock to Add from Warehouse to Shop",
                          hintText: "Enter until Max: $wareHouseStock products",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _salePriceController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: "Sale Price",
                                hintText: "Enter Sale Price",
                                border: OutlineInputBorder(),
                              ),
                              enabled: isPriceEditable,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {setState(() {isPriceEditable = true;});},
                          ),
                        ],
                      ),
                    ),
                    if (successMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          successMessage, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: () {Navigator.of(context).pop();}, child: Text("Close")),
                TextButton(
                  onPressed: () async {
                    int increment = int.tryParse(_incrementController.text) ?? 0;

                    if (wareHouseStock == 0) {
                      setState(() {
                        errorMessage = "You need to order more products";
                        successMessage = '';
                      }); return;
                    }

                    if (currentStock < stockMin && increment < stockMin) {
                      setState(() {
                        errorMessage = "You need to put more products in shop";
                        successMessage = '';
                      }); return;
                    }

                    if (increment <= 0) {
                      setState(() {
                        errorMessage = "You need to insert a valid amount of products";
                        successMessage = '';
                      }); return;
                    } else if (increment > wareHouseStock) {
                      setState(() {
                        errorMessage = "You cannot add more stock than the warehouse has";
                        successMessage = '';
                      }); return;
                    }

                    try {
                      final user = _viewModel._auth.currentUser;
                      if (user == null) throw Exception("User not authenticated");

                      final storeNumber = await _viewModel.getCurrentUserStoreNumber();
                      if (storeNumber == null) {
                        setState(() {
                          errorMessage = 'Store number not set. Please configure it in account settings.';
                          successMessage = '';
                        }); return;
                      }

                      await _viewModel.transferStockToShop(
                        productId: product.id,
                        increment: increment,
                        currentWareHouseStock: wareHouseStock,
                        currentShopStock: currentStock,
                      );

                      await _viewModel.createNotification(
                        message: '$increment of ${product['brand']} - ${product['name']} - ${product['model']}, were transferred from Warehouse to Shop.',
                        productId: product.id,
                        storeNumber: storeNumber,
                        userId: user.uid,
                        notificationType: 'Transfer',
                      );

                      setState(() {
                        currentStock += increment;
                        wareHouseStock -= increment;
                        successMessage = "Product stock updated successfully!";
                        errorMessage = '';
                      });
                    } catch (e) {
                      setState(() {
                        errorMessage = "Failed to update stock: ${e.toString()}";
                        successMessage = '';
                      });
                    }
                  },
                  child: Text("Update Stock", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () async {
                    if (isPriceEditable) {
                      double newPrice = double.tryParse(_salePriceController.text) ?? product['salePrice'];

                      if (newPrice == product['salePrice']) {
                        setState(() {
                          errorMessage = "The new price must be different from the current price.";
                          successMessage = '';
                        }); return;
                      }

                      try {
                        final user = _viewModel._auth.currentUser;
                        if (user == null) throw Exception("User not authenticated");

                        final storeNumber = await _viewModel.getCurrentUserStoreNumber();
                        if (storeNumber == null) {
                          setState(() {
                            errorMessage = 'Store number not set. Please configure it in account settings.';
                            successMessage = '';
                          }); return;
                        }

                        final oldPrice = product['salePrice'];
                        await _viewModel.updateProductPrice(
                          productId: product.id,
                          newPrice: newPrice,
                        );

                        await _viewModel.createNotification(
                          message: 'Price of ${product['brand']} - ${product['name']} - ${product['model']} updated from €$oldPrice to €$newPrice.',
                          productId: product.id,
                          storeNumber: storeNumber,
                          userId: user.uid,
                          notificationType: 'UpdatePrice',
                        );

                        setState(() {
                          successMessage = "Sale price updated successfully!";
                          errorMessage = '';
                        });
                      } catch (e) {
                        setState(() {
                          errorMessage = "Failed to update price: ${e.toString()}";
                          successMessage = '';
                        });
                      }
                    }
                  },
                  child: Text("Update Sale Price", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showStoreSelectionDialog() async {
    String? currentStore = await _viewModel.getCurrentUserStoreNumber();
    if (currentStore == null) return;

    TextEditingController toStoreController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Transfer Between Warehouses"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("From Store:"),
                  Text(currentStore, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: toStoreController,
                    decoration: InputDecoration(
                      labelText: "Enter Destination Store Number",
                      errorText: errorMessage,
                    ),
                  ),
                  if (isLoading) const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (toStoreController.text.isEmpty) {
                      setState(() {
                        errorMessage = "Please enter a store number";
                      });
                      return;
                    }

                    if (toStoreController.text == currentStore) {
                      setState(() {
                        errorMessage = "Cannot transfer to the same store";
                      });
                      return;
                    }

                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });

                    // Verificar se o storeNumber existe
                    final stores = await _viewModel.fetchStores();
                    final storeExists = stores.contains(toStoreController.text);

                    setState(() {
                      isLoading = false;
                    });

                    if (!storeExists) {
                      setState(() {
                        errorMessage = "Store number does not exist";
                      });
                      return;
                    }

                    Navigator.of(context).pop();
                    _showProductSelectionDialog(currentStore, toStoreController.text);
                  },
                  child: const Text("Next"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showProductSelectionDialog(String fromStore, String toStore) async {
    List<WarehouseProductModel> products = await _viewModel.fetchProducts(fromStore);
    if (products.isEmpty) return;

    String? selectedProduct;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text("Select Product from Store $fromStore"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: products
                      .map((product) => RadioListTile<String>(
                            title: Text(
                              "${product.name} (Stock: ${product.wareHouseStock})",
                              style: TextStyle(
                                color: product.wareHouseStock > 0 ? Colors.black : Colors.grey,
                              ),
                            ),
                            value: product.name,
                            groupValue: selectedProduct,
                            onChanged: product.wareHouseStock > 0
                                ? (value) {
                                    setState(() {selectedProduct = value;});
                                  }
                                : null,
                          ))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showStoreSelectionDialog();
                  },
                  child: Text("Back"),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
                ElevatedButton(
                  onPressed: selectedProduct != null
                      ? () {
                          final selectedProductDetails = products.firstWhere((product) => product.name == selectedProduct);
                          Navigator.of(context).pop();
                          _showQuantityDialog(
                            fromStore,
                            toStore,
                            selectedProduct!,
                            selectedProductDetails.wareHouseStock,
                            selectedProductDetails.toMap(),
                          );
                        }
                      : null,
                  child: Text("Next"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showQuantityDialog(
    String fromStore,
    String toStore,
    String product,
    int availableStock,
    Map<String, dynamic> productData,
  ) async {
    TextEditingController quantityController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text("Enter Quantity to Transfer"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("From Store: $fromStore"),
                  Text("To Store: $toStore"),
                  Text("Product: $product"),
                  Text("Available in Warehouse: $availableStock"),
                  SizedBox(height: 10),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(labelText: "Quantity"),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {setState(() {});},
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showProductSelectionDialog(fromStore, toStore);
                  },
                  child: Text("Back"),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    int? quantity = int.tryParse(quantityController.text);
                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please enter a valid quantity.")),
                      );
                    } else if (quantity > availableStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Entered quantity exceeds available stock.")),
                      );
                    } else {
                      Navigator.of(context).pop();
                      _confirmTransfer(fromStore, toStore, product, quantity, productData);
                    }
                  },
                  child: Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmTransfer(
    String fromStore,
    String toStore,
    String product,
    int quantity,
    Map<String, dynamic> productData,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Processing Transfer"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(), SizedBox(height: 16),
                Text("Transferring $quantity of $product..."),
              ],
            ),
          );
        },
      );

      await _viewModel.transferBetweenWarehouses(
        productName: product,
        fromStore: fromStore,
        toStore: toStore,
        quantity: quantity,
        productData: productData,
      );
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Success! $quantity of $product transferred from Store $fromStore to Store $toStore."),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error occurred during the transfer: ${e.toString()}")),
      );
    }
  }

  Future<void> _showTransferToWarehouseDialog(
    BuildContext context, DocumentSnapshot product) async {
    TextEditingController _transferController = TextEditingController();
    int currentShopStock = product['stockCurrent'];
    int currentWarehouseStock = product['wareHouseStock'];
    String errorMessage = '';
    String successMessage = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Transfer to Warehouse - ${product['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current Shop Stock: $currentShopStock'),
                  Text('Current Warehouse Stock: $currentWarehouseStock'),
                  SizedBox(height: 16),
                  TextField(
                    controller: _transferController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity to transfer',
                      hintText: 'Enter amount to transfer to warehouse',
                    ),
                  ),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (successMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        successMessage,
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    int transferAmount =
                        int.tryParse(_transferController.text) ?? 0;

                    if (transferAmount <= 0) {
                      setState(() {
                        errorMessage = 'Please enter a valid amount';
                        successMessage = '';
                      });
                      return;
                    }

                    if (transferAmount > currentShopStock) {
                      setState(() {
                        errorMessage =
                            'Cannot transfer more than available shop stock';
                        successMessage = '';
                      });
                      return;
                    }

                    try {
                      final user = _viewModel._auth.currentUser;
                      if (user == null) {
                        setState(() {
                          errorMessage = 'User not authenticated';
                          successMessage = '';
                        });
                        return;
                      }

                      final storeNumber =
                          await _viewModel.getCurrentUserStoreNumber();
                      if (storeNumber == null) {
                        setState(() {
                          errorMessage = 'Store number not set';
                          successMessage = '';
                        });
                        return;
                      }

                      await _viewModel.transferStockToWarehouse(
                        productId: product.id,
                        increment: transferAmount,
                        currentWareHouseStock: currentWarehouseStock,
                        currentShopStock: currentShopStock,
                      );

                      await _viewModel.createNotification(
                        message:
                            '$transferAmount of ${product['brand']} - ${product['name']} transferred from Shop to Warehouse',
                        productId: product.id,
                        storeNumber: storeNumber,
                        userId: user.uid,
                        notificationType: 'Transfer',
                      );

                      setState(() {
                        currentShopStock -= transferAmount;
                        currentWarehouseStock += transferAmount;
                        successMessage = 'Transfer successful!';
                        errorMessage = '';
                      });
                    } catch (e) {
                      setState(() {
                        errorMessage = 'Transfer failed: ${e.toString()}';
                        successMessage = '';
                      });
                    }
                  },
                  child: Text('Transfer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStockToWarehouse() {
    return FutureBuilder<String?>(
      future: _viewModel.getCurrentUserStoreNumber(),
      builder: (context, AsyncSnapshot<String?> storeSnapshot) {
        if (storeSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (storeSnapshot.data == null) {
          return Center(child: Text("Store number not set. Please configure it."));
        }

        return Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _viewModel._firestore
                    .collection('products')
                    .where('storeNumber', isEqualTo: storeSnapshot.data!)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> productSnapshot) {
                  if (productSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!productSnapshot.hasData || productSnapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No products found"));
                  }

                  // Filtrar localmente os produtos com stockCurrent > 0
                  var filteredProducts = productSnapshot.data!.docs
                      .where((product) => 
                          (product['stockCurrent'] as int) > 0 &&
                          product['name']
                              .toString()
                              .toLowerCase()
                              .contains(_searchText.toLowerCase()))
                      .toList();

                  if (filteredProducts.isEmpty) {
                    return Center(child: Text("No products with shop stock available"));
                  }

                  return ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      var product = filteredProducts[index];
                      return Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          child: Card(
                            margin: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            elevation: 4.0,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16.0),
                              title: Text(
                                product['name'],
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Brand: ${product['brand']}'),
                                  Text('Shop Stock: ${product['stockCurrent']}'),
                                  Text('Warehouse Stock: ${product['wareHouseStock']}'),
                                ],
                              ),
                              onTap: () async {
                                await _showTransferToWarehouseDialog(
                                    context, product);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("WareHouse Management", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, elevation: 0,
        flexibleSpace: Container(
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
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  "WareHouse to Shop",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Text("Shop to WareHouse", style: TextStyle(color: Colors.white)),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Text("Transfer Between Warehouses", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      body: Container(
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWarehouseForm(),
            _buildStockToWarehouse(),
            _buildTransferBetweenWarehouses(),
          ],
        ),
      ),
    );
  }
}