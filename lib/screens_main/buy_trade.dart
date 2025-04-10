import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

// [1. MODEL]
class Product {
  final String id, name, model, storeNumber;
  final double salePrice;
  final int stockCurrent, wareHouseStock, stockBreak;

  Product({
    required this.id,
    required this.name,
    required this.model,
    required this.salePrice,
    required this.stockCurrent,
    required this.wareHouseStock,
    required this.stockBreak,
    required this.storeNumber,
  });

  factory Product.fromDocument(DocumentSnapshot doc) => Product(
    id: doc.id,
    name: doc['name'] ?? '',
    model: doc['model'] ?? '',
    salePrice: (doc['salePrice'] ?? 0.0).toDouble(),
    stockCurrent: (doc['stockCurrent'] ?? 0).toInt(),
    wareHouseStock: (doc['wareHouseStock'] ?? 0).toInt(),
    stockBreak: (doc['stockBreak'] ?? 0).toInt(),
    storeNumber: doc['storeNumber'] ?? '',
  );
}

// [2. VIEWMODEL]
class BuyTradeViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getStoreNumber() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['storeNumber'];
  }

  Stream<QuerySnapshot> getProductsStream(String? storeNumber) {
    if (storeNumber == null) return const Stream.empty();
    return _firestore
        .collection('products')
        .where('storeNumber', isEqualTo: storeNumber)
        .snapshots();
  }

  Future<void> buyProduct(String productId, int currentStock) async {
    await _firestore.collection('products').doc(productId).update({
      'stockCurrent': currentStock - 1,
    });
  }

  Future<void> processBreak(
    String productId, {
    required bool isWarehouse,
    required int quantity,
    required int warehouseStock,
    required int shopStock,
    required String productName,
    required String storeNumber,
  }) async {
    final updates = <String, dynamic>{
      'stockBreak': FieldValue.increment(quantity),
    };
    if (isWarehouse) {
      updates['wareHouseStock'] = warehouseStock - quantity;
    } else {
      updates['stockCurrent'] = shopStock - quantity;
    }
    
    // Create a batch to perform both updates atomically
    final batch = _firestore.batch();
    
    // Update the product
    batch.update(_firestore.collection('products').doc(productId), updates);
    
    // Create the notification
    final notificationRef = _firestore.collection('notifications').doc();
    final location = isWarehouse ? 'warehouse' : 'shop';
    final singularPlural = quantity > 1 ? 'were' : 'was';
    
    batch.set(notificationRef, {
      'message': '$quantity "$productName" $singularPlural sent from $location for Break, which means they are damaged',
      'notificationId': notificationRef.id,
      'notificationType': 'Break',
      'productId': productId,
      'storeNumber': storeNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _auth.currentUser?.uid ?? '',
      'quantity': quantity,
      'location': location,
    });
    
    await batch.commit();
  }

  Future<void> processTrade({
    required String returnedProductId,
    required int returnedWarehouseStock,
    required String tradedProductId,
    required int tradedShopStock,
  }) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('products').doc(returnedProductId), {
      'wareHouseStock': returnedWarehouseStock + 1,
    });
    batch.update(_firestore.collection('products').doc(tradedProductId), {
      'stockCurrent': tradedShopStock - 1,
    });
    await batch.commit();
  }
}

// [3. VIEW]
class BuyTradePage extends StatefulWidget {
  @override
  _BuyTradePageState createState() => _BuyTradePageState();
}

