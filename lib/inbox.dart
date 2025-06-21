import 'dart:async';
import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:html/parser.dart';
import 'package:oauth2_client/google_oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

class Inbox extends StatefulWidget {
  const Inbox({super.key});

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  late GoogleSignIn _googleSignIn;
  late MailClient _mailClient;
  late OAuth2Helper oauth;

  int? _expandedIndex;
  List<MimeMessage> _emails = [];
  StreamSubscription<MailLoadEvent>? _mailSubscription;
  final Map<int, String> _decodedHtmlBodies = {};
  Map<String, dynamic>? tokenJson;
  Map<String, dynamic>? profileJson;

  @override
  void initState() {
    super.initState();
    initMail();
  }

  Future<void> silentlyLogin() async {
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
    oauth = OAuth2Helper(
      googleClient,
      clientId:
          '611007919856-7lkiask2j8v2r6r69npc8tbbesvj10as.apps.googleusercontent.com',
      scopes: [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
        'openid',
        'https://mail.google.com/',
      ],
    );

    try {
      // 3. Acquire token
      final token = await oauth.getToken();
      print('Token: $token');
      tokenJson = json.decode(
        json.encode({
          'accessToken': token?.accessToken,
          'refreshToken': token?.refreshToken,
          'expiresIn': token?.expiresIn,
        }),
      );

      print('Token JSON: $tokenJson');
      // 4. Fetch profile
      final resp = await oauth.get(
        Uri.parse(
          'https://www.googleapis.com/oauth2/v1/userinfo?alt=json',
        ).toString(),
      );
      print('Profile Response: ${resp.body}');
      profileJson = json.decode(resp.body);
    } catch (e) {
      print('Error during OAuth2 flow: $e');
      profileJson = null;
    } finally {
      await server.close();
    }

    setState(() {});
  }

  /// High level mail API example
  Future<void> initMail() async {
    await silentlyLogin();
    final email = profileJson?["email"];
    print('discovering settings for  $email...');
    final config = await Discover.discover(email);
    if (config == null) {
      // note that you can also directly create an account when
      // you cannot auto-discover the settings:
      // Compare the [MailAccount.fromManualSettings]
      // and [MailAccount.fromManualSettingsWithAuth]
      // methods for details.
      print('Unable to auto-discover settings for $email');
      return;
    }
    print('connecting to ${config.displayName}.');
    if (tokenJson == null) {
      print('Sign in failed or cancelled');
      return;
    }
    final oauthToken = OauthToken(
      accessToken: tokenJson?['accessToken'],
      refreshToken: tokenJson?['refreshToken'],
      tokenType: 'Bearer',
      expiresIn: 3600,
      scope: [
        'openid',
        'email',
        'profile',
        'https://mail.google.com/',
      ].toString(),
      created: DateTime.now(),
    );
    final oauth = OauthAuthentication(email, oauthToken);
    final account = MailAccount.fromDiscoveredSettingsWithAuth(
      name: 'my account',
      email: email,
      auth: oauth,
      config: config,
    );
    _mailClient = MailClient(account, isLogEnabled: true);
    try {
      await _mailClient.connect();
      // final mailboxes = await _mailClient.listMailboxesAsTree(
      //   createIntermediate: false,
      // );
      // print(mailboxes);
      await _mailClient.selectInbox();
      _decodedHtmlBodies.clear();
      _emails = await _mailClient.fetchMessages(count: 20);

      setState(() {
        _emails = _emails.reversed.toList();
      });

      int index = 0;
      for (var email in _emails) {
        final html = email.decodeTextHtmlPart();
        print('Decoded HTML for email $index: $html');
        _decodedHtmlBodies[index] = sanitizeHtml(
          html ?? "<p>No HTML content</p>",
        );

        index++;
      }

      _mailSubscription = _mailClient.eventBus.on<MailLoadEvent>().listen((
        event,
      ) {
        print('New message at ${DateTime.now()}:');
        _emails.insert(0, event.message);
      });

      await _mailClient.startPolling();
      // generate and send email:
    } on MailException catch (e) {
      print('High level API failed with $e');
    }
  }

  /// Very simple, non-destructive HTML sanitizer.
  String sanitizeHtml(String html) {
    final doc = parse(html);

    // Remove <script>, <style>, and <meta>
    doc
        .querySelectorAll('script, style, meta, link')
        .forEach((e) => e.remove());

    // Optional: remove base64 img tags
    doc.querySelectorAll('img').forEach((img) {
      final src = img.attributes['src'];
      if (src != null && src.startsWith('data:image')) {
        img.remove();
      }
    });

    return doc.body?.innerHtml ?? '';
  }

