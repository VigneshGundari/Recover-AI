import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import '../../user/data/user_model.dart';
import '../../user/data/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  
  void _submit() async {
    final auth = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    bool result = false;
    if (_isRegistering) {
      result = await auth.signUp(email, password);
      if (result && mounted) {
        // Create initial user doc
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userRepo = ref.read(userRepositoryProvider);
          final newUser = UserModel(uid: uid, email: email);
          await userRepo.createUser(newUser);
        }
      }
    } else {
      result = await auth.signIn(email, password);
    }
    
    if (!result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication Failed')));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Column(
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    'Recover AI',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
              enabled: !isLoading,
            ),
            const SizedBox(height: 32),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: Text(_isRegistering ? 'Register' : 'Login'),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Or continue with", style: TextStyle(color: Colors.white54)),
                      ),
                      Expanded(child: Divider(color: Colors.white12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase Native Google Sign-In Requires Deployment')));
                        },
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase Phone OTP Requires SMS Billing Configuration')));
                        },
                        icon: const Icon(Icons.phone_iphone, size: 20),
                        label: const Text('Phone'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            TextButton(
              onPressed: isLoading ? null : () => setState(() => _isRegistering = !_isRegistering),
              child: Text(_isRegistering ? 'Already have an account? Login' : 'Need an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
