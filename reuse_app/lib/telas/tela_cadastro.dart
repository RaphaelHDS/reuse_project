// =====================================================================
// tela_cadastro.dart
// Criar conta de PESSOA ou de EMPRESA.
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../widgets/comuns.dart';
import 'tela_principal.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formulario = GlobalKey<FormState>();
  String _tipo = 'pessoa'; // 'pessoa' ou 'empresa'
  bool _carregando = false;

  // Um "controller" para cada campo de texto
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _cidade = TextEditingController();
  final _cnpj = TextEditingController();
  final _ramo = TextEditingController();
  final _senha = TextEditingController();
  final _confirmarSenha = TextEditingController();

  @override
  void dispose() {
    for (final campo in [
      _nome, _email, _telefone, _cidade, _cnpj, _ramo, _senha, _confirmarSenha
    ]) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() => _carregando = true);
    try {
      final resultado = await Api.cadastrar({
        'tipo': _tipo,
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'telefone': _telefone.text.trim(),
        'cidade': _cidade.text.trim(),
        'senha': _senha.text,
        if (_tipo == 'empresa') 'cnpj': _cnpj.text.trim(),
        if (_tipo == 'empresa') 'ramo_atividade': _ramo.text.trim(),
      });
      await Sessao.salvarLogin(resultado.token, resultado.usuario);
      if (!mounted) return;
      // Guarda o "mensageiro" antes de trocar de tela
      final mensageiro = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaPrincipal()),
        (_) => false,
      );
      mensageiro.showSnackBar(
          const SnackBar(content: Text('Conta criada! Bem-vindo(a) ao ReUse.')));
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Validação simples: campo obrigatório.
  String? _obrigatorio(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final ehEmpresa = _tipo == 'empresa';
    const espaco = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Você é:'),
                  const SizedBox(height: 8),
                  // Botões lado a lado para escolher Pessoa ou Empresa
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'pessoa',
                          icon: Icon(Icons.person),
                          label: Text('Pessoa')),
                      ButtonSegment(
                          value: 'empresa',
                          icon: Icon(Icons.store),
                          label: Text('Empresa')),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (escolha) =>
                        setState(() => _tipo = escolha.first),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: ehEmpresa ? 'Nome da empresa' : 'Nome completo',
                      prefixIcon: Icon(ehEmpresa ? Icons.store : Icons.person),
                    ),
                    validator: _obrigatorio,
                  ),
                  espaco,
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'E-mail', prefixIcon: Icon(Icons.email)),
                    validator: (v) => (v == null || !v.contains('@') || !v.contains('.'))
                        ? 'Digite um e-mail válido'
                        : null,
                  ),
                  espaco,
                  TextFormField(
                    controller: _telefone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp (com DDD)',
                      hintText: '(11) 98888-0000',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  espaco,
                  TextFormField(
                    controller: _cidade,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Cidade', prefixIcon: Icon(Icons.location_city)),
                  ),

                  // Campos que só aparecem para empresa
                  if (ehEmpresa) ...[
                    espaco,
                    TextFormField(
                      controller: _cnpj,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'CNPJ (opcional)', prefixIcon: Icon(Icons.badge)),
                    ),
                    espaco,
                    TextFormField(
                      controller: _ramo,
                      decoration: const InputDecoration(
                        labelText: 'Ramo de atividade',
                        hintText: 'Ex.: Marcenaria, Confecção, Escola',
                        prefixIcon: Icon(Icons.work),
                      ),
                    ),
                  ],

                  espaco,
                  TextFormField(
                    controller: _senha,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Senha (mínimo 6 caracteres)',
                        prefixIcon: Icon(Icons.lock)),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'A senha precisa ter pelo menos 6 caracteres'
                        : null,
                  ),
                  espaco,
                  TextFormField(
                    controller: _confirmarSenha,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) =>
                        v != _senha.text ? 'As senhas não são iguais' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _carregando ? null : _cadastrar,
                    child: _carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
