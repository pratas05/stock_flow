import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';

class DiscountsPage extends StatefulWidget {
  const DiscountsPage({super.key});

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _storeNumber;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

Future<void> _cleanupExpiredDiscounts() async {
  try {
    final now = Timestamp.now();
    final batch = _firestore.batch();

    final querySnapshot = await _firestore
        .collection('products')
        .where('storeNumber', isEqualTo: _storeNumber)
        .where('endDate', isLessThan: now)
        .get();

    for (var productDoc in querySnapshot.docs) {
      final data = productDoc.data();
      final discountPercent = data['discountPercent'];
      final vatCode = data['vatCode'];
      final basePrice = data['basePrice']?.toDouble() ?? 0.0;

      if (discountPercent != null && vatCode != null && basePrice > 0) {
        final vatRate = await _getVatRate(vatCode, _storeNumber!);
        final recalculatedVatPrice = basePrice * (1 + vatRate);

        batch.update(productDoc.reference, {
          'vatPrice': double.parse(recalculatedVatPrice.toStringAsFixed(2)),
          'startDate': FieldValue.delete(),
          'endDate': FieldValue.delete(),
          'discountPercent': FieldValue.delete(),
        });
      } else if (data.containsKey('startDate') || data.containsKey('endDate') || data.containsKey('discountPercent')) {
        // In case discount fields exist but cannot recalculate vatPrice
        batch.update(productDoc.reference, {
          'startDate': FieldValue.delete(),
          'endDate': FieldValue.delete(),
          'discountPercent': FieldValue.delete(),
        });
      }
    }

    if (querySnapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  } catch (e) {
    print('Error cleaning up expired discounts: $e');
  }
}

Future<double> _getVatRate(String vatCode, String storeNumber) async {
  try {
    final snapshot = await _firestore
        .collection('vatRates')
        .doc(storeNumber)
        .collection('rates')
        .doc(vatCode)
        .get();

    if (snapshot.exists) {
      return (snapshot.data()?['rate'] as num?)?.toDouble() ?? 0.0;
    }
  } catch (e) {
    print('Error fetching VAT rate: $e');
  }
  return 0.0;
}

  @override
  void initState() {
    super.initState();
    _loadStoreNumber();
    _searchController.addListener(_onSearchChanged);
    _cleanupExpiredDiscounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  Future<void> _loadStoreNumber() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _storeNumber = doc.data()?['storeNumber'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("CB2B93"),
              hexStringToColor("9546C4"),
              hexStringToColor("5E61F4"),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildSearchBar(),
                  Expanded(child: _buildDiscountsList()),
                ],
              ),
              _buildAddDiscountButton(),
            ],
          ),
        ),
      ),
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
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountsList() {
    if (_storeNumber == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: _storeNumber)
          .snapshots(),
      builder: (context, snapshot) {
        final now = Timestamp.now();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No discounted products available',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          );
        }

        final discountedProducts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final endDate = data['endDate'] as Timestamp?;
          final productName = data['name']?.toString().toLowerCase() ?? '';
          final hasActiveDiscount = endDate != null && endDate.compareTo(now) >= 0;
          final matchesSearch = _searchQuery.isEmpty || productName.contains(_searchQuery);
          return hasActiveDiscount && matchesSearch;
        }).toList();

        if (discountedProducts.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'No active discounts available'
                  : 'No results found for "$_searchQuery"',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: discountedProducts.length,
          itemBuilder: (context, index) {
            final product = discountedProducts[index];
            final data = product.data() as Map<String, dynamic>;
            final vatPrice = data['vatPrice']?.toDouble() ?? 0.0;
            final discountPercent = data['discountPercent'] ?? 0;
            final endDate = data['endDate'] as Timestamp;

            final originalPrice = vatPrice * 100 / (100 - discountPercent);

            return _buildProductCard(
              data['name'],
              data['model'],
              originalPrice,
              vatPrice,
              discountPercent,
              endDate,
              product.id,
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(
    String name,
    String model,
    double originalPrice,
    double discountedPrice,
    int discountPercent,
    Timestamp endDate,
    String productId,
  ) {
    final formattedEndDate = DateFormat('dd/MM/yyyy HH:mm').format(endDate.toDate());

    return Card(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.local_offer, color: Colors.deepPurple),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model: $model'),
            Text(
              'Original: €${originalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.red,
                decorationThickness: 2,
                color: Colors.redAccent,
              ),
            ),
            Text('Discount: $discountPercent%'),
            Text('Ends on: $formattedEndDate'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade900.withOpacity(0.6),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            '€${discountedPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDiscountButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ElevatedButton(
          onPressed: _showProductSearchPopup,
          child: const Text("Add Discount"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  void _showProductSearchPopup() {
    String popupSearchQuery = '';
    final TextEditingController popupSearchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Search Product'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: popupSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter product name',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setStateDialog(() => popupSearchQuery = value.trim()),
                    ),
                    const SizedBox(height: 16),
                    if (_storeNumber == null)
                      const CircularProgressIndicator()
                    else if (popupSearchQuery.isEmpty)
                      const SizedBox()
                    else
                      _buildProductSearchResults(popupSearchQuery),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductSearchResults(String query) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('products')
          .where('storeNumber', isEqualTo: _storeNumber)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nameMatch = data['name']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false;
          final hasNoDiscount = !data.containsKey('endDate') || (data['endDate'] as Timestamp).compareTo(Timestamp.now()) < 0;
          return nameMatch && hasNoDiscount;
        }).toList();

        if (products.isEmpty) return const Text("No available products found.");

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final data = product.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name']),
                subtitle: Text("Model: ${data['model']}"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDiscountInputPopup(product);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showDiscountInputPopup(QueryDocumentSnapshot product) {
    final discountController = TextEditingController();
    final durationController = TextEditingController();
    String selectedUnit = 'Hours';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Discount for ${product['name']}"),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Discount %',
                        hintText: 'Enter discount percentage (1-99)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        hintText: 'Enter duration amount',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedUnit,
                      items: const [
                        DropdownMenuItem(value: 'Hours', child: Text('Hours')),
                        DropdownMenuItem(value: 'Days', child: Text('Days')),
                      ],
                      onChanged: (value) => setStateDialog(() => selectedUnit = value!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _confirmDiscount(
                    product,
                    discountController.text,
                    durationController.text,
                    selectedUnit,
                    context,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDiscount(
    QueryDocumentSnapshot product,
    String discountText,
    String durationText,
    String selectedUnit,
    BuildContext context,
  ) async {
    final discountPercent = int.tryParse(discountText);
    final durationAmount = int.tryParse(durationText);
    final user = _auth.currentUser;

    if (discountPercent == null || discountPercent < 1 || discountPercent > 99) {
      CustomSnackbar.show(context: context, message: 'Please enter a valid discount percentage (1-99)', backgroundColor: Colors.red);
      return;
    }

    if (durationAmount == null || durationAmount <= 0) {
      CustomSnackbar.show(context: context, message: 'Please enter a valid duration amount', backgroundColor: Colors.red);
      return;
    }

    if (_storeNumber == null) {
      CustomSnackbar.show(context: context, message: 'Store number not found. Please log in again.', backgroundColor: Colors.red);
      return;
    }

    final double originalVatPrice = (product['vatPrice'] ?? 0).toDouble();
    if (originalVatPrice <= 0) {
      CustomSnackbar.show(context: context, message: 'Invalid product price. Cannot apply discount.', backgroundColor: Colors.red);
      return;
    }

    try {
      final startDate = Timestamp.now();
      final endDateTime = selectedUnit == 'Hours'
          ? startDate.toDate().add(Duration(hours: durationAmount))
          : startDate.toDate().add(Duration(days: durationAmount));
      final endDate = Timestamp.fromDate(endDateTime.toUtc());

      final discountedPrice = double.parse((originalVatPrice * (100 - discountPercent) / 100).toStringAsFixed(2));

      await _firestore.collection('products').doc(product.id).update({
        'vatPrice': discountedPrice,
        'startDate': startDate,
        'endDate': endDate,
        'discountPercent': discountPercent,
      });

      final notificationMessage =
          'New discount: ${product['name']} - $discountPercent% OFF (€${originalVatPrice.toStringAsFixed(2)} → €${discountedPrice.toStringAsFixed(2)}), until ${DateFormat('dd/MM/yyyy HH:mm').format(endDate.toDate())}';

      final notificationRef = await _firestore.collection('notifications').add({
        'message': notificationMessage,
        'notificationId': '',
        'notificationType': 'Discount',
        'productId': product.id,
        'storeNumber': _storeNumber,
        'timestamp': Timestamp.now(),
        'userId': user?.uid,
      });

      await notificationRef.update({'notificationId': notificationRef.id});

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context: context, message: 'Discount created until ${DateFormat('dd/MM/yyyy HH:mm').format(endDate.toDate())}', backgroundColor: Colors.green);
      }
    } catch (e) {
      debugPrint('Error creating discount: $e');
      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context: context, message: 'Error creating discount: ${e.toString()}', backgroundColor: Colors.red);
      }
    }
  }
}
