import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stockflow/google_sign.dart';
import 'package:stockflow/screens/forgot_pw_page.dart';
import 'package:stockflow/screens/signup_screen.dart';
import 'package:stockflow/screens/home_screen.dart';
import 'package:stockflow/utils/colors_utils.dart';

// [1. VIEWMODEL]
class SignInViewModel {
  final TextEditingController emailTextController = TextEditingController();
  final TextEditingController passwordTextController = TextEditingController();
  bool obscureText = true;

  Future<void> signIn(BuildContext context) async {
  if (emailTextController.text.isEmpty || passwordTextController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please, fill the fields first.')),
    ); return;
  }

  // Validação do formato do e-mail
  final emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  final emailRegex = RegExp(emailPattern);

  if (!emailRegex.hasMatch(emailTextController.text)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The email address is not valid. Please check your input.')),
    ); return;
  }

  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailTextController.text.trim(),
      password: passwordTextController.text.trim(),
    );
    
    User? user = userCredential.user;

    if (user != null && !user.emailVerified) {
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not verified. Please verify your email before logging in.')),
      );
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(getErrorMessage(e.code))),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
    );
  }
}

  String getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid. Please check your input.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for more information.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again. If you do not have an account, try registering first.';
    } 
  }

  void dispose() {
    emailTextController.dispose();
    passwordTextController.dispose();
  }
}

// [2. VIEW]
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final SignInViewModel _viewModel = SignInViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
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
                      children: <Widget>[
                        Image.asset(
                          "assets/images/logo.png", width: 150,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Stock Flow", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 10),
                        const Text(
                          "Your stock inventory application",
                          style: TextStyle(fontSize: 18, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Please Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black,),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          key: Key('emailField'),
                          width: double.infinity,
                          child: TextFormField(
                            controller: _viewModel.emailTextController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[300],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              labelText: "Enter your Email",
                              icon: const Icon(Icons.person_outline),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          key: Key('passwordField'),
                          width: double.infinity,
                          child: TextFormField(
                            controller: _viewModel.passwordTextController,
                            obscureText: _viewModel.obscureText,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[300],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              labelText: "Enter your Password",
                              icon: const Icon(Icons.lock_outline),
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Align( // Botão "Forgot Password"
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordPage()),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "Forgot Password", style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold,),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Botão de Login
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
                            onPressed: () async {await _viewModel.signIn(context);},
                            child: const Text(
                              'Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,)),
                          ),
                        ),

                        const SizedBox(height: 20),
                        signUpOption(context),
                        const SizedBox(height: 20),

                        const Text( // Opção para login com Google + Botão de Suporte
                          "Or continue with the following option",
                          style: TextStyle(color: Colors.black), textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween, // Espaço entre os botões
                          children: [
                            // Espaço vazio à esquerda para empurrar o botão do Google para o centro
                            const SizedBox(width: 120), // Altere o valor do width conforme necessário

                            ElevatedButton( // Botão de Login com Google (centralizado)
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                minimumSize: const Size(50, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(60),
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/google.png', height: 35, width: 35,
                              ),
                              onPressed: () async {await signInWithGoogle(context);},
                            ),

                            TextButton.icon( // Botão de Suporte
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Support Email'),
                                      content: Text.rich(
                                        TextSpan(
                                          text: 'For assistance, please contact: ',
                                          children: [
                                            TextSpan(text: 'helpstockflow@gmail.com',style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('Close'), onPressed: () {Navigator.of(context).pop();}),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(Icons.support_agent, color: Colors.lightBlue[300]),
                              label: Text('Support', style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold)),
                            ),
                          ],
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

  Widget signUpOption(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Not a member?", style: TextStyle(color: Colors.black, fontSize: 14,),
        ),
        const SizedBox(width: 5), // Espaço entre o texto e o botão
       TextButton(
          key: Key('createAccountButton'),
          onPressed: () {
            Navigator.push(
            context,
              MaterialPageRoute(builder: (context) => SignUpScreen()),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), backgroundColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Create an account', style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}