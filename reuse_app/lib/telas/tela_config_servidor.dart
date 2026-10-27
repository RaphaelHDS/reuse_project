// =====================================================================
// tela_config_servidor.dart
// Muda o endereço da API sem precisar mexer no código.
// No celular, use o endereço que aparece no terminal da API, por ex.:
//     No celular (mesmo Wi-Fi): http://192.168.0.15:8080
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import '../widgets/comuns.dart';

class TelaConfigServidor extends StatefulWidget {
  const TelaConfigServidor({super.key});

  @override
  State<TelaConfigServidor> createState() => _TelaConfigServidorState();
}

class _TelaConfigServidorState extends State<TelaConfigServidor> {
  final _url = TextEditingController(text: Api.urlBase);
  bool _testando = false;
  bool? _funcionou; // null = ainda não testou

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _funcionou = null;
    });
    var url = _url.text.trim();
    if (!url.startsWith('http')) url = 'http://$url';
    final ok = await Api.testarConexao(url);
    if (mounted) {
      setState(() {
        _testando = false;
        _funcionou = ok;
      });
    }
  }

  Future<void> _salvar() async {
    await Sessao.salvarUrl(_url.text);
    if (!mounted) return;
    mostrarMensagem(context, 'Servidor salvo: ${Api.urlBase}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Endereço do servidor')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Endereço da API',
              hintText: 'http://192.168.0.15:8080',
              prefixIcon: Icon(Icons.dns),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Chrome: localhost'),
                onPressed: () => _url.text = 'http://localhost:8080',
              ),
              ActionChip(
                label: const Text('Emulador: 10.0.2.2'),
                onPressed: () => _url.text = 'http://10.0.2.2:8080',
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _testando ? null : _testar,
            icon: _testando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find),
            label: const Text('Testar conexão'),
          ),
          if (_funcionou != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_funcionou! ? Icons.check_circle : Icons.error,
                    color: _funcionou! ? Cores.verde : Cores.vermelho),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_funcionou!
                      ? 'Conectou! A API do ReUse respondeu.'
                      : 'Não conectou. Confira o endereço e se a API está ligada.'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _salvar, child: const Text('Salvar')),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Qual endereço usar?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text('- No Chrome (computador): http://localhost:8080'),
                  const SizedBox(height: 4),
                  const Text(
                      '- No celular: o endereço que aparece no terminal da API, na linha '
                      '"No celular (mesmo Wi-Fi)". Ex.: http://192.168.0.15:8080'),
                  const SizedBox(height: 4),
                  const Text(
                      '- O celular e o computador precisam estar no MESMO Wi-Fi.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
