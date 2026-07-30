import 'dart:io';
import 'package:flutter/material.dart';

class PdfThumbnailWidget extends StatelessWidget {
  final String pdfPath;
  final VoidCallback onTap;
  final bool showFileName;

  const PdfThumbnailWidget({
    super.key,
    required this.pdfPath,
    required this.onTap,
    this.showFileName = true,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = _getFileName();
    final fileSize = _getFileSize();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 40,
                    color: Colors.red[600]!,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700]!,
                    ),
                  ),
                ],
              ),
            ),
            if (showFileName)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileSize,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFileName() {
    try {
      return pdfPath.split('/').last;
    } catch (e) {
      return 'Unknown File';
    }
  }

  String _getFileSize() {
    try {
      final file = File(pdfPath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) {
          return '$bytes B';
        } else if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        } else {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return 'Unknown Size';
  }
}