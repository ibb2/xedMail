import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:html/parser.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  late GoogleSignIn _googleSignIn;
  late MailClient _mailClient;

  int? _expandedIndex;
  List<MimeMessage> _emails = [];
  StreamSubscription<MailLoadEvent>? _mailSubscription;
  final Map<int, String> _decodedHtmlBodies = {};

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

    initMail();
  }

  /// High level mail API example
  Future<void> initMail() async {
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
