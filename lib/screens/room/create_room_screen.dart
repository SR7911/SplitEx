import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _inviteCode;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(currentUserIdProvider);
      final room = await ref.read(roomServiceProvider).createRoom(
            _nameController.text.trim(),
            userId,
          );
      setState(() => _inviteCode = room.inviteCode);
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
      appBar: const AppHeader(showBack: true, title: 'Create Room', showNotification: false),
      body: GradientBody(
        child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _inviteCode != null ? _buildSuccess() : _buildForm(),
        ),
      ),
      )
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.home_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Create a Room', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Give your room a name to get started', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Room Name',
              prefixIcon: const Icon(Icons.home_outlined),
              hintText: 'e.g. Flat 302',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter room name';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _createRoom,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Room Created!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Share this invite code with your roommates:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _inviteCode!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: const Text('Go to My Rooms'),
        ),
      ],
    );
  }
}
