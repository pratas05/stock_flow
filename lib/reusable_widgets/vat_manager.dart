import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stockflow/screens_main/product_database.dart';

class VatMonitorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductViewModel _productViewModel = ProductViewModel();
  StreamSubscription? _vatSubscription;

  void startMonitoring(String storeNumber) {
    _vatSubscription = _firestore
        .collection('iva')
        .doc(storeNumber)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      
      // Verifica cada possível código de VAT
      for (int i = 1; i <= 4; i++) {
        final vatKeys = ['VAT$i', 'vat$i', 'IVA$i'];
        for (final key in vatKeys) {
          if (data.containsKey(key)) {
            final rateValue = data[key];
            final double newRate = rateValue is int ? rateValue.toDouble() :
                                rateValue is double ? rateValue :
                                rateValue is String ? double.tryParse(rateValue) ?? 0.0 :
                                0.0;
            
            final decimalRate = newRate / 100;
            await _productViewModel.updateProductsVatPrices(storeNumber, i.toString(), decimalRate);
            break; // Sai do loop se encontrar o VAT code
          }
        }
      }
    });
  }
  
  void stopMonitoring() {
    _vatSubscription?.cancel();
  }
}