import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.backend,
    required this.onChangeRole,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final VoidCallback onChangeRole;
  final bool isDemo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _creating = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.isDemo ? 'demo@guardiaogamer.app' : '');
    _password = TextEditingController(text: widget.isDemo ? 'demo1234' : '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Digite um e-mail válido.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        await widget.backend.registerParent(email, _password.text);
      } else {
        await widget.backend.signInParent(email, _password.text);
      }
      // O portão de entrada muda de tela sozinho.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo deu errado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Guardião Gamer', style: text.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      _creating
                          ? 'Crie sua conta de responsável.'
                          : 'Entre para acompanhar os jogos dos seus filhos.',
                      style: text.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('emailField'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('passwordField'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hidePassword,
                      autofillHints: [
                        _creating ? AutofillHints.newPassword : AutofillHints.password
                      ],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Mostrar senha' : 'Esconder senha',
                          icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                    ),
                    if (widget.isDemo) ...[
                      const SizedBox(height: 12),
                      const Notice('Modo demonstração, sem internet: os dados são de exemplo.'),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Notice(_error!, isError: true),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('submitButton'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_creating ? 'Criar conta' : 'Entrar'),
                    ),
                    TextButton(
                      key: const Key('toggleButton'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _creating = !_creating;
                                _error = null;
                              }),
                      child: Text(_creating
                          ? 'Já tenho conta. Entrar'
                          : 'Primeira vez aqui? Criar conta'),
                    ),
                    TextButton(
                      key: const Key('changeRoleButton'),
                      onPressed: _busy ? null : widget.onChangeRole,
                      child: const Text('Este aparelho é do filho? Voltar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
