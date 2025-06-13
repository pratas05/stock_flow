import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';
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
  final String id, name, brand, model;
  final double basePrice, vatPrice;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.basePrice,
    required this.vatPrice,
  });

  factory ProductModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      vatPrice: (data['vatPrice'] ?? 0.0).toDouble(),
    );
  }
}

// [2. VIEWMODEL]
class NotificationsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> hasNotificationAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final storeNumber = userDoc.data()?['storeNumber'] as String?;
      final isStoreManager = userDoc.data()?['isStoreManager'] ?? false;
      final adminPermission = userDoc.data()?['adminPermission'] as String?;

      // If user is store manager, check if adminPermission matches storeNumber
      if (isStoreManager) {
        return adminPermission == storeNumber;
      }

      // Regular users with store number can access
      return storeNumber != null && storeNumber.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking notification access: $e");
      return false;
    }
  }

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

      for (final doc in expiredNotifications) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error deleting expired notifications: $e");
    }
  }

  Future<void> sendAdminNotification({
    required String message,
    required String notificationType,
    required String storeNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (storeNumber.isEmpty) {
      throw Exception('Store number not configured');
    }

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
      if (doc.exists) {
        return ProductModel.fromDocument(doc);
      }
      return null;
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

  static String formatTimeElapsed(DateTime dateTime) {
    return timeago.format(dateTime, locale: 'en');
  }
}

// [3. VIEW]
class NotificationsStockAlert extends StatelessWidget {
  const NotificationsStockAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAccessAndStoreNumber(), // Nova função combinada
      builder: (context, snapshot) {
        // Enquanto está carregando
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        // Se erro ou sem storeNumber
        if (snapshot.hasError || snapshot.data?['storeNumber'] == null) {
          return const ErrorScreen(
            icon: Icons.warning_amber_rounded,
            title: "Store Access Required",
            message: "Your account is not associated with any store. Please contact admin.",
          );
        }

        // Se tem storeNumber mas não tem acesso
        if (snapshot.data?['hasAccess'] == false) {
          return const ErrorScreen(
            icon: Icons.warning_amber_rounded,
            title: "Access Denied",
            message: "You don't have permission to access notifications for this store.",
          );
        }

        // Conteúdo principal
        return _buildMainContent(context, snapshot.data!['storeNumber'] as String);
      },
    );
  }

  // Nova função combinada para evitar múltiplos FutureBuilders
  Future<Map<String, dynamic>> _checkAccessAndStoreNumber() async {
    final storeNumber = await NotificationsViewModel().getUserStoreNumber();
    if (storeNumber == null || storeNumber.isEmpty) {
      return {'storeNumber': null, 'hasAccess': false};
    }

    final hasAccess = await NotificationsViewModel().hasNotificationAccess();
    return {'storeNumber': storeNumber, 'hasAccess': hasAccess};
  }

  Widget _buildMainContent(BuildContext context, String storeNumber) {
    NotificationsViewModel().deleteExpiredNotifications(storeNumber);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.add_alert),
                onPressed: () => _showSendNotificationModal(context),
                iconSize: 25.0,
                color: Colors.white,
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<List<NotificationModel>>(
          stream: NotificationsViewModel().getNotificationsStream(storeNumber),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Error loading notifications.',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              );
            }

            final notifications = snapshot.data ?? [];
            final validNotifications = notifications
                .where((n) => !NotificationsViewModel.isNotificationExpired(n.timestamp))
                .toList();

            if (validNotifications.isEmpty) {
              return const Center(
                child: Text(
                  'No notifications available.',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              );
            }

            return ListView(
              children: _groupNotificationsByDay(validNotifications)
                  .entries
                  .map((entry) {
                final dayLabel = entry.key;
                final notificationsForDay = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10.0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.lightBlueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          dayLabel,
                          style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    ...notificationsForDay
                        .map((notification) => _buildNotificationCard(context, notification))
                        .toList(),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, NotificationModel notification) {
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3))
              ],
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
                              style: const TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              NotificationsViewModel.formatTimeElapsed(
                                  notification.timestamp.toDate()),
                              style: const TextStyle(
                                  fontSize: 12.0, color: Colors.black54),
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              children: [
                                Icon(iconData, color: iconColor, size: 18.0),
                                const SizedBox(width: 8.0),
                                Text(
                                  notification.notificationType,
                                  style: const TextStyle(
                                      fontSize: 12.0,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _confirmDelete(context, notification.id),
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
      case 'Order':
        return Icons.add_box;
      case 'Update':
        return Icons.inventory_2;
      case 'Transfer':
        return Icons.swap_horiz;
      case 'UpdatePrice':
        return Icons.attach_money;
      case 'Create':
        return Icons.fiber_new;
      case 'Edit':
        return Icons.edit;
      case 'Meeting':
        return Icons.timelapse_sharp;
      case 'Warning':
        return Icons.warning;
      case 'Schedule':
        return Icons.schedule;
      case 'Break':
        return Icons.insert_page_break;
      case 'Discount':
        return Icons.discount_sharp;
      default:
        return Icons.notification_important;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Order':
        return Color.fromARGB(255, 25, 105, 170);
      case 'Update':
        return Color.fromARGB(255, 23, 143, 27);
      case 'Transfer':
        return Color.fromARGB(255, 131, 6, 153);
      case 'UpdatePrice':
        return Color.fromARGB(255, 255, 115, 0);
      case 'Create':
        return Colors.black;
      case 'Edit':
        return Color.fromARGB(255, 221, 199, 0);
      case 'Meeting':
        return Color.fromARGB(255, 3, 12, 138);
      case 'Warning':
        return Color.fromARGB(255, 141, 128, 9);
      case 'Schedule':
        return Colors.black;
      case 'Break':
        return Color.fromARGB(255, 219, 14, 14);
      case 'Discount':
        return Color.fromARGB(255, 16, 91, 11);
      default:
        return Colors.red;
    }
  }

  void _showSendNotificationModal(BuildContext context) async {
    final messageController = TextEditingController();
    String selectedCategory = '';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomSnackbar.show(
          context: context,
          message: 'You need to be logged in to send notifications');
      return;
    }

    // Obter os dados do usuário
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data();

    // Verificar o storeNumber primeiro
    final storeNumber = userData?['storeNumber'];
    if (storeNumber == null) {
      CustomSnackbar.show(
          context: context,
          message: 'Store number not configured. Please contact admin.');
      return;
    }

    // Depois verificar se é storeManager
    final isStoreManager = userData?['isStoreManager'] ?? false;
    if (!isStoreManager) {
      CustomSnackbar.show(
          context: context,
          message: 'You do not have permission to send custom notifications');
      return;
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
                      DropdownMenuItem(
                          value: 'Schedule', child: Text('Schedule')),
                      DropdownMenuItem(
                          value: 'Warning', child: Text('Warning')),
                      DropdownMenuItem(
                          value: 'Meeting', child: Text('Meeting')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            TextButton(
              onPressed: () async {
                if (messageController.text.length < 5 ||
                    selectedCategory.isEmpty) {
                  CustomSnackbar.show(
                      context: context,
                      message:
                          'Message must have at least 5 characters and a category must be chosen.');
                  return;
                } else {
                  try {
                    await NotificationsViewModel().sendAdminNotification(
                      message: messageController.text,
                      notificationType: selectedCategory,
                      storeNumber: storeNumber,
                    );
                    Navigator.pop(context);
                    CustomSnackbar.show(
                        context: context,
                        message: 'Notification sent successfully!',
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2));
                  } catch (e) {
                    CustomSnackbar.show(
                        context: context,
                        message: 'Error sending notification: $e',
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2));
                  } finally {
                    messageController.clear();
                    selectedCategory = '';
                  }
                }
              },
              child: const Text('Send',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isStoreManager = userDoc.data()?['isStoreManager'] ?? false;

      if (!isStoreManager) {
        CustomSnackbar.show(
            context: context,
            message: 'You do not have permission to delete notifications');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text(
              "Are you sure you want to delete this notification? This action cannot be undone."),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel")),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await NotificationsViewModel().deleteNotification(notificationId);
          CustomSnackbar.show(
            context: context,
            message: "Notification deleted successfully.",
            backgroundColor: Colors.green,
          );
        } catch (e) {
          CustomSnackbar.show(
            context: context,
            message: "Error deleting notification: $e",
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      CustomSnackbar.show(
          context: context,
          message: 'Error checking permissions: $e',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2));
    }
  }

  Future<void> _showNotificationDetails(
    BuildContext context, NotificationModel notification) async {
    try {
      final product = notification.productId != null
          ? await NotificationsViewModel().getProductDetails(notification.productId!)
          : null;

      // Get discount information if this is a discount notification
      double? discountPrice;
      int? discountPercent;
      Timestamp? endDate;
      
      if (product != null) {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .get();
            
        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          if (productData.containsKey('discountPrice') && 
              productData['discountPrice'] != null &&
              productData.containsKey('endDate') &&
              productData['endDate'] != null) {
            endDate = productData['endDate'] as Timestamp;
            if (endDate.toDate().isAfter(DateTime.now())) {
              discountPrice = (productData['discountPrice'] as num).toDouble();
              discountPercent = productData['discountPercent'] as int?;
            }
          }
        }
      }

      final notificationDate = notification.timestamp.toDate().toLocal();
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(notificationDate);

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
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
                  const SizedBox(height: 16),
                  if (product != null) ...[
                    _buildDetailRow(
                      "Product Name:",
                      product.name,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _buildDetailRow(
                      "Brand:",
                      product.brand,
                    ),
                    _buildDetailRow(
                      "Model:",
                      product.model,
                    ),
                    if (discountPrice != null && endDate != null)
                      _buildDiscountPriceRow(
                        originalPrice: product.vatPrice,
                        discountPrice: discountPrice,
                        discountPercent: discountPercent,
                        endDate: endDate,
                      )
                    else
                      _buildDetailRow(
                        "Price:",
                        "\$${product.vatPrice.toStringAsFixed(2)}",
                        valueStyle: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Divider(color: Colors.grey[300], height: 24, thickness: 1),
                  ],
                  _buildDetailRow(
                    "Date:", formattedDate, valueStyle: TextStyle(color: const Color.fromARGB(255, 178, 31, 236)),
                  ),
                  const SizedBox(height: 12),
                  Text("Message:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[200] ?? Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Text(notification.message, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Close", style: TextStyle(color: Color(0xFF5E61F4))),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Error showing notification details: $e");
      CustomSnackbar.show(
        context: context,
        message: "Failed to load notification details",
        backgroundColor: Colors.red,
      );
    }
  }

  Widget _buildDiscountPriceRow({
    required double originalPrice,
    required double discountPrice,
    required int? discountPercent,
    required Timestamp endDate,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Price: ", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        Text(
          "\$${originalPrice.toStringAsFixed(2)}",
          style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        Text(
          "\$${discountPrice.toStringAsFixed(2)}",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        if (discountPercent != null) ...[
          const SizedBox(width: 4),
          Text(
            "($discountPercent% OFF)",
            style: TextStyle(color: Colors.green[800], fontSize: 12),
          ),
        ],
        const SizedBox(width: 8),
        Tooltip(
          message: 'Promotion ends ${DateFormat('dd/MM HH:mm').format(endDate.toDate())}',
          child: Icon(Icons.timer, size: 16, color: Colors.red),
        ),
      ],
    );
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
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: valueStyle ?? TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDay(
      List<NotificationModel> notifications) {
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
  String _formatDate(DateTime dateTime) {return "${dateTime.day}/${dateTime.month}/${dateTime.year}";}
}