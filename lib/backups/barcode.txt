import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

class BarcodePage extends StatelessWidget {
  final String productId;
  final String productName;

  const BarcodePage({
    Key? key,
    required this.productId,
    required this.productName,
  }) : super(key: key);

  // Método estático para mostrar o diálogo de código de barras
  static Future<void> showBarcodeDialog(
    BuildContext context, 
    String productId, 
    String productName
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  productName, 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: productId,
                        width: 250, height: 100,
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Barcode'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product information
            Text(
              productName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'ID: $productId',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            
            // Barcode container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Barcode image
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: productId,
                    width: 250,
                    height: 100,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 15),
                  
                  // Barcode number
                  Text(
                    productId,
                    style: const TextStyle(
                      fontSize: 16,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Print button
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Barcode'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30, 
                  vertical: 15
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Print functionality will be implemented')
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}