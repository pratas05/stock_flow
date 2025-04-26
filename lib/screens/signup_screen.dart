import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stockflow/firebase_auth_services.dart';
import 'package:stockflow/reusable_widgets/custom_snackbar.dart';
import 'package:stockflow/reusable_widgets/privacy_policy.dart';
import 'package:stockflow/screens/login_screen.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

// [1. VIEWMODEL]
class SignUpViewModel {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final TextEditingController emailTextController = TextEditingController();
  final TextEditingController passwordTextController = TextEditingController();
  final TextEditingController confirmPasswordTextController = TextEditingController();
  bool obscureText = true;
  bool termsAccepted = false;

  bool passwordConfirmed() {
    return passwordTextController.text.trim() == confirmPasswordTextController.text.trim();
  }

  PasswordValidation isPasswordValid(String password) {
    return PasswordValidation(
      hasMinLength: password.length >= 8,
      hasNumber: RegExp(r'\d').hasMatch(password),
      hasUpperCase: RegExp(r'[A-Z]').hasMatch(password),
      hasSpecialChar: RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
    );
  }

  Future<void> signUp(BuildContext context) async {
    if (emailTextController.text.isEmpty || passwordTextController.text.isEmpty || confirmPasswordTextController.text.isEmpty) {
      CustomSnackbar.show(context: context, message: 'Please fill in all fields.'); 
      return;
    }

    if (!termsAccepted) {
      CustomSnackbar.show(context: context, message: 'You must accept the terms and conditions.'); 
      return;
    }

    final emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    final emailRegex = RegExp(emailPattern);

    if (!emailRegex.hasMatch(emailTextController.text)) {
      CustomSnackbar.show(context: context, message: 'The email address is not valid. Please check your input.', backgroundColor: Colors.red); 
      return;
    }

    if (!passwordConfirmed()) {
      CustomSnackbar.show(context: context, message: 'Passwords do not match.', backgroundColor: Colors.red); 
      return;
    }

    final passwordValidation = isPasswordValid(passwordTextController.text.trim());
    if (!passwordValidation.isValid()) {
      CustomSnackbar.show(context: context, message: 'Password must meet all requirements.', backgroundColor: Colors.red); 
      return;
    }

    try {
      User? user = await _auth.signUpWithEmailAndPassword(
        emailTextController.text.trim(),
        passwordTextController.text.trim(),
      );

      if (user != null) {
        CustomSnackbar.show(context: context, message: 'Verification email sent. Please check your email.', backgroundColor: Colors.green);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      CustomSnackbar.show(context: context, message: e.message ?? 'An error occurred. Please try again.');
    }
  }

  void dispose() {
    emailTextController.dispose();
    passwordTextController.dispose();
    confirmPasswordTextController.dispose();
  }
}

class PasswordValidation {
  final bool hasMinLength;
  final bool hasNumber;
  final bool hasUpperCase;
  final bool hasSpecialChar;

  PasswordValidation({
    required this.hasMinLength,
    required this.hasNumber,
    required this.hasUpperCase,
    required this.hasSpecialChar,
  });

  bool isValid() {return hasMinLength && hasNumber && hasUpperCase && hasSpecialChar;}
}

// [2. VIEW]
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final SignUpViewModel _viewModel = SignUpViewModel();
  PasswordValidation _passwordValidation = PasswordValidation(
    hasMinLength: false,
    hasNumber: false,
    hasUpperCase: false,
    hasSpecialChar: false,
  );

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
                  ? 600 
                  : MediaQuery.of(context).size.width * 0.95,
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
                      children: <Widget>[
                        Image.asset(
                          "assets/images/logo.png", 
                          width: 150,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Stock Flow",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Your stock inventory application",
                          style: TextStyle(fontSize: 18, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Create an Account", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 20),

                        // Email Field
                        TextFormField(
                          controller: _viewModel.emailTextController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            labelText: "Enter your Email",
                            prefixIcon: const Icon(Icons.person_outline),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _viewModel.passwordTextController,
                          obscureText: _viewModel.obscureText,
                          onChanged: (value) {
                            setState(() {
                              _passwordValidation = _viewModel.isPasswordValid(value);
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            labelText: "Enter your Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_viewModel.obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _viewModel.obscureText = !_viewModel.obscureText;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Password Requirements
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Password Requirements:",
                                style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              _buildRequirementItem("At least 8 characters long", _passwordValidation.hasMinLength),
                              _buildRequirementItem("1 uppercase letter (A-Z)", _passwordValidation.hasUpperCase),
                              _buildRequirementItem("1 number (0-9)", _passwordValidation.hasNumber),
                              _buildRequirementItem("1 special character (!@#\$%^&*)", _passwordValidation.hasSpecialChar),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Confirm Password Field
                        TextFormField(
                          controller: _viewModel.confirmPasswordTextController,
                          obscureText: _viewModel.obscureText,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            labelText: "Confirm your Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_viewModel.obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _viewModel.obscureText = !_viewModel.obscureText;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Terms and Conditions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _viewModel.termsAccepted,
                              onChanged: (bool? value) {
                                setState(() {
                                  _viewModel.termsAccepted = value ?? false;
                                });
                              },
                            ),
                            const Text(
                              "By clicking on the box, you will accept our ",
                              style: TextStyle(color: Colors.black, fontSize: 14),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Terms and Conditions"),
                                        content: SingleChildScrollView(
                                          child: const Text(PrivacyPolicy.privacyPolicyText),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            }, 
                                            child: const Text('Close')
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Terms and Conditions",
                                    style: TextStyle(color: Colors.lightBlue[300], fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sign Up Button
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 400
                              ? 300
                              : MediaQuery.of(context).size.width * 0.8,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.2),
                              shadowColor: Colors.transparent,
                            ),
                            onPressed: () async {
                              await _viewModel.signUp(context);
                            },
                            child: const Text(
                              'Sign Up', 
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        signInOption(context),
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

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            child: Icon(
              isMet ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: isMet ? Colors.green : Colors.redAccent.withOpacity(0.6),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.green : Colors.black87,
                fontSize: 13,
                fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget signInOption(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?", style: TextStyle(color: Colors.black, fontSize: 14)),
        const SizedBox(width: 5),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInScreen()));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
            backgroundColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Sign In', style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}