  // Future<void> pollEmails() async {
  //   print("Starting email polling...");
  //   try {
  //     _mailClient.eventBus.on<MailLoadEvent>().listen((event) {
  //       print('New message at ${DateTime.now()}:');
  //       final emails = _mailClient.fetchMessages(count: 1);
  //       setState(() {
  //         appendElements(_emails, emails);
  //       });
  //     });
  //     await _mailClient.startPolling();
  //   } catch (e) {
  //     print('Error fetching emails: $e');
  //   }
  // }

  Future<List<MimeMessage>> appendElements(
    Future<List<MimeMessage>> listFuture,
    Future<List<MimeMessage>> elementsToAdd,
  ) async {
    final list = await listFuture;
    list.addAll(await elementsToAdd);
    return list;
  }

  Future<void> fetchEmails() async {
    var credentials = await _googleSignIn.signIn();
    final email = 'ibyster824@gmail.com';
    print('discovering settings for  $email...');
    final config = await Discover.discover(email);
    if (config == null) {
      // note that you can also directly create an account when
      // you cannot auto-discover the settings:
      // Compare the [MailAccount.fromManualSettings]
      // and [MailAccount.fromManualSettingsWithAuth]
      // methods for details.
      print('Unable to auto-discover settings for $email');
      return;
    }
    print('connecting to ${config.displayName}.');
    if (credentials == null) {
      print('Sign in failed or cancelled');
      return;
    }
    final oauthToken = OauthToken(
      accessToken: credentials.accessToken,
      refreshToken: credentials.refreshToken ?? '',
      tokenType: credentials.tokenType ?? 'Bearer',
      expiresIn: 3600,
      scope: credentials.scopes.toString(),
      created: DateTime.now(),
    );
    final oauth = OauthAuthentication(email, oauthToken);
    final account = MailAccount.fromDiscoveredSettingsWithAuth(
      name: 'my account',
      email: email,
      auth: oauth,
      config: config,
    );
    _mailClient = MailClient(account, isLogEnabled: true);
    print("Connected to account: ${account.name} (${account.email})");
    try {
      await _mailClient.connect();
      print('connected');
      final mailboxes = await _mailClient.listMailboxesAsTree(
        createIntermediate: false,
      );
      print(mailboxes);
      await _mailClient.selectInbox();
      _emails = await _mailClient.fetchMessages(count: 20);
      _emails = _emails.reversed.toList();
    } on MailException catch (e) {
      print('High level API failed with $e');
      return;
    }
  }

  String generateHtml(MimeMessage mimeMessage) {
    return mimeMessage.transformToHtml(
      blockExternalImages: false,
      emptyMessageText: 'Nothing here, move on!',
    );
  }

  void refreshInbox() {
    print('Refreshing inbox...');
    setState(() {
      fetchEmails();
    });
  }

  @override
  void dispose() {
    _mailSubscription?.cancel();
    _mailClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: _emails.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: ListView.builder(
                      itemCount: _emails.length * 2,
                      itemBuilder: (context, index) {
                        final emailIndex = index ~/ 2;

                        if (index.isOdd) {
                          // insert expanded email body after tapped item
                          if (_expandedIndex == emailIndex) {
                            String htmlContent =
                                _decodedHtmlBodies[emailIndex] ??
                                '<p>(Empty)</p>';
                            print('HTML content: $htmlContent');
                            return SizedBox(
                              height: 400,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: InAppWebView(
                                  initialData: InAppWebViewInitialData(
                                    data: htmlContent,
                                    mimeType: 'text/html',
                                    encoding: 'utf-8',
                                  ),
                                  initialSettings: InAppWebViewSettings(
                                    useOnDownloadStart: true,
                                    useOnLoadResource: true,
                                    javaScriptEnabled: true,
                                    useShouldOverrideUrlLoading: true,
                                    clearCache: true,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }

                        final email = _emails[emailIndex];
                        return ListTile(
                          title: Text(email.decodeSubject() ?? 'No Subject'),
                          subtitle: Text(
                            email.from?.firstOrNull.toString() ??
                                'Unknown Sender',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            email.decodeDate()?.toLocal().toString().split(
                                  ' ',
                                )[0] ??
                                '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            // Action to view email details
                            print('Tapped on email: ${email.decodeSubject()}');
                            setState(() {
                              if (_expandedIndex == emailIndex) {
                                _expandedIndex = null; // Collapse
                              } else {
                                _expandedIndex = emailIndex; // Expand
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Action to refresh inbox
                      refreshInbox();
                    },
                    child: const Text('Refresh Inbox'),
                  ),
                ],
              ),
            ),
    );
  }
}
