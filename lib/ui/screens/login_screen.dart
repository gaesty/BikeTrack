import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';  // Updated path since they're in the same folder
import '../../main.dart';
import '../../services/password_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Attempting login with: ${_emailController.text.trim()}');
      
      // 1. Connexion standard avec Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      print('Login response: ${authResponse.user != null ? 'Success' : 'Failed'}');
      
      if (authResponse.user != null) {
        // 2. Option: vérifier le mot de passe haché stocké dans votre table users
        // Ce n'est généralement pas nécessaire mais vous pouvez l'ajouter si besoin
        try {
          // Récupérer l'utilisateur depuis votre table users
          final userData = await Supabase.instance.client
              .from('users')
              .select('password')
              .eq('id', authResponse.user!.id)
              .single();
          
          // Vérifier le mot de passe avec bcrypt
          final hashedPassword = userData['password'] as String;
          final passwordValid = await PasswordService.verifyPassword(
            _passwordController.text, 
            hashedPassword
          );
          
          if (!passwordValid) {
            // Si vous voulez être très strict, vous pouvez déconnecter l'utilisateur
            // await Supabase.instance.client.auth.signOut();
            // throw Exception('Password verification failed');
            
            // Mais généralement, la vérification Supabase Auth suffit
            print('Notice: Local password verification failed but Supabase Auth passed');
          }
        } catch (error) {
          print('Password verification error: $error');
          // Généralement pas besoin de bloquer la connexion ici
        }
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Échec de connexion: Aucun utilisateur retourné';
        });
      }
    } on AuthException catch (error) {
      print('Auth error during login: ${error.message}');
      setState(() {
        if (error.message == 'Email not confirmed') {
          _errorMessage = 'Veuillez confirmer votre email avant de vous connecter';
        } else if (error.message == 'Invalid login credentials') {
          _errorMessage = 'Email ou mot de passe incorrect';
        } else {
          _errorMessage = error.message;
        }
      });
    } catch (error) {
      print('General error during login: $error');
      setState(() {
        _errorMessage = 'Une erreur est survenue lors de la connexion';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Text(
                'BikeTrack',
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre mot de passe';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text('Se connecter', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const RegisterPage())
                  );
                },
                child: const Text("Pas encore de compte ? S'inscrire"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


