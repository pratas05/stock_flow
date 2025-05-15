// lib/presentation/chat_page.dart
// RETIRAR
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  String? storeNumber;
  bool isLoading = true; // Add a loading state

  @override
  void initState() {
    super.initState();
    _getStoreNumber();
    _cleanupOldMessages(); // Clean up old messages when the page is loaded
  }

  Future<void> _getStoreNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            storeNumber = userDoc['storeNumber'];
            isLoading = false; // Set loading to false after fetching storeNumber
          });
          //print('Fetched storeNumber: $storeNumber'); // Debug print
        } else {
          setState(() {
            isLoading = false; // Stop loading if user document does not exist
          });
          print('User document does not exist.');
        }
      } catch (e) {
        setState(() {
          isLoading = false; // Stop loading on error
        });
        print('Error fetching store number: $e');
      }
    } else {
      setState(() {
        isLoading = false; // Stop loading if no user is logged in
      });
      print('No user is logged in.');
    }
  }

  Future<void> _cleanupOldMessages() async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      final querySnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('createdAt', isLessThan: Timestamp.fromDate(oneDayAgo))
          .get();

      for (var doc in querySnapshot.docs) {
        await FirebaseFirestore.instance.collection('messages').doc(doc.id).delete();
      }

      //print('Old messages cleaned up successfully.');
    } catch (e) {
      print('Error cleaning up old messages: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || storeNumber == null) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'text': text,
      'storeNumber': storeNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });
    _messageController.clear();
  }

  Stream<QuerySnapshot> _chatStream() {
    if (storeNumber == null) {
      print('storeNumber is null. Returning empty stream.');
      return const Stream.empty(); // Return an empty stream if storeNumber is null
    }
    try {
      return FirebaseFirestore.instance
          .collection('messages')
          .where('storeNumber', isEqualTo: storeNumber)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Error creating Firestore query: $e');
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Store Chat',
          style: TextStyle(color: Colors.white), // Ensure the text is visible
        ),
        backgroundColor: Colors.transparent, // Make the AppBar transparent
        elevation: 0, // Remove the shadow
        iconTheme: const IconThemeData(color: Colors.white), // Ensure icons are visible
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator()) // Show loading indicator
            : storeNumber == null
                ? const Center(child: Text('Unable to fetch store number.'))
                : Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _chatStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              print('StreamBuilder error: ${snapshot.error}');
                              if (snapshot.error.toString().contains('failed-precondition')) {
                                return const Center(
                                  child: Text(
                                    'A required index is missing. Please try again later.',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const Center(child: Text('Error loading messages.'));
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white),));
                            }
                            final docs = snapshot.data!.docs;
                            return ListView.builder(
                              reverse: true,
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final userId = data['userId'];
                                final isCurrentUser = userId == FirebaseAuth.instance.currentUser?.uid;

                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                                  builder: (context, userSnapshot) {
                                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Loading...'),
                                      );
                                    }
                                    if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Unknown User'),
                                      );
                                    }

                                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                    final userName = userData['name'] ?? 'Unknown User';

                                    return Align(
                                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Column(
                                          crossAxisAlignment: isCurrentUser
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
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
                                                  bottomLeft: isCurrentUser
                                                      ? const Radius.circular(12)
                                                      : const Radius.circular(0),
                                                  bottomRight: isCurrentUser
                                                      ? const Radius.circular(0)
                                                      : const Radius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                data['text'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
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
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Adjusted vertical padding
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
                                  fillColor: Colors.transparent,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    _sendMessage(); // Call the send message function
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
