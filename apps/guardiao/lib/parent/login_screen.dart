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
    _email = TextEditingController(
      text: widget.isDemo ? 'demo@guardiao.app' : '',
    );
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
    return OnboardScaffold(
      title: _creating ? 'Criar conta' : 'Entrar',
      subtitle: _creating
          ? 'Crie sua conta de responsável.'
          : 'Entre para acompanhar os jogos dos seus filhos.',
      onBack: _busy ? null : widget.onChangeRole,
      backKey: const Key('changeRoleButton'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('submitButton'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_creating ? 'Criar conta' : 'Entrar'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _creating ? 'Já tem conta?' : 'Não tem conta?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                key: const Key('toggleButton'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _creating = !_creating;
                        _error = null;
                      }),
                child: Text(_creating ? 'Entrar' : 'Criar conta'),
              ),
            ],
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GField(
              fieldKey: const Key('emailField'),
              label: 'E-mail',
              hint: 'voce@email.com',
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            GField(
              fieldKey: const Key('passwordField'),
              label: 'Senha',
              hint: 'Pelo menos 6 caracteres',
              controller: _password,
              enabled: !_busy,
              obscure: _hidePassword,
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onSubmitted: (_) => _submit(),
              suffix: TextButton(
                key: const Key('togglePassword'),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                child: Text(_hidePassword ? 'Mostrar' : 'Esconder'),
              ),
            ),
            if (widget.isDemo) ...[
              const SizedBox(height: 16),
              const Notice(
                'Modo demonstração, sem internet: os dados são de exemplo.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Notice(_error!, isError: true),
            ],
          ],
        ),
      ),
    );
  }
}
