import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grand_stock/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../exceptions/api_exception.dart';
import '../../exceptions/auth_exception.dart';
import '../../helper/server_settings_auth.dart';
import '../../manager/hash_manager.dart';
import '../../manager/assets_manager.dart';
import '../../manager/my_app_method.dart';
import '../../providers/user_provider.dart';
import '../../widgets/custom_text_field.dart';
import 'forgot_password_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final FocusNode _usernameFocusNode;
  late final FocusNode _passwordFocusNode;
  late final _formKey = GlobalKey<FormState>();
  bool obscureText = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String fcmToken = 'Waiting for token...';
  @override
  void initState() {
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _usernameFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _loadSavedCredentials();
    //_getToken();
    super.initState();
  }

/*
  Future<void> _getToken() async {
    final notificationProvider = context.read<NotificationProvider>();
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user!;
    String? token = await FirebaseMessaging.instance.getToken();
    print('token is $token');
    setState(() {
      fcmToken = token ?? 'Failed to get token';
    });
    notificationProvider.sendTokenToServer(userId: user.oid);
  }
*/

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        _usernameController.text = prefs.getString('savedUsername') ?? '';
        _passwordController.text = prefs.getString('savedPassword') ?? '';
      }
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('savedUsername', _usernameController.text.trim());
      await prefs.setString('savedPassword', _passwordController.text.trim());
    } else {
      await prefs.remove('rememberMe');
      await prefs.remove('savedUsername');
      await prefs.remove('savedPassword');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loginFct() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    if (isValid) {
      _formKey.currentState!.save();
      try {
        setState(() {
          _isLoading = true;
        });
        // Save or clear credentials based on remember me choice
        await _saveCredentials();
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final HashManager hasher = HashManager();
        final password = _passwordController.text.trim();
        final hashedPassword = hasher.hashPasswordWithMd5(password: password);
        await userProvider.login(
          username: _usernameController.text.trim(),
          password: hashedPassword,
        );
        userProvider.logAppEntry();
        Fluttertoast.showToast(
          msg: "Connexion réussie",
          toastLength: Toast.LENGTH_SHORT,
          textColor: Colors.white,
        );

        if (!mounted) return;
        // Navigate to Root Screen
        Navigator.pushReplacement(
          context,
          //MaterialPageRoute(builder: (context) => const DashboardScreen()),
          MaterialPageRoute(builder: (context) =>  HomeScreen()),
        );
      } on AuthException catch (error) {
        await MyAppMethods.showErrorORWarningDialog(
          context: context,
          subtitle: error.message,
          fct: () {},
        );
      } on ApiException catch (error) {
        await MyAppMethods.showErrorORWarningDialog(
          context: context,
          subtitle: error.message,
          fct: () {},
        );
      } catch (error) {
        print(error);
        await MyAppMethods.showErrorORWarningDialog(
          context: context,
          subtitle: "An error has occurred: $error",
          fct: () {},
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40.0),
                // Logo added here
                Image.asset(
                  AssetsManager.logo,
                  height: 250,
                  fit: BoxFit.contain,
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      CustomTextField(
                        labelText: "Nom d'utilisateur",
                        textEditingController: _usernameController,
                        hintText: "Entrez votre nom d'utilisateur",
                        customPrefixIconData: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        labelText: "Mot de passe",
                        textEditingController: _passwordController,
                        hintText: "Entrez votre mot de passe",
                        isPass: true,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text('Souviens-toi de moi'),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Mot de passe oublié?',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text(
                            "Se connecter",
                            style: TextStyle(fontSize: 20),
                          ),
                          onPressed: _loginFct,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Paramètres du serveur',
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onPressed: _isLoading
                      ? null
                      : () => ServerSettingsAuth.openProtected(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
