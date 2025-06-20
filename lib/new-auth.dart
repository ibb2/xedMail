import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:oauth2_client/google_oauth2_client.dart';

class NewAuthenticationPage extends StatefulWidget {
  const NewAuthenticationPage({super.key});
  @override
  State<NewAuthenticationPage> createState() => _NewAuthenticationPageState();
}

class _NewAuthenticationPageState extends State<NewAuthenticationPage> {
  String? tokenJson, profileJson;

  Future<void> login() async {
    // 1. Start Shelf server on random localhost port
    final server = await shelf_io.serve(
      (shelf.Request req) async {
        // Handshake: OAuth2 client picks up the URL itself
        return shelf.Response.ok(
          '<html><body>You may close this window.</body></html>',
          headers: {'content-type': 'text/html'},
        );
      },
      '127.0.0.1',
      8000,
    );

    final redirectUri = 'http://127.0.0.1:${server.port}/';

    // 2. Instantiate client & helper
    final googleClient = GoogleOAuth2Client(
      redirectUri: redirectUri,
      customUriScheme: 'http',
    );
    final oauth = OAuth2Helper(
      googleClient,
      clientId:
          '611007919856-7lkiask2j8v2r6r69npc8tbbesvj10as.apps.googleusercontent.com',
      scopes: ['openid', 'email', 'profile', 'https://mail.google.com/'],
    );

    try {
      // 3. Acquire token
      oauth.disconnect();
      await oauth.removeAllTokens();
      final token = await oauth.getToken();
      print('Token: $token');
      tokenJson = json.encode({
        'accessToken': token?.accessToken,
        'refreshToken': token?.refreshToken,
        'expiresIn': token?.expiresIn,
      });

      print('Token JSON: $tokenJson');
      // 4. Fetch profile
      final resp = await oauth.get(
        Uri.parse(
          'https://www.googleapis.com/oauth2/v1/userinfo?alt=json',
        ).toString(),
      );
      print('Profile Response: ${resp.body}');
      profileJson = resp.body;
    } catch (e) {
      tokenJson = 'Error: $e';
      print('Error during OAuth2 flow: $e');
      profileJson = null;
    } finally {
      await server.close();
    }

    setState(() {});
  }

  Future<void> logout() async {
    // Clear tokens and profile
    setState(() {
      tokenJson = null;
      profileJson = null;
    });
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google OAuth2 Desktop')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: login, child: const Text('Login')),
            if (tokenJson != null) ...[
              const SizedBox(height: 20),
              const Text('Tokens:'),
              SelectableText(tokenJson!),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    tokenJson = null;
                    profileJson = null;
                  });
                },
                child: const Text('Clear Tokens'),
              ),
            ],
            if (profileJson != null) ...[
              const SizedBox(height: 20),
              const Text('Profile:'),
              SelectableText(profileJson!),
            ],
          ],
        ),
      ),
    );
  }
}
