import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/screens_main/discounts_page.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';
import 'package:stockflow/reusable_widgets/search_controller.dart';
import 'package:stockflow/reusable_widgets/vat_manager.dart';

// [1. MODEL]
class Product {
  final String id, name, model, storeNumber;
  final double basePrice, vatPrice;
  final int stockCurrent, wareHouseStock, stockBreak;

  Product({
    required this.id,
    required this.name,
    required this.model,
    required this.basePrice,
    required this.vatPrice,
    required this.stockCurrent,
    required this.wareHouseStock,
    required this.stockBreak,
    required this.storeNumber,
  });

  factory Product.fromDocument(DocumentSnapshot doc) => Product(
    id: doc.id,
    name: doc['name'] ?? '',
    model: doc['model'] ?? '',
    basePrice: (doc['basePrice'] ?? 0.0).toDouble(),
    stockCurrent: (doc['stockCurrent'] ?? 0).toInt(),
    wareHouseStock: (doc['wareHouseStock'] ?? 0).toInt(),
    stockBreak: (doc['stockBreak'] ?? 0).toInt(),
    storeNumber: doc['storeNumber'] ?? '',
    vatPrice: (doc['vatPrice'] ?? 0.0).toDouble(),
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.vatPrice * quantity;
}

// [2. VIEWMODEL]
class BuyTradeViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => _cartItems;

