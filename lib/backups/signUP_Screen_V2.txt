import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stockflow/firebase_auth_services.dart';
import 'package:stockflow/screens/login_screen.dart';
import 'package:stockflow/utils/colors_utils.dart';

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

  bool isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'\d').hasMatch(password)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return false;
    return true;
  }

  Future<void> signUp(BuildContext context) async {
    if (emailTextController.text.isEmpty || passwordTextController.text.isEmpty || confirmPasswordTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      ); return;
    }

    if (!termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the terms and conditions.')),
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

    if (!passwordConfirmed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      ); return;
    }

    if (!isPasswordValid(passwordTextController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must meet all requirements.')),
      ); return;
    }

    try {
      User? user = await _auth.signUpWithEmailAndPassword(
        emailTextController.text.trim(),
        passwordTextController.text.trim(),
      );

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your email.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create account. Please try again.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'An error occurred. Please try again.')),
      );
    }
  }

  void dispose() {
    emailTextController.dispose();
    passwordTextController.dispose();
    confirmPasswordTextController.dispose();
  }
}

// [2. VIEW]
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final SignUpViewModel _viewModel = SignUpViewModel();

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
                          "Create an Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black,),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _viewModel.emailTextController,
                            decoration: InputDecoration(
                              filled: true, fillColor: Colors.grey[300],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              labelText: "Enter your Email", icon: const Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _viewModel.passwordTextController,
                            obscureText: _viewModel.obscureText,
                            decoration: InputDecoration(
                              filled: true, fillColor: Colors.grey[300],
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

                        // Nova versão melhorada da mensagem de requisitos da senha
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Password Requirements:",
                                style: TextStyle(color: Colors.black,fontSize: 13,fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              _buildRequirementItem("At least 8 characters long"),
                              _buildRequirementItem("1 uppercase letter (A-Z)"),
                              _buildRequirementItem("1 number (0-9)"),
                              _buildRequirementItem("1 special character (!@#\$%^&*)"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _viewModel.confirmPasswordTextController,
                            obscureText: _viewModel.obscureText,
                            decoration: InputDecoration(
                              filled: true, fillColor: Colors.grey[300],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              labelText: "Confirm your Password",
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
                        const SizedBox(height: 20),

                        // Checkbox de Aceitação dos Termos
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
                                          child: const Text(
                                            '''
                  Privacy Policy
  Last updated: November 4, 2024

  This Privacy Policy describes Our policies and procedures on the collection, use, and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You.
  We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy.

  Additional Privacy Compliance and Regulations
  Our Privacy Policy also covers the following compliance regulations and considerations:

  Google Analytics and Tracking
  Yes, we use Google Analytics and other related tools to monitor and analyze our website traffic, understand user behavior, and improve our services.

  Email Communications
  Yes, we may send emails to users, and users can opt in to receive emails from us for updates, special offers, and other service-related information.

  CCPA + CPRA Compliance
  This Privacy Policy has been updated to include requirements from the California Consumer Privacy Act (CCPA), amended by the California Privacy Rights Act (CPRA), which apply to websites, apps, and businesses with users from California, USA. We comply with user rights for California residents, including access, deletion, and opting out of data sales.

  GDPR Compliance
  We comply with the General Data Protection Regulation (GDPR) for users from the European Union (EU) and European Economic Area (EEA). Our users have rights including access, correction, deletion, and data portability.

  CalOPPA Compliance
  We comply with the California Online Privacy Protection Act (CalOPPA), which applies to websites, apps, and businesses in the US or with users from California, USA. This policy includes disclosure about the types of personal information collected and how it is used, as required under CalOPPA.

  COPPA Compliance
  We comply with the Children's Online Privacy Protection Act (COPPA) in the United States. Our services are not directed to children under the age of 13, and we do not knowingly collect personal information from them. If we become aware of any data collected from children, we take steps to delete it.

  Interpretation and Definitions
  Interpretation
  The words of which the initial letter is capitalized have meanings defined under the following conditions. The following definitions shall have the same meaning regardless of whether they appear in singular or in plural.

  Definitions
  For the purposes of this Privacy Policy:
  • Account means a unique account created for You to access our Service or parts of our Service.
  • Affiliate means an entity that controls, is controlled by or is under common control with a party, where "control" means ownership of 50% or more of the shares, equity interest, or other securities entitled to vote for election of directors or other managing authority.
  • Application refers to stockflow, the software program provided by the Company.
  • Company (referred to as either "the Company", "We", "Us" or "Our" in this Agreement) refers to stockflow.
  • Country refers to: Portugal
  • Device means any device that can access the Service such as a computer, a cellphone, or a digital tablet.
  • Personal Data is any information that relates to an identified or identifiable individual.
  • Service refers to the Application.
  • Service Provider means any natural or legal person who processes the data on behalf of the Company. It refers to third-party companies or individuals employed by the Company to facilitate the Service, to provide the Service on behalf of the Company, to perform services related to the Service, or to assist the Company in analyzing how the Service is used.
  • Usage Data refers to data collected automatically, either generated by the use of the Service or from the Service infrastructure itself (for example, the duration of a page visit).
  • You means the individual accessing or using the Service, or the company, or other legal entity on behalf of which such individual is accessing or using the Service, as applicable.

  Collecting and Using Your Personal Data
  Types of Data Collected
  Personal Data
  While using Our Service, We may ask You to provide Us with certain personally identifiable information that can be used to contact or identify You. Personally identifiable information may include, but is not limited to:
  • Email address
  • First name and last name
  • Address, State, Province, ZIP/Postal code, City
  • Usage Data

  Usage Data
  Usage Data is collected automatically when using the Service. Usage Data may include information such as Your Device's Internet Protocol address (e.g. IP address), browser type, browser version, the pages of our Service that You visit, the time and date of Your visit, the time spent on those pages, unique device identifiers and other diagnostic data.

  Information Collected while Using the Application
  While using Our Application, in order to provide features of Our Application, We may collect, with Your prior permission:
  • Pictures and other information from your Device's camera and photo library.
  We use this information to provide features of Our Service, to improve and customize Our Service. The information may be uploaded to the Company's servers and/or a Service Provider's server or it may be simply stored on Your device.
  You can enable or disable access to this information at any time, through Your Device settings.

  Use of Your Personal Data
  The Company may use Personal Data for the following purposes:
  • To provide and maintain our Service, including to monitor the usage of our Service.
  • To manage Your Account: to manage Your registration as a user of the Service. The Personal Data You provide can give You access to different functionalities of the Service that are available to You as a registered user.
  • For the performance of a contract: the development, compliance, and undertaking of the purchase contract for the products, items, or services You have purchased or of any other contract with Us through the Service.
  • To contact You: To contact You by email, telephone calls, SMS, or other equivalent forms of electronic communication, such as a mobile application's push notifications regarding updates or informative communications related to the functionalities, products, or contracted services, including security updates.
  • To provide You with news, special offers, and general information about other goods, services, and events which we offer that are similar to those that you have already purchased or enquired about unless You have opted not to receive such information.
  • To manage Your requests: To attend and manage Your requests to Us.
  • For business transfers: We may use Your information to evaluate or conduct a merger, divestiture, restructuring, reorganization, dissolution, or other sale or transfer of some or all of Our assets, where Personal Data held by Us about our Service users is among the assets transferred.
  • For other purposes: We may use Your information for other purposes, such as data analysis, identifying usage trends, determining the effectiveness of our promotional campaigns, and evaluating and improving our Service, products, services, marketing, and user experience.

  Retention of Your Personal Data
  The Company will retain Your Personal Data only for as long as is necessary for the purposes set out in this Privacy Policy. We will retain and use Your Personal Data to comply with our legal obligations, resolve disputes, and enforce our agreements and policies.

  Transfer of Your Personal Data
  Your information, including Personal Data, may be transferred to and maintained on computers located outside of Your jurisdiction where data protection laws may differ. Your consent to this Privacy Policy followed by Your submission of such information represents Your agreement to that transfer.

  Delete Your Personal Data
  You have the right to delete or request deletion of Your Personal Data collected by Us. You can delete or update information through your Account settings or by contacting Us.

  Disclosure of Your Personal Data
  Business Transactions
  If the Company is involved in a merger, acquisition, or asset sale, Your Personal Data may be transferred.

  Law Enforcement
  We may disclose Your Personal Data if required by law or in response to valid requests by public authorities.

  Security of Your Personal Data
  We use commercially acceptable means to protect Your Personal Data, but no method is 100% secure.

  Children's Privacy
  Our Service does not address anyone under the age of 13, and we do not knowingly collect personal identifiable information from them.

  Changes to This Privacy Policy
  We may update Our Privacy Policy from time to time. You are advised to review this Privacy Policy periodically.

  Contact Us
  If you have any questions about this Privacy Policy, You can contact us at helpstockflow@gmail.com
                                            '''
                                          ),
                                        ),
                                        actions: [TextButton(onPressed: () {Navigator.of(context).pop();}, child: const Text('Close'))],
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
                                    style: TextStyle(color: Colors.lightBlue[300], fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

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
                            onPressed: () async {await _viewModel.signUp(context);},
                            child: const Text(
                              'Sign Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,),
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

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3, right: 6),
            child: Icon(
              Icons.circle, size: 6, color: Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              text, style: const TextStyle(color: Colors.black, fontSize: 13,
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
        const Text(
          "Already have an account?", style: TextStyle(color: Colors.black, fontSize: 14,),
        ),
        const SizedBox(width: 5), // Espaço entre o texto e o botão
        TextButton(
          onPressed: () {Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInScreen()));},
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), backgroundColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'Sign In', style: TextStyle(color: Colors.lightBlue[300], fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}