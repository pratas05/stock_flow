//MVVM
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

// [1. MODEL]
class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String model;
  final String category;
  final String storeNumber;
  final double salePrice;
  final int stockBreak;
  final int stockCurrent;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.category,
    required this.storeNumber,
    required this.salePrice,
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
      salePrice: (data['salePrice'] ?? 0.0).toDouble(),
      stockBreak: (data['stockBreak'] ?? 0).toInt(),
      stockCurrent: (data['stockCurrent'] ?? 0).toInt(),
    );
  }
}

// [2. VIEWMODEL]
class StockBreakViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> getUserStoreNumber() async {
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
      debugPrint("Error transferring stock: $e");
      rethrow;
    }
  }

    List<ProductModel> filterProducts({
    required List<ProductModel> products,
    required String nameFilter,
    required String brandFilter,
    required String categoryFilter,
    required String storeNumberFilter,
    required String? priceRange,
    required String? userStoreNumber, // Adicionar este parâmetro
  }) {
    // Se o userStoreNumber não estiver configurado, retornar lista vazia
    if (userStoreNumber == null || userStoreNumber.isEmpty) {
      return [];
    }

    // Se não houver filtros específicos, usar o storeNumber do usuário como padrão
    final effectiveStoreFilter = storeNumberFilter.isEmpty 
        ? userStoreNumber 
        : storeNumberFilter;

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
      
      // Verificar se o produto pertence ao storeNumber efetivo
      if (product.storeNumber.toLowerCase() != effectiveStoreFilter.toLowerCase()) {
        return false;
      }

      return product.name.toLowerCase().contains(nameFilter.toLowerCase()) &&
          product.brand.toLowerCase().contains(brandFilter.toLowerCase()) &&
          product.category.toLowerCase().contains(categoryFilter.toLowerCase()) &&
          product.salePrice >= minPrice &&
          product.salePrice <= maxPrice;
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

  @override
  void initState() {
    super.initState();
    _viewModel = StockBreakViewModel();
    _fetchUserStoreNumber();
  }

  Future<void> _fetchUserStoreNumber() async {
    final storeNumber = await _viewModel.getUserStoreNumber();
    if (storeNumber != null) {
      setState(() {
        _storeNumberController.text = storeNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Stock Brake Management", style: TextStyle(color: Colors.white)),
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
            _buildTextField(_brandController, 'Brand'),
            _buildTextField(_categoryController, 'Category'),
            _buildTextField(_storeNumberController, 'Filter by store number', enabled: false),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.clear_all),
                  tooltip: 'Clear all filters',
                  onPressed: () {
                    setState(() {
                      _nameController.clear();
                      _brandController.clear();
                      _categoryController.clear();
                      _selectedPriceRange = null;
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
    return StreamBuilder<List<ProductModel>>(
      stream: _viewModel.getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No products found.'));
        }

        return FutureBuilder<String?>(
          future: _viewModel.getUserStoreNumber(),
          builder: (context, storeNumberSnapshot) {
            if (storeNumberSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final storeNumber = storeNumberSnapshot.data;
            
            // Se não houver storeNumber configurado
            if (storeNumber == null || storeNumber.isEmpty) {
              return Center(
                child: Text('Your account is not associated with any store. Please contact admin.', style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0))),
              );
            }

            final filteredProducts = _viewModel.filterProducts(
              products: snapshot.data!,
              nameFilter: _nameController.text,
              brandFilter: _brandController.text,
              categoryFilter: _categoryController.text,
              storeNumberFilter: _storeNumberController.text,
              priceRange: _selectedPriceRange,
              userStoreNumber: storeNumber,
            );

            if (filteredProducts.isEmpty) {
              return Center(child: Text('No products found matching your criteria.'));
            }

            return ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(
                      product.name, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Brand: ${product.brand.isNotEmpty ? product.brand : "Without brand"}"),
                        Text("Model: ${product.model.isNotEmpty ? product.model : "Without model"}"),
                        Text("Category: ${product.category.isNotEmpty ? product.category : "Without category"}"),
                        Text("Stock Break: ${product.stockBreak}"),
                      ],
                    ),
                    onTap: () => _showProductDetailsDialog(context, product),
                  ),
                );
              },
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
          value: null, // Opção para limpar o filtro
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
    
    showDialog(
      context: context,
      builder: (context) {
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
              Text("Stock Break: ${product.stockBreak}"),
              Text("Current Stock: ${product.stockCurrent}"),
              SizedBox(height: 10),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Quantity to transfer",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final transferQuantity = int.tryParse(quantityController.text) ?? 0;
                
                if (transferQuantity > 0 && transferQuantity <= product.stockBreak) {
                  try {
                    await _viewModel.transferStock(
                      productId: product.id,
                      transferQuantity: transferQuantity,
                      currentStockBreak: product.stockBreak,
                      currentStockCurrent: product.stockCurrent,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock updated successfully!')),
                    );

                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating stock!')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid quantity!')),
                  );
                }
              },
              child: Text('Transfer'),
            ),
          ],
        );
      },
    );
  }
}