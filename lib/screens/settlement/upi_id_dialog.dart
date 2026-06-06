import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/services/user_service.dart';

class UpiIdDialog extends ConsumerStatefulWidget {
  final String userId;
  final bool allowSkip;
  const UpiIdDialog({super.key, required this.userId, this.allowSkip = true});

  @override
  ConsumerState<UpiIdDialog> createState() => _UpiIdDialogState();
}

class _UpiIdDialogState extends ConsumerState<UpiIdDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set UPI ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add your UPI ID to receive payments from roommates.'),
          const SizedBox(height: 8),
          const Text(
            'This is only used to receive money from roommates — not for fraud or marketing. Your UPI ID will be shared only with people in rooms you join.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'yourname@upi',
              labelText: 'UPI ID',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        if (widget.allowSkip)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final upiId = _controller.text.trim();
    if (upiId.isEmpty || !upiId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID (e.g. name@upi)')),
      );
      return;
    }
    setState(() => _saving = true);
    await UserService().updateUserProfile(widget.userId, {'upiId': upiId});
    if (mounted) Navigator.pop(context);
  }
}
