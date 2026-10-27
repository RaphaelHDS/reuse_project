// =====================================================================
// tela_recuperar_senha.dart
// Passo 1: o usuário informa o e-mail e recebe um código de 6 dígitos.
// Passo 2: digita o código e a nova senha.
//
// Modo demonstração: como o projeto não envia e-mail de verdade, o
// código aparece na tela (e também no terminal da API).
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../tema.dart';
import '../widgets/comuns.dart';

class TelaRecuperarSenha extends StatefulWidget {
  const TelaRecuperarSenha({super.key});

  @override
  State<TelaRecuperarSenha> createState() => _TelaRecuperarSenhaState();
}

class _TelaRecuperarSenhaState extends State<TelaRecuperarSenha> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _novaSenha = TextEditingController();

  bool _carregando = false;
  bool _codigoEnviado = false; // false = passo 1, true = passo 2
  String? _codigoDemonstracao;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _novaSenha.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!_email.text.contains('@')) {
      mostrarMensagem(context, 'Digite seu e-mail.', erro: true);
      return;
    }
    setState(() => _carregando = true);
    try {
      final codigo = await Api.recuperarSenha(_email.text.trim());
      setState(() {
        _codigoEnviado = true;
        _codigoDemonstracao = codigo;
      });
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _redefinir() async {
    if (_codigo.text.trim().length != 6) {
      mostrarMensagem(context, 'O código tem 6 dígitos.', erro: true);
      return;
    }
    if (_novaSenha.text.length < 6) {
      mostrarMensagem(context, 'A nova senha precisa ter 6 caracteres ou mais.',
          erro: true);
      return;
    }
    setState(() => _carregando = true);
    try {
      await Api.redefinirSenha(
          _email.text.trim(), _codigo.text.trim(), _novaSenha.text);
      if (!mounted) return;
      mostrarMensagem(context, 'Senha alterada! Entre com a nova senha.');
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_reset, size: 64, color: Cores.verde.withValues(alpha: 0.8)),
                const SizedBox(height: 16),
                Text(
                  _codigoEnviado
                      ? 'Digite o código e escolha a nova senha.'
                      : 'Informe o e-mail da sua conta. Vamos gerar um código de 6 dígitos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  enabled: !_codigoEnviado,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'E-mail', prefixIcon: Icon(Icons.email)),
                ),

                if (!_codigoEnviado) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _carregando ? null : _enviarCodigo,
                    child: const Text('Enviar código'),
                  ),
                ] else ...[
                  // Caixa com o código (modo demonstração)
                  if (_codigoDemonstracao != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Cores.verdeClaro,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('Modo demonstração - seu código é:'),
                          const SizedBox(height: 4),
                          SelectableText(
                            _codigoDemonstracao!,
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                                color: Cores.verdeEscuro),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Em um app real, ele chegaria por e-mail.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: 'Código de 6 dígitos',
                        prefixIcon: Icon(Icons.pin)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _novaSenha,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Nova senha', prefixIcon: Icon(Icons.lock)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _carregando ? null : _redefinir,
                    child: const Text('Salvar nova senha'),
                  ),
                  TextButton(
                    onPressed: _carregando ? null : _enviarCodigo,
                    child: const Text('Gerar outro código'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
