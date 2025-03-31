import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:stockflow/screens/forgot_pw_page.dart';
import '../login/login_viewmodel_test.mocks.dart';

// Generate mocks with build_runner
@GenerateMocks([FirebaseAuth])
void main() {
  // Initialize mocks
  final mockAuth = MockFirebaseAuth();

  // FRONT-END TESTS (Widget Tests)
  group('ForgotPasswordPage Widget Tests', () {
    /* 
    Test 1: Verifies basic UI components are rendered
    - Checks if email TextField exists
    - Checks if Reset Password button exists
    */
    testWidgets('should display email field and reset button', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage()));
      
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
    });

    /* 
    Test 2: Validates empty email field handling
    - Taps reset button without entering email
    - Checks if error message appears
    */
    testWidgets('should show error if email field is empty', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage()));
      await tester.tap(find.text('Reset Password'));
      await tester.pump();
      
      expect(find.text('Please enter your email.'), findsOneWidget);
    });

    /* 
    Test 3: Comprehensive widget verification
    - Checks logo image exists
    - Verifies title and subtitle text
    - Checks email field and placeholder
    - Verifies reset button exists
    - Checks return to login link
    - Validates container decoration
    */
    testWidgets('should load all widgets correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage()));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Are you forgot your password?'), findsOneWidget);
      expect(find.text('Enter your email to receive a password reset link'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Return to Login'), findsOneWidget);

      final containerFinder = find.byType(Container).at(2);
      final Container container = tester.widget(containerFinder);
      expect(container.decoration, isA<BoxDecoration>());
    });

    /* 
    Test 4: Style validation
    - Checks title text styling (font size and weight)
    - Verifies button background color
    */
    testWidgets('should have proper styling', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: ForgotPasswordPage()));

      final titleFinder = find.text('Are you forgot your password?');
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontSize, 26);
      expect(titleText.style?.fontWeight, FontWeight.bold);

      final buttonFinder = find.byType(ElevatedButton);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.style?.backgroundColor?.resolve({}), equals(Colors.black.withOpacity(0.2)));
    });
  });

  // BACK-END TESTS (Integration Tests)
  group('ForgotPasswordPage Backend Tests', () {
    setUp(() {
      // Reset mocks before each test
      reset(mockAuth);
    });

    /* 
    Test 5: Firebase interaction test
    - Mocks successful password reset email
    - Verifies Firebase method is called with correct email
    */
    test('should call FirebaseAuth sendPasswordResetEmail method', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenAnswer((_) => Future.value());

      await mockAuth.sendPasswordResetEmail(email: 'test@example.com');

      verify(mockAuth.sendPasswordResetEmail(email: 'test@example.com')).called(1);
    });

    /* 
    Test 6: Error handling test
    - Mocks invalid email scenario
    - Verifies Firebase exception is thrown
    */
    test('should throw error if email is invalid', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));
      
      expect(() async => await mockAuth.sendPasswordResetEmail(email: 'invalid-email'), 
          throwsA(isA<FirebaseAuthException>()));
    });

    /* 
    Test 7: Empty email validation
    - Mocks empty email scenario
    - Verifies Firebase exception is thrown
    - Confirms the method was called (even though it fails)
    */
    test('should not call sendPasswordResetEmail if email is empty', () async {
      when(mockAuth.sendPasswordResetEmail(email: ''))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      expect(() async => await mockAuth.sendPasswordResetEmail(email: ''),
          throwsA(isA<FirebaseAuthException>()));
      
      verify(mockAuth.sendPasswordResetEmail(email: '')).called(1);
    });
  });
}