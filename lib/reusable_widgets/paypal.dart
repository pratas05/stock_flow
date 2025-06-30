import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:stockflow/reusable_widgets/secrets.dart';
import 'package:stockflow/screens_main/buy_trade.dart';

Future<bool?> processPaypalPayment({
  required BuildContext context,
  required List<CartItem> cartItems,
  required double cartTotal,
  required VoidCallback onSuccess,
}) async {
  try {
    final paymentSuccess = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (BuildContext context) => PaypalCheckoutView(
          sandboxMode: true,
          clientId: paypalClientId,
          secretKey: paypalSecretKey,
          transactions: [
            {
              "amount": {
                "total": cartTotal.toStringAsFixed(2),
                "currency": "EUR",
                "details": {
                  "subtotal": cartTotal.toStringAsFixed(2),
                  "shipping": '0',
                  "shipping_discount": 0
                }
              },
              "description": "Payment for ${cartItems.length} items",
              "item_list": {
                "items": cartItems.map((item) {
                  return {
                    "name": "${item.product.name} - ${item.product.model}",
                    "quantity": item.quantity,
                    "price": item.product.vatPrice.toStringAsFixed(2),
                    "currency": "EUR"
                  };
                }).toList(),
              }
            }
          ],
          note: "Thank you for your purchase!",
          onSuccess: (Map params) async {
            Navigator.of(context).pop(true);
            onSuccess();
          },
          onError: (error) {
            Navigator.of(context).pop(false);
          },
          onCancel: () {
            Navigator.of(context).pop(false);
          },
        ),
      ),
    );

    return paymentSuccess;
  } catch (e) {
    rethrow;
  }
}