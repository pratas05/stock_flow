import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:stockflow/reusable_widgets/analysis_processor.dart';
import 'package:stockflow/reusable_widgets/secrets.dart';

class StoreDashboardPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot>> _getProducts() async {
    // Primeiro obtemos todos os produtos que têm vendas
    final salesSnapshot = await _firestore.collection('sales').get();
    
    // Criamos um conjunto com os IDs dos produtos que têm vendas
    final productsWithSales = salesSnapshot.docs.map((doc) => doc.id).toSet();
    
    // Se não houver produtos com vendas, retornamos lista vazia
    if (productsWithSales.isEmpty) {
      return [];
    }
    
    // Agora obtemos apenas os produtos que estão no conjunto de IDs
    final querySnapshot = await _firestore
        .collection('products')
        .where(FieldPath.documentId, whereIn: productsWithSales.toList())
        .get();
    
    return querySnapshot.docs;
  }

  Future<List<Map<String, dynamic>>> _getProductSales(String productId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    final salesSnapshot = await _firestore
        .collection('sales')
        .doc(productId)
        .get();

    if (!salesSnapshot.exists) {
      return [];
    }

    final salesData = salesSnapshot.data() as Map<String, dynamic>;
    final salesList = salesData['sales'] as List<dynamic>? ?? [];

    // Filter and convert sales from last 30 days
    return salesList.where((sale) {
      final saleDate = (sale['date'] as Timestamp).toDate();
      return saleDate.isAfter(thirtyDaysAgo);
    }).map((sale) => {
      ...sale as Map<String, dynamic>,
      'id': productId,
    }).toList();
  }

  Future<void> _generateProductReport(
    BuildContext context,
    String productId,
    String productName,
  ) async {
    try {
      // Obter vendas dos últimos 30 dias
      final sales = await _getProductSales(productId);

      // Obter informações do produto (incluindo localizações e stock)
      final productDoc = await _firestore.collection('products').doc(productId).get();
      final productData = productDoc.data() ?? {};

      // Correção da leitura de localizações
      final productLocations = productData['productLocations'];
      final numberOfLocations = (productLocations is List) ? productLocations.length : 0;
      
      // Obter informações de stock
      final stockMax = (productData['stockMax'] as num?)?.toInt() ?? 0;

      final totalRevenue = sales.fold(0.0, (sum, sale) => sum + (sale['total'] ?? 0.0));
      final totalCost = sales.fold(0.0, (sum, sale) => sum + ((sale['lastPurchasePrice'] ?? 0.0) * (sale['quantity'] ?? 1)));
      final totalQuantitySold = sales.fold(0, (sum, sale) => sum + ((sale['quantity'] ?? 1) as int));

      // Gerar análise com IA
      final aiConclusion = await _getAIConclusion(
        productId,
        productName,
        sales,
        totalCost,
        totalQuantitySold,
        stockMax,
      );

      // Conteúdo do relatório
      final reportContent = '''
  Relatório do Produto: $productName

  - Total de Vendas (últimos 30 dias): ${sales.length}
  - Receita Total: €${totalRevenue.toStringAsFixed(2)}
  - Custo Total: €${totalCost.toStringAsFixed(2)}
  - Quantidade Total de Itens Vendidos: $totalQuantitySold
  - Lucro: €${(totalRevenue - totalCost).toStringAsFixed(2)}
  - Margem de Lucro: ${totalRevenue > 0 ? ((totalRevenue - totalCost) / totalRevenue * 100).toStringAsFixed(2) : '0.00'}%
  - Número de Localizações: $numberOfLocations
  - Stock Máximo: $stockMax
  - Proporção Vendas/Stock: ${stockMax > 0 ? (totalQuantitySold / stockMax * 100).toStringAsFixed(2) : 'N/A'}%

  Análise AI:
  $aiConclusion
  ''';

      // Salvar em arquivo
      final directory = await getDownloadsDirectory();
      final file = File(
        '${directory?.path}/Relatorio_${productName}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(reportContent);

      // Mostrar mensagem de sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Relatório salvo em ${file.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar relatório: $e')),
        );
      }
    }
  }

  Future<String> _getAIConclusion(
    String productId,
    String productName,
    List<Map<String, dynamic>> salesList,
    double totalCost,
    int totalQuantity,
    int stockMax,
  ) async {
    // Cálculo da receita total
    double totalRevenue = salesList.fold(0.0, (sum, sale) => sum + (sale['total'] ?? 0.0));
    final totalSales = salesList.length;
    
    // Cálculo da proporção vendas/stock
    final salesToStockRatio = stockMax > 0 ? (totalQuantity / stockMax) : 0;

    try {
      // Obter informações do produto
      final productDoc = await _firestore.collection('products').doc(productId).get();
      final productData = productDoc.data() ?? {};
      
      // CORREÇÃO DEFINITIVA - usando apenas productLocations
      final locationsArray = productData['productLocations'] as List<dynamic>?;
      final numberOfLocations = locationsArray?.length ?? 0;

      // Obter preço - usar vatPrice se price for 0
      double productPrice = (productData['price'] as num?)?.toDouble() ?? 0.0;
      if (productPrice == 0.0) {
        productPrice = (productData['vatPrice'] as num?)?.toDouble() ?? 0.0;
      }
      
      final productDescription = productData['description']?.toString() ?? 'Sem descrição disponível';
      final productCategory = productData['category'] ?? 'Sem categoria';
      final productBrand = productData['brand'] ?? 'Sem marca';

      final apiKey = groqApiKey;
      const url = "https://api.groq.com/openai/v1/chat/completions";

      final prompt = '''
  Analise o desempenho comercial do produto "$productName" com estas métricas:

  **Dados Básicos:**
  - Categoria: $productCategory
  - Marca: $productBrand
  - Preço Atual: €${productPrice.toStringAsFixed(2)} ${productPrice == 0 ? '(preço obtido do vatPrice)' : ''}
  - Número de Localizações: $numberOfLocations (${numberOfLocations > 1 ? 'Disponível em múltiplas lojas' : 'Disponível em uma loja'})
  - Stock Máximo: $stockMax unidades

  **Métricas de Vendas:**
  - Total de Vendas (30 dias): $totalSales
  - Quantidade Vendida: $totalQuantity unidades
  - Receita Total: €${totalRevenue.toStringAsFixed(2)}
  - Custo Total: €${totalCost.toStringAsFixed(2)}
  - Lucro: €${(totalRevenue - totalCost).toStringAsFixed(2)}
  - Margem: ${totalRevenue > 0 ? ((totalRevenue - totalCost) / totalRevenue * 100).toStringAsFixed(2) : 0}%
  - Proporção Vendas/Stock Máximo: ${salesToStockRatio.toStringAsFixed(2)} (${(salesToStockRatio * 100).toStringAsFixed(2)}%)

  **Análise Requerida:**
  1. Avalie se o stock máximo atual ($stockMax) é adequado para a demanda (vendas de $totalQuantity unidades em 30 dias)
  2. Sugira ajustes no stock máximo se necessário ou se as vendas forem satisfatórias
  3. Avalie o impacto das $numberOfLocations localização(ões) nas vendas.
  4. Exiba o €${productPrice.toStringAsFixed(2)}) do produto. Compare com produtos similares existentes no mercado (pesquise na web e liste por tópicos produtos semelhantes e compare com o preço de €${productPrice.toStringAsFixed(2)}). Quero também que indique as caracteristicas desse produto comparando com a $productDescription.
  5. Sugira estratégias de marketing para aumentar as vendas.
  6. Conclusão final sobre o desempenho do produto na loja.

  Forneça uma análise completa em português com foco prático, especialmente sobre a gestão do stock e desempenho do produto.
  ''';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "model": "llama3-70b-8192",
          "messages": [{"role": "user", "content": prompt}],
          "temperature": 0.7,
          "max_tokens": 1024
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AnalysisProcessor.process(data['choices'][0]['message']['content']);
      } else {
        return '''
  Análise básica:
  - Vendas: $totalSales unidades (${totalQuantity} itens)
  - Lucro: €${(totalRevenue - totalCost).toStringAsFixed(2)}
  - Margem: ${((totalRevenue - totalCost) / totalRevenue * 100).toStringAsFixed(2)}%
  - Disponível em $numberOfLocations localização(ões)
  - Stock Máximo: $stockMax (${salesToStockRatio >= 1 ? 'Pode ser insuficiente' : 'Adequado'} para vendas de $totalQuantity unidades)
  - Preço: €${productPrice.toStringAsFixed(2)} ${productPrice == 0 ? '(obtido do vatPrice)' : ''}
  ''';
      }
    } catch (e) {
      return 'Erro ao gerar análise: ${e.toString()}';
    }
  }

  Future<void> _showProductSelectionDialog(BuildContext context) async {
    try {
      final products = await _getProducts();
      
      if (products.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum produto com vendas encontrado')),
          );
        }
        return;
      }

      if (context.mounted) {
        // Variáveis para controle da pesquisa
        final searchController = TextEditingController();
        List<QueryDocumentSnapshot> filteredProducts = List.from(products);

        showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                void filterProducts(String query) {
                  setState(() {
                    filteredProducts = products.where((product) {
                      final name = product['name']?.toString().toLowerCase() ?? '';
                      final model = product['model']?.toString().toLowerCase() ?? '';
                      final searchLower = query.toLowerCase();
                      return name.contains(searchLower) || model.contains(searchLower);
                    }).toList();
                  });
                }

                // Calcula a altura baseada no número de produtos filtrados
                final screenHeight = MediaQuery.of(context).size.height;
                final itemHeight = 70.0;
                final headerFooterHeight = 180.0; // Aumentado para acomodar a barra de pesquisa
                final dialogHeight = min(
                  screenHeight * 0.7, // Aumentei para 70% para melhor visualização
                  max(250.0, (filteredProducts.length * itemHeight) + headerFooterHeight),
                );

                return Dialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: dialogHeight,
                      minWidth: 320,
                      maxWidth: 500,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cabeçalho com título e barra de pesquisa
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            children: [
                              Text(
                                'Selecionar Produto',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: hexStringToColor("5E61F4"),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: searchController,
                                onChanged: filterProducts,
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar produtos...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Lista de produtos filtrados
                        Expanded(
                          child: filteredProducts.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Nenhum produto encontrado',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  physics: const ClampingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    final category = product['category']?.toString().toLowerCase() ?? 'eletrônicos';
                                    
                                    final iconData = {
                                      'eletrônicos': Icons.devices_other,
                                      'informática': Icons.computer,
                                      'vestuário': Icons.checkroom,
                                    }[category] ?? Icons.shopping_bag;
                                    
                                    final iconColor = {
                                      'eletrônicos': Colors.blueAccent,
                                      'informática': Colors.purpleAccent,
                                      'vestuário': Colors.orangeAccent,
                                    }[category] ?? hexStringToColor("5E61F4");
                                    
                                    return InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _generateProductReport(
                                          context,
                                          product.id,
                                          product['name'] ?? 'Produto sem nome',
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade100,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: iconColor.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(iconData, size: 18, color: iconColor),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    product['name'] ?? 'Sem nome',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Modelo: ${product['model'] ?? 'Sem modelo'}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey.shade400,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        
                        // Rodapé com botão CANCELAR
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: hexStringToColor("5E61F4"),
                                side: BorderSide(
                                  color: hexStringToColor("5E61F4"),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar produtos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hexStringToColor("5E61F4"),
              hexStringToColor("9546C4"),
              hexStringToColor("CB2B93"),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeader(context),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Gerar Relatório'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      onPressed: () => _showProductSelectionDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildOverviewCards(),
                const SizedBox(height: 20),
                _buildChartsSection(),
                const SizedBox(height: 20),
                _buildRecentTransactions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Store Analytics",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              "Last updated: ${DateTime.now().toString().substring(0, 10)}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€1,245.80",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Average Purchase Price",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€8,745.20",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Monthly Revenue",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.money_off, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€3,210.50",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Last Month Expenses",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "1,248",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Total Products",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Performance Metrics",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildGlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Revenue vs Expenses (Last 6 Months)",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "Bar Chart Placeholder",
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildGlassCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Top Selling Categories",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "Pie Chart Placeholder",
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Inventory Status",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInventoryStatus(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryStatus() {
    return Column(
      children: [
        _buildStatusItem("In Stock", "856", Colors.green),
        const SizedBox(height: 8),
        _buildStatusItem("Low Stock", "127", Colors.orange),
        const SizedBox(height: 8),
        _buildStatusItem("Out of Stock", "42", Colors.red),
        const SizedBox(height: 8),
        _buildStatusItem("On Order", "89", Colors.blue),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recent Transactions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildGlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              _buildTransactionRow("Product A", "€125.50", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Product B", "€89.99", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Supplier X", "€-450.00", Icons.local_shipping, Colors.red),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Product C", "€210.00", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Supplier Y", "€-320.75", Icons.local_shipping, Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(String title, String amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ColorFilter.mode(Colors.white.withOpacity(0.1), BlendMode.srcOver),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(15),
            child: child,
          ),
        ),
      ),
    );
  }
}