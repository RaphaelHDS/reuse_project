// =====================================================================
// tela_perfil.dart  (aba "Perfil")
// Dados do usuário, resumo do impacto e atalhos:
// meus anúncios, painel de impacto, editar perfil, servidor e sair.
// =====================================================================

import 'package:flutter/material.dart';

import '../modelos/outros_modelos.dart';
import '../servicos/api.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';
import 'tela_config_servidor.dart';
import 'tela_editar_perfil.dart';
import 'tela_impacto.dart';
import 'tela_login.dart';
import 'tela_meus_anuncios.dart';

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  Impacto? _impacto;

  @override
  void initState() {
    super.initState();
    _carregarImpacto();
  }

  Future<void> _carregarImpacto() async {
    try {
      final impacto = await Api.impacto();
      if (mounted) setState(() => _impacto = impacto);
    } catch (_) {
      // sem conexão: só não mostra os números
    }
  }

  Future<void> _sair() async {
    final certeza = await confirmar(context,
        titulo: 'Sair da conta?', texto: 'Você precisará entrar de novo.',
        textoSim: 'Sair');
    if (!certeza) return;
    await Api.logout();
    await Sessao.sair();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (_) => false,
    );
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    if (mounted) setState(() {}); // atualiza (ex.: nome editado)
    _carregarImpacto();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Sessao.usuario;
    if (usuario == null) return const SizedBox();

    return LarguraMaxima(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabeçalho com "avatar" e nome
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Cores.verde,
                    child: Text(usuario.inicial,
                        style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(usuario.nome,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(usuario.email,
                            style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            SeloStatus(
                              InfoStatus(
                                usuario.ehEmpresa ? 'Empresa' : 'Pessoa',
                                Cores.verde,
                                usuario.ehEmpresa ? Icons.store : Icons.person,
                              ),
                              pequeno: true,
                            ),
                            if (usuario.cidade != null)
                              SeloStatus(
                                InfoStatus(usuario.cidade!, Cores.cinza,
                                    Icons.location_city),
                                pequeno: true,
                              ),
                          ],
                        ),
                        if (usuario.ramoAtividade != null) ...[
                          const SizedBox(height: 4),
                          Text('Ramo: ${usuario.ramoAtividade}',
                              style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Resumo do meu impacto
          if (_impacto != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _numero('Doados', formatarKg(_impacto!.kgDoados), Icons.upload),
                const SizedBox(width: 8),
                _numero('Recebidos', formatarKg(_impacto!.kgRecebidos), Icons.download),
                const SizedBox(width: 8),
                _numero('Anúncios ativos', '${_impacto!.anunciosAtivos}',
                    Icons.inventory_2),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _opcao(Icons.inventory_2_outlined, 'Meus anúncios',
                    () => _abrir(const TelaMeusAnuncios())),
                _opcao(Icons.eco_outlined, 'Painel de impacto',
                    () => _abrir(const TelaImpacto())),
                _opcao(Icons.edit_outlined, 'Editar perfil',
                    () => _abrir(const TelaEditarPerfil())),
                _opcao(Icons.dns_outlined, 'Servidor (${Api.urlBase})',
                    () => _abrir(const TelaConfigServidor())),
                _opcao(Icons.info_outline, 'Sobre o ReUse', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'ReUse',
                    applicationVersion: '1.0.0',
                    applicationIcon:
                        const Icon(Icons.recycling, color: Cores.verde, size: 40),
                    children: const [
                      Text(
                        'Plataforma para reaproveitamento de materiais: conecta quem '
                        'tem materiais sobrando com quem pode reutilizá-los.\n\n'
                        'Contribui para o ODS 12 (consumo e produção responsáveis).\n\n'
                        'Projeto acadêmico - Engenharia de Software - UMC 2026.',
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Cores.vermelho),
            onPressed: _sair,
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _numero(String rotulo, String valor, IconData icone) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Icon(icone, color: Cores.verde),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(rotulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcao(IconData icone, String texto, VoidCallback aoTocar) {
    return ListTile(
      leading: Icon(icone, color: Cores.verde),
      title: Text(texto, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: aoTocar,
    );
  }
}
