import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/user_service.dart';
import 'package:split_ex/screens/settlement/upi_id_dialog.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(currentUserIdProvider);

      // Ensure user has a primary UPI ID before joining a room. If missing,
      // prompt the user explaining that UPI is only used to receive money
      // (not for fraud). This prompt is skippable earlier in onboarding but
      // mandatory when joining a room.
      final profile = await UserService().getUserProfile(userId);
      if (profile == null || profile.upiId == null || profile.upiId!.isEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('UPI ID Required to Join'),
            content: const Text(
                'To join a room you must add your primary UPI ID so others can settle payments with you. This is only used to receive money and will not be used for fraud or marketing.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set UPI')),
            ],
          ),
        );

        if (proceed != true) {
          return;
        }

        // Force UPI dialog (no skip) and wait for user to save.
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpiIdDialog(userId: userId, allowSkip: false),
        );

        final updated = await UserService().getUserProfile(userId);
        if (updated == null || updated.upiId == null || updated.upiId!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('UPI ID is required to join a room')),
            );
          }
          return;
        }
      }

      final room = await ref.read(roomServiceProvider).joinRoom(
        _codeController.text.trim().toUpperCase(),
        userId,
      );
      if (room == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid invite code')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined "${room.name}"!')),
          );
          context.go('/');
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the invite code shared by your roommate',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  letterSpacing: 6,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: 'XXXXXX',
                  counterText: '',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().length != 6) {
                    return 'Enter 6-character code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinRoom,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
