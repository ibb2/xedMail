import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class Email extends StatefulWidget {
  const Email({super.key, required this.email, required this.htmlBody});

  final MimeMessage? email;
  final String? htmlBody;

  @override
  State<Email> createState() => _EmailState();
}

class _EmailState extends State<Email> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.email?.decodeSubject() ?? "No Subject"),
      ),
      body: Expanded(
        child: Center(
          child: Container(
            color: Colors.white,
            child: SizedBox(
              width: 1080,
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: widget.htmlBody ?? '<p>(Empty)</p> ',
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
          ),
        ),
      ),
    );
  }
}
