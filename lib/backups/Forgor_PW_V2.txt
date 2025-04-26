import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';

// [1. VIEWMODEL]
class ForgotPasswordViewModel {
  final TextEditingController emailController = TextEditingController();

  Future<void> passwordReset(BuildContext context) async {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      CustomSnackbar.show(
        context: context,
        message: 'Please enter your email address.'
      ); return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      CustomSnackbar.show(
        context: context,
        message: 'Password reset link sent. Your email needs to be associated with an account.', 
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      CustomSnackbar.show(
        context: context,
        message: e.message ?? 'An error occurred. Please try again.', backgroundColor: Colors.red,
      );
    }
  }

  void dispose() {
    emailController.dispose();
  }
}

// [2. VIEW]
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final ForgotPasswordViewModel _viewModel = ForgotPasswordViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width > 500
                  ? 600 : MediaQuery.of(context).size.width * 0.95,
              padding: const EdgeInsets.all(25),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.17),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/logo.png", width: 120,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Are you forgot your password?",
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black,),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25.0),
                          child: Text(
                            'Enter your email to receive a password reset link',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black, fontSize: 18,),
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.25,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: TextField(
                                controller: _viewModel.emailController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Email',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: () async {
                            await _viewModel.passwordReset(context);
                          },
                          child: const Text(
                            'Reset Password',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.2),
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {Navigator.pop(context);},
                                child: Text(
                                  'Return to Login',
                                  style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold,),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}