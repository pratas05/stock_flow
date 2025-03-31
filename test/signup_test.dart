import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:stockflow/screens/signup_screen.dart';
import 'login/login_viewmodel_test.mocks.dart';


void main() async {
  // Widget Tests
  group('SignUpScreen Widget Tests', () {
    testWidgets('should display Sign Up button and it should be enabled', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SignUpScreen())));

      final signUpButton = find.text('Sign Up');
      expect(signUpButton, findsOneWidget);

      final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('should allow user to type in form fields', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SignUpScreen())));

      // Test email field
      await tester.enterText(find.byKey(Key('emailField')), 'test@example.com');
      expect(find.text('test@example.com'), findsOneWidget);

      // Test password field
      await tester.enterText(find.byKey(Key('passwordField')), 'Password123!');
      expect(find.text('Password123!'), findsOneWidget);

      // Test confirm password field
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'Password123!');
      expect(find.text('Password123!'), findsOneWidget);
    });

    testWidgets('should show validation errors for empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SignUpScreen())));

      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('Password visibility toggle', (WidgetTester tester) async {
      // Create the LoginPage widget
      await tester.pumpWidget(MaterialApp(
        home: SignUpScreen(),
      ));

      // Find the password field
      final passwordField = find.byType(TextField).at(1);

      // Verify if the password is initially hidden
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect((tester.widget(passwordField) as TextField).obscureText, true);

      // Click the eye icon (visibility)
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      // Verify if the password is visible after the click
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect((tester.widget(passwordField) as TextField).obscureText, false);

      // Click the eye icon again to hide the password
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Verify if the password is hidden again
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect((tester.widget(passwordField) as TextField).obscureText, true);
    });

    testWidgets('should show Terms and Conditions dialog', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SignUpScreen())));

      await tester.tap(find.text('Terms and Conditions'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Terms and Conditions'), findsOneWidget);
    });
  });

  // Integration Tests (Back-end)
  group('SignUpScreen Integration Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockUserCredential mockUserCredential;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockUserCredential = MockUserCredential();

      // Mock default auth behavior
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUserCredential);

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.sendEmailVerification()).thenAnswer((_) async => Future.value());
    });

    testWidgets('Successful registration flow', (WidgetTester tester) async {
      // Arrange
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'valid@example.com',
        password: 'ValidPass123!',
      )).thenAnswer((_) async => mockUserCredential);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SignUpScreen()),
      ));

      // Act
      await tester.enterText(find.byKey(Key('emailField')), 'valid@example.com');
      await tester.enterText(find.byKey(Key('passwordField')), 'ValidPass123!');
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'ValidPass123!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuth.createUserWithEmailAndPassword(
        email: 'valid@example.com',
        password: 'ValidPass123!',
      )).called(1);
      verify(mockUser.sendEmailVerification()).called(1);
      expect(find.text('Verification email sent.'), findsOneWidget);
    });

    testWidgets('Failed registration - email already in use', (WidgetTester tester) async {
      // Arrange
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'used@example.com',
        password: 'ValidPass123!',
      )).thenThrow(FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email already in use',
      ));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SignUpScreen()),
      ));

      // Act
      await tester.enterText(find.byKey(Key('emailField')), 'used@example.com');
      await tester.enterText(find.byKey(Key('passwordField')), 'ValidPass123!');
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'ValidPass123!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Email already in use'), findsOneWidget);
    });

    testWidgets('Failed registration - weak password', (WidgetTester tester) async {
      // Arrange
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'weak',
      )).thenThrow(FirebaseAuthException(
        code: 'weak-password',
        message: 'Password too weak',
      ));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SignUpScreen()),
      ));

      // Act
      await tester.enterText(find.byKey(Key('emailField')), 'test@example.com');
      await tester.enterText(find.byKey(Key('passwordField')), 'weak');
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'weak');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Password too weak'), findsOneWidget);
    });

    testWidgets('Failed registration - passwords dont match', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SignUpScreen()),
      ));

      // Act
      await tester.enterText(find.byKey(Key('emailField')), 'test@example.com');
      await tester.enterText(find.byKey(Key('passwordField')), 'Password123!');
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'Different123!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ));
    });

    testWidgets('Failed registration - terms not accepted', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SignUpScreen()),
      ));

      // Act
      await tester.enterText(find.byKey(Key('emailField')), 'test@example.com');
      await tester.enterText(find.byKey(Key('passwordField')), 'Password123!');
      await tester.enterText(find.byKey(Key('confirmPasswordField')), 'Password123!');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('You must accept the terms'), findsOneWidget);
      verifyNever(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      ));
    });
  });
}