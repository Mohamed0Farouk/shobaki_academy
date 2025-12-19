import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfModel extends StatelessWidget {
  const PdfModel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: PdfViewer.uri(
          Uri.parse(
            'https://kuntxbhlrelempsixqfu.supabase.co/storage/v1/object/public/pdfs/Drawing%20sheet%20(2).pdf.pdf',
          ),
        ),
      ),
    );
  }
}
