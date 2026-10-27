// =====================================================================
// tela_login.dart
// Entrar com e-mail e senha. Daqui também dá para criar conta,
// recuperar a senha e trocar o endereço do servidor.
// =====================================================================

import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../widgets/comuns.dart';
import 'tela_cadastro.dart';
import 'tela_carregando.dart';
import 'tela_config_servidor.dart';
import 'tela_principal.dart';
import 'tela_recuperar_senha.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrarSenha = false;
  bool _carregando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    // Confere se os campos foram preenchidos
    if (!_formulario.currentState!.validate()) return;

    setState(() => _carregando = true);
    try {
      final resultado = await Api.login(_email.text.trim(), _senha.text);
      await Sessao.salvarLogin(resultado.token, resultado.usuario);
      if (!mounted) return;
      // Vai para a tela principal e "apaga" o login do histórico
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaPrincipal()),
        (_) => false,
      );
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Preenche com uma conta de teste (para apresentar o projeto).
  void _usarContaTeste(String email) {
    _email.text = email;
    _senha.text = Config.senhaDeTeste;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // No computador, não deixa o formulário ficar largo demais
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LogoReUse(),
                    const SizedBox(height: 6),
                    Text(
                      'Reaproveite materiais. Evite resíduos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (valor) =>
                          (valor == null || !valor.contains('@'))
                              ? 'Digite seu e-mail'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _senha,
                      obscureText: !_mostrarSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_mostrarSenha
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _mostrarSenha = !_mostrarSenha),
                        ),
                      ),
                      onFieldSubmitted: (_) => _entrar(),
                      validator: (valor) => (valor == null || valor.isEmpty)
                          ? 'Digite sua senha'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaRecuperarSenha()),
                        ),
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelaCadastro()),
                      ),
                      child: const Text('Criar conta'),
                    ),

                    // ---- Contas de teste (ajuda na apresentação) ----
                    const SizedBox(height: 28),
                    Text('Contas de teste (senha 123456):',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final conta in Config.contasDeTeste.entries)
                          ActionChip(
                            label: Text(conta.key),
                            onPressed: () => _usarContaTeste(conta.value),
                          ),
                      ],
                    ),

                    // ---- Endereço do servidor ----
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaConfigServidor()),
                        );
                        setState(() {}); // atualiza o endereço mostrado
                      },
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text('Servidor: ${Api.urlBase}'),
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
