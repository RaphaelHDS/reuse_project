// =====================================================================
// comuns.dart
// "Widgets" (peças de tela) usados em várias telas do app.
// =====================================================================

import 'package:flutter/material.dart';

import '../servicos/api.dart';
import '../tema.dart';

// ---------------------------------------------------------------------
// FOTO DO ANÚNCIO (ou um ícone colorido do material, se não tiver foto)
// ---------------------------------------------------------------------
class FotoAnuncio extends StatelessWidget {
  final String? fotoUrl;
  final String tipoMaterial;
  final double? largura;
  final double? altura;
  final double raio;
  final double tamanhoIcone;

  const FotoAnuncio({
    super.key,
    required this.fotoUrl,
    required this.tipoMaterial,
    this.largura,
    this.altura,
    this.raio = 12,
    this.tamanhoIcone = 36,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = tipoPorNome(tipoMaterial);
    final semFoto = Container(
      width: largura,
      height: altura,
      color: tipo.cor.withValues(alpha: 0.15),
      child: Icon(tipo.icone, color: tipo.cor, size: tamanhoIcone),
    );

    final url = Api.urlFoto(fotoUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: url == null
          ? semFoto
          : Image.network(
              url,
              width: largura,
              height: altura,
              fit: BoxFit.cover,
              // Se a foto não carregar, mostra o ícone no lugar
              errorBuilder: (context, erro, pilha) => semFoto,
              loadingBuilder: (context, filho, progresso) =>
                  progresso == null ? filho : semFoto,
            ),
    );
  }
}

// ---------------------------------------------------------------------
// SELO DE STATUS (etiqueta colorida: "Disponível", "Reservado"...)
// ---------------------------------------------------------------------
class SeloStatus extends StatelessWidget {
  final InfoStatus info;
  final bool pequeno;

  const SeloStatus(this.info, {super.key, this.pequeno = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: pequeno ? 8 : 10, vertical: pequeno ? 3 : 5),
      decoration: BoxDecoration(
        color: info.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icone, size: pequeno ? 13 : 16, color: info.cor),
          const SizedBox(width: 4),
          Text(
            info.texto,
            style: TextStyle(
              color: info.cor,
              fontWeight: FontWeight.w600,
              fontSize: pequeno ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ETIQUETA DO TIPO DE MATERIAL (ícone + nome)
// ---------------------------------------------------------------------
class EtiquetaMaterial extends StatelessWidget {
  final String tipoMaterial;
  const EtiquetaMaterial(this.tipoMaterial, {super.key});

  @override
  Widget build(BuildContext context) {
    final tipo = tipoPorNome(tipoMaterial);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(tipo.icone, size: 16, color: tipo.cor),
        const SizedBox(width: 4),
        Text(tipo.nome,
            style: TextStyle(color: tipo.cor, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// TELA VAZIA / ERRO (com botão opcional)
// ---------------------------------------------------------------------
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? texto;
  final String? textoBotao;
  final VoidCallback? aoTocarBotao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.texto,
    this.textoBotao,
    this.aoTocarBotao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (texto != null) ...[
              const SizedBox(height: 8),
              Text(texto!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
            if (textoBotao != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                  onPressed: aoTocarBotao, child: Text(textoBotao!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mostra o erro de carregamento com botão "Tentar de novo".
class ErroCarregamento extends StatelessWidget {
  final Object erro;
  final VoidCallback aoTentarDeNovo;
  const ErroCarregamento(
      {super.key, required this.erro, required this.aoTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: Icons.cloud_off,
      titulo: 'Ops! Não deu para carregar.',
      texto: erro.toString(),
      textoBotao: 'Tentar de novo',
      aoTocarBotao: aoTentarDeNovo,
    );
  }
}

/// No computador (tela larga), deixa o conteúdo centralizado com largura
/// máxima, para não ficar "esticado". No celular não muda nada.
class LarguraMaxima extends StatelessWidget {
  final Widget child;
  final double largura;
  const LarguraMaxima({super.key, required this.child, this.largura = 760});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// FUNÇÕES DE APOIO
// ---------------------------------------------------------------------

/// Mostra uma mensagem rápida na parte de baixo da tela.
void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? Cores.vermelho : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Pergunta "tem certeza?" e devolve true se o usuário confirmar.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String textoSim = 'Confirmar',
  bool perigoso = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar')),
        FilledButton(
          style: perigoso
              ? FilledButton.styleFrom(
                  backgroundColor: Cores.vermelho, minimumSize: const Size(64, 40))
              : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(textoSim),
        ),
      ],
    ),
  );
  return resposta ?? false;
}

/// Título de uma seção (ex.: "Descrição", "Local de retirada").
class TituloSecao extends StatelessWidget {
  final String texto;
  const TituloSecao(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(texto,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
