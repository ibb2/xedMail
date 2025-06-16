import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleSignIn;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

class SignInDemo extends StatefulWidget {
  @override
  _SignInDemoState createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> {
  late GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      params: GoogleSignInParams(
        clientId:
            '611007919856-2jae4hpql0eaeai46kpappvasajc1uf0.apps.googleusercontent.com',
        clientSecret: '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',
        scopes: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/userinfo.profile',
          'https://mail.google.com/',
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sign-In Demo')),
      body: Center(
        child: Column(
          children: [
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final credentials = await _googleSignIn.signIn();
                if (credentials != null) {
                  print('Signed in successfully: ${credentials.accessToken}');
                } else {
                  print('Sign in failed');
                }
              },
              child: const Text('Sign In'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
