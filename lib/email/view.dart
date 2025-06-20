import 'package:enough_mail/imap.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/material.dart';

class EmailViewer extends StatelessWidget {
  const EmailViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return MimeMessageViewer(mimeMessage: MimeMessage());
  }
}
