import 'package:enough_mail/discover.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/smtp.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleSignIn;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  late GoogleSignIn _googleSignIn;
  late Future<List<MimeMessage>> _emails;
  late MailClient _mailClient;

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

    _emails = fetchEmails();

    pollEmails();
  }

  Future<void> pollEmails() async {
    try {
      _mailClient.eventBus.on<MailLoadEvent>().listen((event) {
        print('New message at ${DateTime.now()}:');
        final emails = _mailClient.fetchMessages(count: 20);
        setState(() {
          _emails = Future.value(emails);
        });
      });
      await _mailClient.startPolling();
    } catch (e) {
      print('Error fetching emails: $e');
    }
  }

  Future<List<MimeMessage>> fetchEmails() async {
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
      return [];
    }
    print('connecting to ${config.displayName}.');
    if (credentials == null) {
      print('Sign in failed or cancelled');
      return [];
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
      return await _mailClient.fetchMessages(count: 20);

      // mailClient.eventBus.on<MailLoadEvent>().listen((event) {
      //   print('New message at ${DateTime.now()}:');
      // });
      // await mailClient.startPolling();
    } on MailException catch (e) {
      print('High level API failed with $e');
      return [];
    }
  }

  void refreshInbox() {
    setState(() {
      _emails = fetchEmails();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: FutureBuilder(
        future: _emails,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (asyncSnapshot.hasError) {
            return Center(child: Text('Error: ${asyncSnapshot.error}'));
          }

          final emails = asyncSnapshot.data ?? [];

          if (emails.isEmpty) {
            return const Center(child: Text('No emails found.'));
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    itemCount: emails.length,
                    itemBuilder: (context, index) {
                      final rEmails = emails.reversed.toList();
                      final email = rEmails[index];
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
                        },
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Action to refresh inbox
                    setState(() {});
                  },
                  child: const Text('Refresh Inbox'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
