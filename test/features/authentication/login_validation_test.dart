import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/theme/app_theme.dart';
import 'package:pinpoint/core/widgets/app_text_field.dart';
import 'package:pinpoint/features/authentication/presentation/screens/login_screen.dart';

void main() {
  testWidgets('login fields explain how to fix an empty email and a short password', (tester) async {
    final email = TextEditingController();
    final password = TextEditingController(text: 'short');
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: email,
                  label: 'Email',
                  validator: validateLoginEmail,
                ),
                AppTextField(
                  controller: password,
                  label: 'Password',
                  obscureText: true,
                  validator: validateLoginPassword,
                ),
                TextButton(
                  onPressed: () => formKey.currentState!.validate(),
                  child: const Text('Check'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(find.text('Enter the email on your account.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
  });
}