class _BuyTradePageState extends State<BuyTradePage> with SingleTickerProviderStateMixin {
  late final BuyTradeViewModel _viewModel;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String? storeNumber;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _viewModel = BuyTradeViewModel();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      storeNumber = await _viewModel.getStoreNumber();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching store number: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSafeSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Buy and Trade", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: "Buy"),
            Tab(text: "Trade"),
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
            _buildBuyTab(),
            _buildTradeTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyTab() {
    if (storeNumber == null) {
      return Center(
        child: Text(
          "You are not connected to any Store. Please contact your Admin",
          style: TextStyle(fontSize: 18, color: Colors.white), textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  hexStringToColor("CB2B93"),
                  hexStringToColor("9546C4"),
                  hexStringToColor("5E61F4"),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Product",
                labelStyle: TextStyle(color: const Color.fromARGB(179, 53, 51, 51)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                prefixIcon: Icon(Icons.search, color: const Color.fromARGB(255, 43, 41, 41)),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: TextStyle(color: const Color.fromARGB(255, 73, 71, 71)),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _viewModel.getProductsStream(storeNumber),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final filteredDocs = snapshot.data!.docs.where((doc) {
                final name = (doc['name'] as String).toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              if (filteredDocs.isEmpty) return Center(child: Text("No products found.", style: TextStyle(color: Colors.white)));

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final product = Product.fromDocument(filteredDocs[index]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(
                          "${product.name} - ${product.model}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        subtitle: Text(
                          "Price: \$${product.salePrice.toStringAsFixed(2)} | Stock: ${product.stockCurrent}",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.add_shopping_cart, 
                              color: product.stockCurrent > 0 ? Colors.green : Colors.grey),
                          onPressed: product.stockCurrent > 0
                              ? () => _showBuyConfirmationDialog(product.id, product.stockCurrent)
                              : null,
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
  }

  Widget _buildTradeTab() {
    if (storeNumber == null) {
      return Center(
        child: Text(
          "You are not connected to any Store. Please contact your Admin",
          style: TextStyle(fontSize: 18, color: Colors.white), textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  hexStringToColor("CB2B93"),
                  hexStringToColor("9546C4"),
                  hexStringToColor("5E61F4"),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Product",
                labelStyle: TextStyle(color: const Color.fromARGB(179, 53, 51, 51)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color.fromARGB(255, 97, 97, 97)),
                ),
                prefixIcon: Icon(Icons.search, color: const Color.fromARGB(255, 43, 41, 41)),
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: TextStyle(color: const Color.fromARGB(255, 73, 71, 71)),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _viewModel.getProductsStream(storeNumber),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final filteredDocs = snapshot.data!.docs.where((doc) {
                final name = (doc['name'] as String).toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              if (filteredDocs.isEmpty) return Center(child: Text("No products found.", style: TextStyle(color: Colors.white)));

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final product = Product.fromDocument(filteredDocs[index]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(
                          "${product.name} - ${product.model}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        subtitle: Text(
                          "Stock: ${product.stockCurrent} | WareHouseStock: ${product.wareHouseStock}",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        trailing: Icon(Icons.swap_horiz, color: Colors.blue),
                        onTap: () => _showTradeOptions(product),
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
  }

  Future<void> _showBuyConfirmationDialog(String productId, int stockCurrent) async {
    if (!mounted) return;
    final scaffoldContext = context;

    final confirmed = await showDialog<bool>(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Confirm Purchase"),
        content: Text("Are you sure you want to purchase this product?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text("Buy", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _viewModel.buyProduct(productId, stockCurrent);
      _showSafeSnackBar("Product purchased successfully!");
    } catch (e) {
      _showSafeSnackBar("Error purchasing product: $e");
    }
  }

  void _showTradeOptions(Product product) {
    if (!mounted) return;
    final scaffoldContext = context;

    if (product.wareHouseStock == 0 && product.stockCurrent == 0) {
      _showSafeSnackBar("This product has no stock in warehouse or shop.");
      return;
    }

    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Trade Options"),
        content: Text("Select an action for ${product.name} - ${product.model}."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showProductSelection(product, scaffoldContext);
            },
            child: Text("Trade"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _askStockTypeForBreak(product, scaffoldContext);
            },
            child: Text("Break"),
          ),
        ],
      ),
    );
  }

  void _askStockTypeForBreak(Product product, BuildContext scaffoldContext) {
    if (!mounted) return;
    int quantity = 1;
    bool isWarehouse = product.wareHouseStock > 0;

    if (product.wareHouseStock == 0 && product.stockCurrent == 0) {
      _showSafeSnackBar("This product has no stock in warehouse or shop.");
      return;
    }

    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setState) {
            return AlertDialog(
              title: Text("Break Product"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Where was the product located?"),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: product.wareHouseStock <= 0
                            ? null
                            : () => setState(() => isWarehouse = true),
                        child: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWarehouse && product.wareHouseStock > 0 
                                ? Colors.blue 
                                : Colors.grey[300],
                            border: Border.all(
                              color: isWarehouse && product.wareHouseStock > 0 
                                  ? Colors.blue 
                                  : Colors.grey, width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "W",
                              style: TextStyle(
                                color: isWarehouse && product.wareHouseStock > 0 
                                    ? Colors.white 
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: product.stockCurrent <= 0
                            ? null
                            : () => setState(() => isWarehouse = false),
                        child: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: !isWarehouse && product.stockCurrent > 0 
                                ? Colors.blue 
                                : Colors.grey[300],
                            border: Border.all(
                              color: !isWarehouse && product.stockCurrent > 0 
                                  ? Colors.blue 
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "S",
                              style: TextStyle(
                                color: !isWarehouse && product.stockCurrent > 0 
                                    ? Colors.white 
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("Select the quantity to break for ${product.name} - ${product.model}."),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: quantity > 1 
                            ? () => setState(() => quantity--)
                            : null,
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          if (isWarehouse && quantity < product.wareHouseStock) {
                            setState(() => quantity++);
                          } else if (!isWarehouse && quantity < product.stockCurrent) {
                            setState(() => quantity++);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    try {
                      await _viewModel.processBreak(
                        product.id,
                        isWarehouse: isWarehouse,
                        quantity: quantity,
                        warehouseStock: product.wareHouseStock,
                        shopStock: product.stockCurrent,
                        productName: product.name,
                        storeNumber: product.storeNumber,
                      );
                      _showSafeSnackBar("Product break recorded successfully!");
                    } catch (e) {
                      _showSafeSnackBar("Error recording product break: $e");
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

  void _showProductSelection(Product selectedProduct, BuildContext scaffoldContext) {
    if (!mounted) return;
    
    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Select Product for Trade"),
        content: StreamBuilder<QuerySnapshot>(
          stream: _viewModel.getProductsStream(storeNumber),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
            final products = snapshot.data!.docs
                .map((doc) => Product.fromDocument(doc))
                .where((product) => product.stockCurrent > 0 && product.id != selectedProduct.id)
                .toList();
            if (products.isEmpty) return Text("No products available for trade.");
            return Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    title: Text("${product.name} - ${product.model}"),
                    subtitle: Text("Stock in the shop: ${product.stockCurrent}"),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _confirmTrade(
                        selectedProduct: selectedProduct,
                        tradeProduct: product,
                        scaffoldContext: scaffoldContext,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmTrade({
    required Product selectedProduct,
    required Product tradeProduct,
    required BuildContext scaffoldContext,
  }) {
    if (!mounted) return;
    
    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Confirm Trade"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("You are about to trade the following:"),
            SizedBox(height: 10),
            Text("Product to Increase Warehouse Stock:"),
            Text("${selectedProduct.name} - ${selectedProduct.model}", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Warehouse Stock: ${selectedProduct.wareHouseStock}"),
            SizedBox(height: 10),
            Divider(),
            Text("Product to Decrease Stock from the shop:"),
            Text("${tradeProduct.name} - ${tradeProduct.model}", 
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Stock in the shop: ${tradeProduct.stockCurrent}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await _viewModel.processTrade(
                  returnedProductId: selectedProduct.id,
                  returnedWarehouseStock: selectedProduct.wareHouseStock,
                  tradedProductId: tradeProduct.id,
                  tradedShopStock: tradeProduct.stockCurrent,
                );
                _showSafeSnackBar("Trade completed successfully!");
              } catch (e) {
                _showSafeSnackBar("Error during trade: $e");
              }
            }, child: Text("Confirm"),
          ),
        ],
      ),
    );
  }
}