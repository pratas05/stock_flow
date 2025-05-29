// CONSIDERAÇÕES:
// ALTERAR O BALANCE DA SANDBOX ACCOUNT PARA O PAGAMENTO SER FEITO NA INTEGRA, NO PAYPAL E NAO NO CARTÃO DE CRÉDITO
// INICIAR SESSÃO COM A SANDBOX ACCOUNT PARA TESTAR O PAGAMENTO (guardar num local seguro ou ver no Dasboard do PayPal)

import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
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
          clientId: "ATBJQijKrqA15oox5NOP8ndG7oQ7wdeW1_g5VuKHqnjQvE0pex4jDH9_qkBNQGnHmvOQs2o3Ssik2Z5g",
          secretKey: "ED8yKANlBttX--ze-CeiqqlqHAd6t2nfOLq0teDp3QaZyxbfpzJ-TwGfxPuNKJBmSoFw9LXGZVc6Inbo",
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