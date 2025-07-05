import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/error_screen.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  String? storeNumber;
  bool isLoading = true;
  bool hasStoreAccess = false;
  bool isPending = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          hasStoreAccess = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('User document does not exist');
        setState(() {
          isLoading = false;
          hasStoreAccess = false;
        });
        return;
      }

      final data = userDoc.data();
      if (data == null) {
        debugPrint('User document data is null');
        setState(() {
          isLoading = false;
          hasStoreAccess = false;
        });
        return;
      }

      setState(() {
        storeNumber = data['storeNumber']?.toString();
        isPending = data['isPending'] as bool? ?? false;
        isLoading = false;
        hasStoreAccess = storeNumber != null && storeNumber!.isNotEmpty;
      });

      if (hasStoreAccess) {
        _cleanupOldMessages();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        isLoading = false;
        hasStoreAccess = false;
      });
    }
  }

  Future<void> _cleanupOldMessages() async {
    try {
      if (storeNumber == null) return;

      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      final querySnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('storeNumber', isEqualTo: storeNumber)
          .where('createdAt', isLessThan: Timestamp.fromDate(oneDayAgo))
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {debugPrint('Error cleaning up old messages: $e');}
  }

  Future<void> _sendMessage() async {
    try {
      final text = _messageController.text.trim();
      if (text.isEmpty || storeNumber == null) return;

      await FirebaseFirestore.instance.collection('messages').add({
        'text': text,
        'storeNumber': storeNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });

      _messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  Stream<QuerySnapshot> _chatStream() {
    if (storeNumber == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('messages')
        .where('storeNumber', isEqualTo: storeNumber)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('Error in chat stream: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (isPending) {
      return const ErrorScreen(
        icon: Icons.hourglass_top,
        title: "Pending Approval",
        message: "Your account is pending approval. Please wait for admin confirmation.",
      );
    }

    if (!hasStoreAccess) {
      return const ErrorScreen(
        icon: Icons.warning_amber_rounded,
        title: "Store Access Required",
        message: "Your account is not associated with any store. Please contact admin.",
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Store Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: Column(
          children: [
            Expanded(child: _buildChatMessages()),
            _buildMessageInput(),
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildChatMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Chat stream error: ${snapshot.error}');
          return const Center(
            child: Text(
              'Error loading messages',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildMessageItem(docs[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'];
    final isCurrentUser = userId == FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Loading...', style: TextStyle(color: Colors.white)),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Unknown User';
        final plainMessage = data['text'] ?? '';

        return Align(
          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? Colors.blueAccent.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.8),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isCurrentUser ? const Radius.circular(12) : const Radius.circular(0),
                      bottomRight: isCurrentUser ? const Radius.circular(0) : const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    plainMessage,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (value) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 28),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}