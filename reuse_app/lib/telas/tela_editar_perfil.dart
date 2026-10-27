// =====================================================================
// tela_editar_perfil.dart
// Altera nome, telefone, cidade (e dados de empresa).
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../widgets/comuns.dart';

class TelaEditarPerfil extends StatefulWidget {
  const TelaEditarPerfil({super.key});

  @override
  State<TelaEditarPerfil> createState() => _TelaEditarPerfilState();
}

class _TelaEditarPerfilState extends State<TelaEditarPerfil> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = Sessao.usuario!;
  late final _nome = TextEditingController(text: _usuario.nome);
  late final _telefone = TextEditingController(text: _usuario.telefone ?? '');
  late final _cidade = TextEditingController(text: _usuario.cidade ?? '');
  late final _cnpj = TextEditingController(text: _usuario.cnpj ?? '');
  late final _ramo = TextEditingController(text: _usuario.ramoAtividade ?? '');
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_nome, _telefone, _cidade, _cnpj, _ramo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final atualizado = await Api.atualizarPerfil({
        'nome': _nome.text.trim(),
        'telefone': _telefone.text.trim(),
        'cidade': _cidade.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'ramo_atividade': _ramo.text.trim(),
      });
      await Sessao.atualizarUsuario(atualizado);
      if (!mounted) return;
      mostrarMensagem(context, 'Perfil atualizado!');
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const espaco = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: LarguraMaxima(
        largura: 520,
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              espaco,
              TextFormField(
                controller: _telefone,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Telefone / WhatsApp (com DDD)'),
              ),
              espaco,
              TextFormField(
                controller: _cidade,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
              if (_usuario.ehEmpresa) ...[
                espaco,
                TextFormField(
                  controller: _cnpj,
                  decoration: const InputDecoration(labelText: 'CNPJ'),
                ),
                espaco,
                TextFormField(
                  controller: _ramo,
                  decoration: const InputDecoration(labelText: 'Ramo de atividade'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
