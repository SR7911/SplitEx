import 'dart:io';
import 'package:flutter/material.dart';
import 'package:split_ex/services/upload_service.dart';

class ReceiptPicker extends StatefulWidget {
  final String roomId;
  final String folder;
  final ValueChanged<String?> onUploaded;

  const ReceiptPicker({
    super.key,
    required this.roomId,
    required this.folder,
    required this.onUploaded,
  });

  @override
  State<ReceiptPicker> createState() => _ReceiptPickerState();
}

class _ReceiptPickerState extends State<ReceiptPicker> {
  final _uploadService = UploadService();
  File? _pickedFile;
  bool _uploading = false;
  String? _uploadedUrl;

  Future<void> _pick(bool fromCamera) async {
    final file = await _uploadService.pickImage(fromCamera: fromCamera);
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _uploading = true;
    });

    final url = await _uploadService.uploadReceipt(
      file: file,
      roomId: widget.roomId,
      folder: widget.folder,
    );

    setState(() => _uploading = false);

    if (url != null) {
      setState(() => _uploadedUrl = url);
      widget.onUploaded(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed — check your connection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Uploading receipt...'),
            ],
          ),
        ),
      );
    }

    if (_uploadedUrl != null) {
      return Card(
        child: ListTile(
          leading: _pickedFile != null
              ? ClipRoundedRect(file: _pickedFile!)
              : const Icon(Icons.check_circle, color: Colors.green),
          title: const Text('Receipt attached ✅'),
          subtitle: const Text('Tap to change'),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _pickedFile = null;
                _uploadedUrl = null;
              });
              widget.onUploaded(null);
            },
          ),
          onTap: () => _showPickerOptions(),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _showPickerOptions,
      icon: const Icon(Icons.attach_file),
      label: const Text('Attach Receipt (Photo/PDF)'),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ClipRoundedRect extends StatelessWidget {
  final File file;
  const ClipRoundedRect({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
}
