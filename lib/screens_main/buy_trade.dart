import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';
import 'package:stockflow/reusable_widgets/search_controller.dart';

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

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
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
    
    final batch = _firestore.batch();
    batch.update(_firestore.collection('products').doc(productId), updates);
    
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'message': '$quantity "$productName" ${quantity > 1 ? 'were' : 'was'} sent from ${isWarehouse ? 'warehouse' : 'shop'} for Break, which means it is damaged',
      'notificationId': notificationRef.id,
      'notificationType': 'Break',
      'productId': productId,
      'storeNumber': storeNumber,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _auth.currentUser?.uid ?? '',
      'quantity': quantity,
      'location': isWarehouse ? 'warehouse' : 'shop',
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
  String searchQuery = "";
  String? storeNumber;
  bool _isLoading = true;
  bool _isStoreManager = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BuyTradeViewModel();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final userData = await _viewModel.getUserData();
      if (userData != null) {
        setState(() {
          storeNumber = userData['storeNumber'];
          _isStoreManager = userData['isStoreManager'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching user data: $e")),
        );
      }
    } finally {if (mounted) setState(() => _isLoading = false);}
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    if (_isLoading) {return _buildLoadingScreen();}
    if (!_isStoreManager) {return _buildNoPermissionsScreen();}

    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
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
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildNoPermissionsScreen() {
    if (storeNumber == null || storeNumber!.isEmpty) {
      return const ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Store Access Required",
        message: "Your account is not associated with any store. Please contact admin.",
      );
    }

    if (!_isStoreManager) {
      return const ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Access Denied",
        message: "You don't have permissions to access this page.",
      );
    }

    return const ErrorScreen(
      icon: Icons.error,
      title: "Unknown Error",
      message: "An unexpected error occurred. Please try again.",
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Buy and Trade", style: TextStyle(color: Colors.white)),
      centerTitle: true,
      backgroundColor: Colors.transparent, elevation: 0,
      flexibleSpace: Container(decoration: _buildBackgroundDecoration()),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: "Buy"),
          Tab(text: "Trade"),
        ],
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          hexStringToColor("CB2B93"),
          hexStringToColor("9546C4"),
          hexStringToColor("5E61F4"),
        ],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    );
  }

  Widget _buildBuyTab() {
    return Column(
      children: [
        SearchControllerPage(
          initialText: searchQuery,
          onSearchChanged: (value) => setState(() => searchQuery = value),
          hintText: "Search Product",
        ),
        Expanded(
          child: _buildProductList(
            itemBuilder: (context, product) => ListTile(
              title: Text(
                "${product.name} - ${product.model}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
        ),
      ],
    );
  }

  Widget _buildTradeTab() {
    return Column(
      children: [
        SearchControllerPage(
          initialText: searchQuery,
          onSearchChanged: (value) => setState(() => searchQuery = value),
          hintText: "Search Product",
        ),
        Expanded(
          child: _buildProductList(
            itemBuilder: (context, product) => ListTile(
              title: Text(
                "${product.name} - ${product.model}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              subtitle: Text(
                "Stock: ${product.stockCurrent} | WareHouseStock: ${product.wareHouseStock}",
                style: TextStyle(color: Colors.grey[700]),
              ),
              trailing: Icon(
                Icons.swap_horiz,
                color: (product.stockCurrent > 0 || product.wareHouseStock > 0) 
                    ? Colors.blue 
                    : Colors.grey,
              ),
              onTap: (product.stockCurrent > 0 || product.wareHouseStock > 0)
                  ? () => _showTradeOptions(product)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductList({required Widget Function(BuildContext, Product) itemBuilder}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _viewModel.getProductsStream(storeNumber),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final name = (doc['name'] as String).toLowerCase();
          return name.contains(searchQuery.toLowerCase());
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text("No products found.", style: TextStyle(color: Colors.white)),
          );
        }

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
                child: itemBuilder(context, product),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBuyConfirmationDialog(String productId, int stockCurrent) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm Purchase"),
        content: const Text("Are you sure you want to purchase this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Buy", style: TextStyle(fontWeight: FontWeight.bold)),
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Trade Options"),
        content: Text("Select an action for ${product.name} - ${product.model}."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {Navigator.of(dialogContext).pop(); _showProductSelection(product, context);},
            child: const Text("Trade"),
          ),
          ElevatedButton(
            onPressed: () {Navigator.of(dialogContext).pop(); _askStockTypeForBreak(product, context);},
            child: const Text("Break"),
          ),
        ],
      ),
    );
  }

  void _askStockTypeForBreak(Product product, BuildContext scaffoldContext) {
    if (!mounted) return;
    int quantity = 1;
    bool isWarehouse = product.wareHouseStock > 0;

    showDialog(
      context: scaffoldContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setState) {
            return AlertDialog(
              title: const Text("Break Product"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Where was the product located?"),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 20),
                  Text("Select the quantity to break for ${product.name} - ${product.model}."),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: quantity > 1 
                            ? () => setState(() => quantity--)
                            : null,
                      ),
                      Text('$quantity'),
                      IconButton(
                        icon: const Icon(Icons.add),
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
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel")),
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
                  }, child: const Text("Confirm"),
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
      builder: (dialogContext) {
        return StreamBuilder<QuerySnapshot>(
          stream: _viewModel.getProductsStream(storeNumber),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                title: Text("Loading..."),
                content: Center(child: CircularProgressIndicator()),
              );
            }

            final allProducts = snapshot.data!.docs
                .map((doc) => Product.fromDocument(doc))
                .where((product) => product.stockCurrent > 0 && product.id != selectedProduct.id)
                .toList();

            if (allProducts.isEmpty) {
              return AlertDialog(
                title: const Text("No Products"),
                content: const Text("No products available for trade."),
                actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("OK"))],
              );
            }

            final searchController = TextEditingController();
            List<Product> filteredProducts = [];

            return StatefulBuilder(
              builder: (context, setState) {
                void _filterProducts(String query) {
                  setState(() {
                    if (query.trim().isEmpty) {
                      filteredProducts = [];
                    } else {
                      final searchLower = query.toLowerCase();
                      filteredProducts = allProducts.where((product) {
                        final nameLower = product.name.toLowerCase();
                        final modelLower = product.model.toLowerCase();
                        return nameLower.contains(searchLower) || modelLower.contains(searchLower);
                      }).toList();
                    }
                  });
                }

                return AlertDialog(
                  title: const Text("Select Product for Trade"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: "Search products",
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: _filterProducts,
                        ),
                        const SizedBox(height: 16),
                        if (filteredProducts.isNotEmpty) ...[
                          const Text("Search results:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...filteredProducts.map((product) => ListTile(
                                title: Text("${product.name} - ${product.model}"),
                                subtitle: Text("Shop stock: ${product.stockCurrent}"),
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  _confirmTrade(
                                    selectedProduct: selectedProduct,
                                    tradeProduct: product,
                                    scaffoldContext: scaffoldContext,
                                  );
                                },
                              )),
                        ] else if (searchController.text.isNotEmpty) ...[const Text("No results found.")],
                      ],
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel"))],
                );
              },
            );
          },
        );
      },
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
        title: const Text("Confirm Trade"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("You are about to trade the following:"),
            const SizedBox(height: 10),
            const Text("Product to Increase Warehouse Stock:"),
            Text("${selectedProduct.name} - ${selectedProduct.model}", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Warehouse Stock: ${selectedProduct.wareHouseStock}"),
            const SizedBox(height: 10),
            const Divider(),
            const Text("Product to Decrease Stock from the shop:"),
            Text("${tradeProduct.name} - ${tradeProduct.model}", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Stock in the shop: ${tradeProduct.stockCurrent}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel")),
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
              } catch (e) {_showSafeSnackBar("Error during trade: $e");}
            }, 
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}