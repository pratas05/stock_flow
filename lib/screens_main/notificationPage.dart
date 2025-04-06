// MVVM
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stockflow/utils/colors_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

// [1. MODEL]
class NotificationModel {
  final String id, message, notificationType, storeNumber;
  final Timestamp timestamp;
  final String? productId;
  final String? userId;

  NotificationModel({
    required this.id,
    required this.message,
    required this.notificationType,
    required this.storeNumber,
    required this.timestamp,
    this.productId,
    this.userId,
  });

  factory NotificationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      message: data['message'] ?? '',
      notificationType: data['notificationType'] ?? 'Standard',
      storeNumber: data['storeNumber'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      productId: data['productId'],
      userId: data['userId'],
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String model;
  final double salePrice;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.salePrice,
  });

  factory ProductModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      salePrice: (data['salePrice'] ?? 0.0).toDouble(),
    );
  }
}

// [2. VIEWMODEL]
class NotificationsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> getUserStoreNumber() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['storeNumber'] as String?;
    } catch (e) {
      debugPrint("Error fetching store number: $e"); return null;
    }
  }

  Stream<List<NotificationModel>> getNotificationsStream(String storeNumber) {
    return _firestore
        .collection('notifications')
        .where('storeNumber', isEqualTo: storeNumber)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromDocument(doc))
            .toList());
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> deleteExpiredNotifications(String storeNumber) async {
    try {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(Duration(days: 3));

      // Modifique a consulta para não precisar do índice composto
      final allNotifications = await _firestore
          .collection('notifications')
          .where('storeNumber', isEqualTo: storeNumber)
          .get();

      final expiredNotifications = allNotifications.docs.where((doc) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isBefore(threeDaysAgo);
      }).toList();

      for (final doc in expiredNotifications) {await doc.reference.delete();}
    } catch (e) {
      debugPrint("Error deleting expired notifications: $e");
      // Você pode adicionar um retry ou notificar o usuário aqui
    }
  }

  Future<void> sendAdminNotification({
    required String message,
    required String notificationType,
    required String storeNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {throw Exception('User not authenticated');}

    if (storeNumber.isEmpty) {throw Exception('Store number not configured');}

    try {
      await _firestore.collection('notifications').add({
        'message': message,
        'notificationId': _firestore.collection('notifications').doc().id,
        'notificationType': notificationType,
        'storeNumber': storeNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
    } catch (e) {
      debugPrint("Error sending notification: $e");
      throw Exception('Failed to send notification: ${e.toString()}');
    }
  }

  Future<ProductModel?> getProductDetails(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {return ProductModel.fromDocument(doc);} return null;
    } catch (e) {
      debugPrint("Error fetching product details: $e");
      return null;
    }
  }

  static bool isNotificationExpired(Timestamp timestamp) {
    final notificationTime = timestamp.toDate();
    final currentTime = DateTime.now();
    final difference = currentTime.difference(notificationTime);
    return difference.inDays > 3;
  }

  static String formatTimeElapsed(DateTime dateTime) {return timeago.format(dateTime, locale: 'en');}
}

// [3. VIEW]
class NotificationsStockAlert extends StatelessWidget {
  const NotificationsStockAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_alert),
                onPressed: () => _showSendNotificationModal(context), iconSize: 25.0,
              ),
            ],
          ),
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
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<String?>(
          future: NotificationsViewModel().getUserStoreNumber(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text(
                  'You are not connected to any store. Please contact your Admin.', style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 0, 0, 0)),
                ),
              );
            }

            final storeNumber = snapshot.data!;
            NotificationsViewModel().deleteExpiredNotifications(storeNumber);

            return StreamBuilder<List<NotificationModel>>(
              stream: NotificationsViewModel().getNotificationsStream(storeNumber),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error to load notificatons.', style: TextStyle(fontSize: 18, color: Colors.white)),
                  );
                }

                final notifications = snapshot.data ?? [];
                final validNotifications = notifications.where((n) => 
                  !NotificationsViewModel.isNotificationExpired(n.timestamp)).toList();

                if (validNotifications.isEmpty) {
                  return const Center(
                    child: Text('No notifications available.', style: TextStyle(fontSize: 18, color: Colors.white)),
                  );
                }

                return ListView(
                  children: _groupNotificationsByDay(validNotifications).entries.map((entry) {
                    final dayLabel = entry.key;
                    final notificationsForDay = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10.0),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(dayLabel,
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        ...notificationsForDay.map((notification) {
                          return _buildNotificationCard(context, notification);
                        }).toList(),
                      ],
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notification) {
    final iconData = _getIconForType(notification.notificationType);
    final iconColor = _getColorForType(notification.notificationType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showNotificationDetails(context, notification),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Colors.white],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.message,
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              NotificationsViewModel.formatTimeElapsed(notification.timestamp.toDate()),
                              style: const TextStyle(fontSize: 12.0, color: Colors.black54),
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              children: [
                                Icon(iconData, color: iconColor, size: 18.0),
                                const SizedBox(width: 8.0),
                                Text(
                                  notification.notificationType,
                                  style: const TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, notification.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Order': return Icons.add_box;
      case 'Update': return Icons.inventory_2;
      case 'Transfer': return Icons.swap_horiz;
      case 'UpdatePrice': return Icons.attach_money;
      case 'Create': return Icons.fiber_new;
      case 'Edit': return Icons.edit;
      case 'Meeting': return Icons.timelapse_sharp;
      case 'Warning': return Icons.warning;
      case 'Schedule': return Icons.schedule;
      default: return Icons.notification_important;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Order': return Color.fromARGB(255, 25, 105, 170);
      case 'Update': return Color.fromARGB(255, 23, 143, 27);
      case 'Transfer': return Color.fromARGB(255, 131, 6, 153);
      case 'UpdatePrice': return Color.fromARGB(255, 255, 115, 0);
      case 'Create': return Colors.black;
      case 'Edit': return Color.fromARGB(255, 221, 199, 0);
      case 'Meeting': return Color.fromARGB(255, 3, 12, 138);
      case 'Warning': return Color.fromARGB(255, 141, 128, 9);
      case 'Schedule': return Colors.black;
      default: return Colors.red;
    }
  }

  void _showSendNotificationModal(BuildContext context) async {
    final messageController = TextEditingController();
    String selectedCategory = '';
    
    // Verificar o storeNumber antes de mostrar o diálogo
    final storeNumber = await NotificationsViewModel().getUserStoreNumber();
    if (storeNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cant send notifications because you are not connected to any store.'),
          duration: Duration(seconds: 5),
        ),
      ); return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Administrative Message'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message',
                      contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 10),
                  const Text('Choose the notification category:'),
                  DropdownButton<String>(
                    value: selectedCategory.isEmpty ? null : selectedCategory,
                    hint: const Text('Choose Category'),
                    items: const [
                      DropdownMenuItem(value: 'Schedule', child: Text('Schedule')),
                      DropdownMenuItem(value: 'Warning', child: Text('Warning')),
                      DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                    ],
                    onChanged: (value) {
                      if (value != null) {setState(() => selectedCategory = value);}
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () async {
                if (messageController.text.length < 5 || selectedCategory.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message must have at least 5 characters and a category must be chosen.'),
                    ),
                  );
                } else {
                  try {
                    await NotificationsViewModel().sendAdminNotification(
                      message: messageController.text,
                      notificationType: selectedCategory,
                      storeNumber: storeNumber,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification sent successfully!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send notification: ${e.toString()}'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }, child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String notificationId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this notification? This action cannot be undone."),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSecondDeleteConfirmation(context, notificationId);
              },
              child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSecondDeleteConfirmation(BuildContext context, String notificationId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Again"),
          content: const Text("This is your last chance to cancel. Do you really want to delete this notification?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await NotificationsViewModel().deleteNotification(notificationId);
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Notification deleted successfully.")),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Error deleting notification.")),
                  );
                }
              },
              child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNotificationDetails(BuildContext context, NotificationModel notification) async {
  try {
    final product = notification.productId != null 
        ? await NotificationsViewModel().getProductDetails(notification.productId!)
        : null;

    final notificationDate = notification.timestamp.toDate().toLocal();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(notificationDate);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notification Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5E61F4)),
                ),
                SizedBox(height: 16),
                
                if (product != null) ...[
                  _buildDetailRow(
                    "Product Name:", product.name,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _buildDetailRow(
                    "Brand:", product.brand,
                  ),
                  _buildDetailRow(
                    "Model:", product.model,
                  ),
                  _buildDetailRow(
                    "Price:",
                    "\$${product.salePrice.toStringAsFixed(2)}",
                    valueStyle: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                  ),
                  Divider(color: Colors.grey[300], height: 24, thickness: 1),
                ],
                
                _buildDetailRow(
                  "Date:", formattedDate, valueStyle: TextStyle(color: const Color.fromARGB(255, 178, 31, 236)),
                ),
                
                SizedBox(height: 12),
                Text(
                  "Message:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200] ?? Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    notification.message, style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(),
              child: Text("Close", style: TextStyle(color: Color(0xFF5E61F4))),
            ),
          ],
        );
      },
    );
  } catch (e) {
    debugPrint("Error showing notification details: $e");
  }
}

  Widget _buildDetailRow(String label, String value, {TextStyle? labelStyle, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: labelStyle ?? TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDay(List<NotificationModel> notifications) {
    final Map<String, List<NotificationModel>> groupedNotifications = {};

    for (final notification in notifications) {
      final dateTime = notification.timestamp.toDate();
      String dayLabel;

      if (_isToday(dateTime)) {
        dayLabel = "Today - ${_formatDate(dateTime)}";
      } else if (_isYesterday(dateTime)) {
        dayLabel = "Yesterday - ${_formatDate(dateTime)}";
      } else {
        dayLabel = _formatDate(dateTime);
      }
      groupedNotifications.putIfAbsent(dayLabel, () => []).add(notification);
    }
    return groupedNotifications;
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;
  }

  bool _isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  String _formatDate(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }
}