import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/button.dart';
import '../components/textfield.dart';
import '../helper/helper_functions.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  void registerUser() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    if (passwordController.text != confirmPasswordController.text) {
      Navigator.pop(context);
      displayMessageToUser("As senhas não coincidem!", context);
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text,
        password: passwordController.text,
        data: {'username': usernameController.text},
      );

      if (response.user == null) {
        throw Exception("Cadastro falhou.");
      }

      await Supabase.instance.client.from('profiles').insert({
        'id': response.user!.id,
        'username': usernameController.text,
      });

      if (mounted) Navigator.pop(context);
      if (mounted) {
        displayMessageToUser("Cadastro realizado! Verifique seu email.", context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) displayMessageToUser(e.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  Icon(
                    Icons.circle,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Circle",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 50),

                  MyTextfield(
                    hintText: "Nome de usuário",
                    obscureText: false,
                    controller: usernameController,
                  ),

                  const SizedBox(height: 10),

                  MyTextfield(
                    hintText: "Email",
                    obscureText: false,
                    controller: emailController,
                  ),

                  const SizedBox(height: 10),

                  MyTextfield(
                    hintText: "Senha",
                    obscureText: true,
                    controller: passwordController,
                  ),

                  const SizedBox(height: 10),

                  MyTextfield(
                    hintText: "Confirmar senha",
                    obscureText: true,
                    controller: confirmPasswordController,
                  ),

                  const SizedBox(height: 25),

                  MyButton(text: "Cadastrar", onTap: registerUser),

                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Já tem conta?"),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Entrar",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