  void addToCart(Product product) {
  final existingItem = _cartItems.firstWhere(
    (item) => item.product.id == product.id,
    orElse: () => CartItem(product: Product(id: '', name: '', model: '', basePrice: 0, vatPrice: 0, stockCurrent: 0, wareHouseStock: 0, stockBreak: 0, storeNumber: '')),
  );

  if (existingItem.product.id.isNotEmpty) {
    // Only increment if we haven't reached the available stock
    if (existingItem.quantity < product.stockCurrent + existingItem.quantity) {
      existingItem.quantity++;
    }
  } else {
    // Only add to cart if there's at least 1 in stock
    if (product.stockCurrent > 0) {
      _cartItems.add(CartItem(product: product));
    }
  }
}

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
  }

  void updateQuantity(String productId, int newQuantity) {
    final item = _cartItems.firstWhere((item) => item.product.id == productId);
    if (newQuantity > 0) {
      item.quantity = newQuantity;
    } else {
      removeFromCart(productId);
    }
  }

  void clearCart() {
    _cartItems.clear();
  }

  double get cartTotal => _cartItems.fold(
    0,
    (total, item) => total + (item.product.vatPrice * item.quantity),
  );

  Future<bool> hasFullAdminAccess() async {
    try {
      final userData = await getUserData();
      if (userData == null) return false;
      
      return (userData['isStoreManager'] as bool? ?? false) && (userData['adminPermission'] == userData['storeNumber']);
    } catch (e) {
      debugPrint("Error checking admin access: $e"); return false;
    }
  }

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

  Future<void> buyProductsInCart() async {
    final batch = _firestore.batch();
    
    for (final item in _cartItems) {
      final productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {
        'stockCurrent': FieldValue.increment(-item.quantity),
      });
    }
    
    await batch.commit();
    clearCart();
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
    final breakageType = isWarehouse ? 'wareHouseStock' : 'stockCurrent';
    final breakageDocId = '${productId}_$breakageType';

    final batch = _firestore.batch();

    // Update the product stock
    final updates = <String, dynamic>{
      'stockBreak': FieldValue.increment(quantity),
    };
    if (isWarehouse) {
      updates['wareHouseStock'] = warehouseStock - quantity;
    } else {
      updates['stockCurrent'] = shopStock - quantity;
    }
    batch.update(_firestore.collection('products').doc(productId), updates);

    // Check if a breakage document already exists
    final breakageDocRef = _firestore.collection('breakages').doc(breakageDocId);
    final breakageDoc = await breakageDocRef.get();

    if (breakageDoc.exists) {
      // If the document exists, merge and sum the breakageQty
      final existingData = breakageDoc.data() as Map<String, dynamic>;
      final existingQty = existingData['breakageQty'] ?? 0;

      batch.update(breakageDocRef, {
        'breakageQty': existingQty + quantity, // Sum quantities
      });
    } else {
      // If the document does not exist, create a new one
      batch.set(breakageDocRef, {
        'productId': productId,
        'productName': productName,
        'breakageQty': quantity,
        'breakageType': breakageType,
        'storeNumber': storeNumber,
      });
    }

    // Add a notification for the breakage
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'message': '$quantity "$productName" ${quantity > 1 ? 'were' : 'was'} sent from ${isWarehouse ? 'warehouse' : 'shop'} for Break, which means it is damaged',
      'notificationId': notificationRef.id,
      'notificationType': 'Break',
      'productId': productId,
      'storeNumber': storeNumber,
      'userId': _auth.currentUser?.uid ?? '',
      'quantity': quantity,
      'location': isWarehouse ? 'warehouse' : 'shop',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Commit the batch
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
  final VatMonitorService _vatMonitor = VatMonitorService();
  bool _hasFullPermission = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BuyTradeViewModel();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _viewModel.getUserData();
      if (userData != null) {
        setState(() {
          storeNumber = userData['storeNumber'];
          _isStoreManager = userData['isStoreManager'] ?? false;
        });
        
        final hasPermission = await _viewModel.hasFullAdminAccess();
        setState(() {
          _hasFullPermission = hasPermission;
        });
      }

      if (storeNumber != null && storeNumber!.isNotEmpty) {
        _vatMonitor.startMonitoring(storeNumber!);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error fetching user data: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _vatMonitor.stopMonitoring();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {return _buildLoadingScreen();}
    if (!_isStoreManager) {return _buildNoPermissionsScreen();}
    if (!_hasFullPermission) {return _buildNoPermissionsScreen();}

    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBuyTab(),
            _buildTradeTab(),
            const DiscountsPage(),
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

    if (!_isStoreManager || !_hasFullPermission) {
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
          Tab(text: "Discounts"),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: SearchControllerPage(
                  initialText: searchQuery,
                  onSearchChanged: (value) => setState(() => searchQuery = value),
                  hintText: "Search Product",
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _viewModel.cartItems.isNotEmpty
                    ? Container(
                        key: const ValueKey('cart-button'),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Badge(
                            label: Text(_viewModel.cartItems.length.toString()),
                            child: const Icon(Icons.shopping_cart, color: Colors.white),
                          ),
                          onPressed: () => _showCartDialog(),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty-cart')),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildProductList(
            itemBuilder: (context, product) {
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .doc(product.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(
                      title: Text("${product.name} - ${product.model}"),
                      subtitle: const Text("Loading..."),
                    );
                  }

                  final productData = snapshot.data!.data() as Map<String, dynamic>;
                  final vatPrice = productData['vatPrice']?.toDouble() ?? product.vatPrice;
                  double priceToShow = vatPrice;
                  bool hasDiscount = false;
                  Timestamp? endDate;
                  int? discountPercent;

                  // Check for active discount
                  if (productData.containsKey('vatPrice') && 
                      productData['vatPrice'] != null &&
                      productData.containsKey('endDate') &&
                      productData['endDate'] != null) {
                    endDate = productData['endDate'] as Timestamp;
                    final now = Timestamp.now();

                    if (endDate.toDate().isAfter(now.toDate())) {
                      hasDiscount = true;
                      priceToShow = (productData['vatPrice'] as num).toDouble();
                      discountPercent = productData['discountPercent'] as int?;
                    }
                  }

                  final isInCart = _viewModel.cartItems.any((item) => item.product.id == product.id);
                  return ListTile(
                    title: Text(
                      "${product.name} - ${product.model}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: isInCart ? Colors.blue : Colors.black87),
                    ),
                    tileColor: isInCart ? Colors.blue.withOpacity(0.1) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isInCart ? Colors.blue : Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    subtitle: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount) ...[
                          Text(
                            "Price: ",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          Text(
                            // make the inverse operation to get the original price
                            "€${(vatPrice / (1 - (discountPercent! / 100))).toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "€${priceToShow.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Promotion ends ${DateFormat('dd/MM HH:mm').format(endDate!.toDate())}',
                            child: const Icon(Icons.timer, size: 16, color: Colors.red),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "| Stock: ${product.stockCurrent}",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ] else ...[
                          Text(
                            "Price: €${priceToShow.toStringAsFixed(2)} | Stock: ${product.stockCurrent}",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isInCart) ...[
                          const Icon(Icons.check, color: Colors.green),
                          Text(
                            "(${_viewModel.cartItems.firstWhere((item) => item.product.id == product.id).quantity})",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ] else if (product.stockCurrent > 0)
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart),
                            onPressed: () {
                              _viewModel.addToCart(product);
                              setState(() {});
                            },
                            color: Colors.green,
                          ),
                      ],
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
          return Center(child: Text("No products found.", style: TextStyle(color: Colors.white)));
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

  void _resetCartVisuals() {
    _viewModel.clearCart(); // Limpa o carrinho no ViewModel
    
    // Força a reconstrução da tela para remover os visuais do carrinho
    if (mounted) {
      setState(() {
        // Esta reconstrução irá:
        // 1. Remover o badge do ícone do carrinho
        // 2. Remover os highlights dos produtos no carrinho
        // 3. Remover os ícones de checkmark e quantidades
      });
    }
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text("Your Cart"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_viewModel.cartItems.isEmpty)
                      const Text("Your cart is empty")
                    else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _viewModel.cartItems.length,
                          itemBuilder: (context, index) {
                            final item = _viewModel.cartItems[index];
                            final maxQuantity = item.product.stockCurrent;
                            
                            return ListTile(
                              title: Text("${item.product.name} - ${item.product.model}"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "€${item.product.vatPrice.toStringAsFixed(2)} x ${item.quantity} = "
                                    "€${(item.product.vatPrice * item.quantity).toStringAsFixed(2)}",
                                  ),
                                  Text(
                                    "Available: ${maxQuantity - item.quantity}",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      setState(() {
                                        if (item.quantity > 1) {
                                          item.quantity--;
                                        } else {
                                          _viewModel.removeFromCart(item.product.id);
                                          if (_viewModel.cartItems.isEmpty) {
                                            Navigator.pop(dialogContext);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  Text(item.quantity.toString()),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: maxQuantity > item.quantity
                                        ? () {
                                            setState(() {
                                              item.quantity++;
                                            });
                                          }
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        _viewModel.removeFromCart(item.product.id);
                                        if (_viewModel.cartItems.isEmpty) {
                                          Navigator.pop(dialogContext);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Text(
                        "Total: €${_viewModel.cartTotal.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Continue Shopping"),
                ),
                if (_viewModel.cartItems.isNotEmpty) ...[
                  TextButton(
                    onPressed: () {
                      _viewModel.clearCart();
                      Navigator.pop(context);
                      if (mounted) setState(() {});
                    },
                    child: const Text("Clear Cart"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // First validate all quantities
                      bool allValid = true;
                      for (final item in _viewModel.cartItems) {
                        if (item.quantity > item.product.stockCurrent) {
                          allValid = false;
                          CustomSnackbar.show(
                            context: context,
                            message: "Not enough stock for ${item.product.name}. Available: ${item.product.stockCurrent}",
                            backgroundColor: Colors.red
                          );
                          break;
                        }
                      }
                      if (!allValid) return;
                      
                      // Calculate total quantity
                      final totalQuantity = _viewModel.cartItems.fold(0, (sum, item) => sum + item.quantity);

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Confirm Purchase"),
                          content: Text(
                            "Are you sure you want to purchase $totalQuantity items for "
                            "€${_viewModel.cartTotal.toStringAsFixed(2)}?",
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Confirm"),
                            ),
                          ],
                        ),
                      );

                        // Close the cart dialog only after confirmation
                        if (confirmed == true) {
                        Navigator.pop(dialogContext); // Fecha o popup

                        try {
                          await _viewModel.buyProductsInCart();

                          if (mounted) {
                            _resetCartVisuals();
                            CustomSnackbar.show(
                              context: context,
                              message: "Purchase completed successfully!", backgroundColor: Colors.green,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            CustomSnackbar.show(
                              context: context,
                              message: "Error during purchase: $e", backgroundColor: Colors.red,
                            );
                        }
                        }
                      }
                    },
                    child: const Text("Check Out"),
                  ),
                ],
              ],
            );
          },
        );
      },
    ).then((_) {if (mounted) setState(() {});});
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
                  Text("Select the quantity to break for ${product.name}"),
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
                      CustomSnackbar.show(
                        context: context, 
                        message:  "Product break recorded successfully!", backgroundColor: Colors.green,
                      );
                    } catch (e) {
                      CustomSnackbar.show(
                        context: context, 
                        message: "Error recording product break: $e", backgroundColor: Colors.red,
                      );
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
                .where((product) => product.id != selectedProduct.id)
                .toList();

            if (allProducts.isEmpty) {
              return AlertDialog(
                title: const Text("No Products"),
                content: const Text("No other products available in this store."),
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
                                enabled: product.stockCurrent > 0,
                                tileColor: product.stockCurrent > 0 ? null : Colors.grey[200],
                                onTap: product.stockCurrent > 0
                                    ? () {
                                        Navigator.of(dialogContext).pop();
                                        _confirmTrade(
                                          selectedProduct: selectedProduct,
                                          tradeProduct: product,
                                          scaffoldContext: scaffoldContext,
                                        );
                                      }
                                    : null,
                              )),
                        ] else if (searchController.text.isNotEmpty) ...[
                          const Text("No results found."),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text("Cancel"),
                    ),
                  ],
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
                CustomSnackbar.show(
                  context: context, 
                  message: "Trade completed successfully!", backgroundColor: Colors.green,
                );
              } catch (e) {
                CustomSnackbar.show(
                  context: context, 
                  message: "Error during trade: $e", backgroundColor: Colors.red,
                );
              }
            }, 
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}