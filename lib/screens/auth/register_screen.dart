import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final credential = await ref.read(authServiceProvider).signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      await credential.user?.updateDisplayName(_nameController.text.trim());
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Back + title
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                Text('Create Account', style: AppTextStyles.pageTitle(context)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Fill in your details to get started',
                  style: AppTextStyles.bodySmall(context),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your name';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter email';
                    if (!v.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isLoading ? null : _register(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter password';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _register,
                        child: const Text('Create Account'),
                      ),

                const SizedBox(height: AppSpacing.xxl),

                Center(
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: AppTextStyles.bodySmall(context),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
