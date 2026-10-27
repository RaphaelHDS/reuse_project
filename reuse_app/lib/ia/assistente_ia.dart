// =====================================================================
// assistente_ia.dart  -  O DIFERENCIAL: "IA" QUE ANALISA A FOTO
// ---------------------------------------------------------------------
// IMPORTANTE (para a apresentação): esta é uma IA SIMULADA, que funciona
// sem internet e sem custo. Ela faz duas coisas:
//
//  1) "Olha" a foto: reduz a imagem para 40x40 pixels e analisa as cores
//     (matiz, saturação e brilho) de cada pixel. Cada pixel "vota" no
//     material mais provável. Ex.: tons de marrom -> madeira;
//     cinza -> metal; azul forte -> plástico; muitas cores -> tecido.
//  2) Consulta uma BASE DE CONHECIMENTO (abaixo) com ideias de
//     reutilização e possíveis interessados para cada material.
//
// O usuário sempre confere e pode corrigir o tipo antes de publicar.
// Numa versão futura, a função analisarFoto() pode ser trocada por uma
// IA de verdade (ex.: um modelo de visão computacional na nuvem).
// =====================================================================

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// O que a IA "sabe" sobre cada tipo de material.
class ConhecimentoMaterial {
  final String tipo;
  final String tituloSugerido;
  final List<String> reutilizacoes; // formas de reaproveitar
  final List<String> destinatarios; // quem pode se interessar
  final String dica; // cuidado na hora de anunciar/entregar

  /// Peso médio aproximado (kg) de 1 unidade, 1 metro e 1 m².
  /// Usado para estimar o peso quando o usuário não sabe.
  final double kgPorUnidade;
  final double kgPorMetro;
  final double kgPorM2;

  const ConhecimentoMaterial({
    required this.tipo,
    required this.tituloSugerido,
    required this.reutilizacoes,
    required this.destinatarios,
    required this.dica,
    required this.kgPorUnidade,
    required this.kgPorMetro,
    required this.kgPorM2,
  });
}

/// Resultado da análise de uma foto.
class ResultadoIA {
  final String tipo; // material mais provável
  final int confianca; // 0 a 100 (%)
  final List<String> alternativas; // outros materiais possíveis
  final Color corPredominante; // cor média da foto
  final ConhecimentoMaterial info;

  const ResultadoIA({
    required this.tipo,
    required this.confianca,
    required this.alternativas,
    required this.corPredominante,
    required this.info,
  });
}

class AssistenteIA {
  // -------------------------------------------------------------------
  // BASE DE CONHECIMENTO
  // -------------------------------------------------------------------
  static const base = <String, ConhecimentoMaterial>{
    'Madeira': ConhecimentoMaterial(
      tipo: 'Madeira',
      tituloSugerido: 'Sobras de madeira',
      reutilizacoes: [
        'Móveis pequenos, bancos e prateleiras',
        'Caixas organizadoras e porta-objetos',
        'Brinquedos e peças de artesanato',
        'Canteiros e hortas',
        'Lenha ou serragem para compostagem (se não tiver tinta)',
      ],
      destinatarios: [
        'Marcenarias',
        'Escolas técnicas',
        'Artesãos',
        'Hortas comunitárias',
        'ONGs de construção',
      ],
      dica: 'Retire pregos e parafusos e informe se a madeira tem tinta ou verniz.',
      kgPorUnidade: 2.0,
      kgPorMetro: 0.8,
      kgPorM2: 7.0,
    ),
    'Tecido': ConhecimentoMaterial(
      tipo: 'Tecido',
      tituloSugerido: 'Retalhos de tecido',
      reutilizacoes: [
        'Patchwork e colchas',
        'Bolsas, ecobags e necessaires',
        'Bonecas e brinquedos de pano',
        'Enchimento de almofadas e pufes',
        'Panos de limpeza',
      ],
      destinatarios: [
        'Costureiras e ateliês',
        'Artesãos',
        'Projetos sociais de costura',
        'Escolas (aulas de arte)',
        'Abrigos de animais',
      ],
      dica: 'Separe por tipo (algodão, malha, jeans) e informe se está limpo.',
      kgPorUnidade: 0.2,
      kgPorMetro: 0.15,
      kgPorM2: 0.2,
    ),
    'Metal': ConhecimentoMaterial(
      tipo: 'Metal',
      tituloSugerido: 'Sobras de metal',
      reutilizacoes: [
        'Peças para serralheria e consertos',
        'Esculturas e decoração',
        'Suportes, ganchos e estruturas',
        'Venda para reciclagem (gera renda)',
      ],
      destinatarios: [
        'Serralherias',
        'Oficinas mecânicas',
        'Artistas plásticos',
        'Cooperativas de reciclagem',
        'Escolas técnicas',
      ],
      dica: 'Avise se há pontas cortantes ou ferrugem. Use luvas ao manusear.',
      kgPorUnidade: 1.0,
      kgPorMetro: 1.2,
      kgPorM2: 8.0,
    ),
    'Plástico': ConhecimentoMaterial(
      tipo: 'Plástico',
      tituloSugerido: 'Plásticos para reaproveitar',
      reutilizacoes: [
        'Hortas verticais com garrafas PET',
        'Vasos e regadores',
        'Brinquedos e projetos escolares',
        'Organizadores e porta-lápis',
        'Envio para reciclagem',
      ],
      destinatarios: [
        'Escolas',
        'Hortas comunitárias',
        'Artesãos',
        'Cooperativas de reciclagem',
        'Projetos de educação ambiental',
      ],
      dica: 'Lave e seque antes de entregar. Informe o tipo (PET, PP, PEAD).',
      kgPorUnidade: 0.05,
      kgPorMetro: 0.2,
      kgPorM2: 1.0,
    ),
    'Papel e papelão': ConhecimentoMaterial(
      tipo: 'Papel e papelão',
      tituloSugerido: 'Papel e papelão',
      reutilizacoes: [
        'Caixas para mudança e organização',
        'Embalagem de produtos de pequenos negócios',
        'Material escolar e maquetes',
        'Compostagem (papel sem tinta)',
      ],
      destinatarios: [
        'Pequenos comércios e lojas online',
        'Escolas',
        'Pessoas em mudança',
        'Cooperativas de reciclagem',
      ],
      dica: 'Mantenha seco: papelão molhado perde a utilidade.',
      kgPorUnidade: 0.3,
      kgPorMetro: 0.2,
      kgPorM2: 0.5,
    ),
    'Vidro': ConhecimentoMaterial(
      tipo: 'Vidro',
      tituloSugerido: 'Potes e garrafas de vidro',
      reutilizacoes: [
        'Potes para alimentos e temperos',
        'Velas artesanais e decoração',
        'Terrários e vasos',
        'Embalagem para produtos caseiros (doces, conservas)',
      ],
      destinatarios: [
        'Artesãos',
        'Pequenos produtores de alimentos',
        'Feiras e lojas a granel',
        'Cooperativas de reciclagem',
      ],
      dica: 'Embale bem para não quebrar e avise se algum item estiver trincado.',
      kgPorUnidade: 0.3,
      kgPorMetro: 1.0,
      kgPorM2: 10.0,
    ),
    'Embalagens': ConhecimentoMaterial(
      tipo: 'Embalagens',
      tituloSugerido: 'Embalagens reaproveitáveis',
      reutilizacoes: [
        'Proteção para envios (plástico bolha, isopor)',
        'Organização e armazenamento',
        'Projetos de arte e maquetes',
        'Reciclagem correta',
      ],
      destinatarios: [
        'Lojas online e pequenos negócios',
        'Escolas',
        'Artesãos',
        'Cooperativas de reciclagem',
      ],
      dica: 'Informe se estão limpas e sem resíduos de alimentos.',
      kgPorUnidade: 0.1,
      kgPorMetro: 0.1,
      kgPorM2: 0.3,
    ),
    'Outros': ConhecimentoMaterial(
      tipo: 'Outros',
      tituloSugerido: 'Material para reaproveitar',
      reutilizacoes: [
        'Projetos de artesanato',
        'Doação para quem precisa',
        'Uso em oficinas e escolas',
        'Encaminhar para reciclagem',
      ],
      destinatarios: [
        'Artesãos',
        'Escolas',
        'ONGs e projetos sociais',
        'Cooperativas de reciclagem',
      ],
      dica: 'Descreva bem o material e o estado dele para atrair interessados.',
      kgPorUnidade: 0.5,
      kgPorMetro: 0.3,
      kgPorM2: 1.0,
    ),
  };

  /// Informações de um tipo (se não existir, usa "Outros").
  static ConhecimentoMaterial infoDoTipo(String? tipo) =>
      base[tipo] ?? base['Outros']!;

  /// Estima o peso em kg a partir da quantidade e da unidade.
  static double estimarPeso(String tipo, double quantidade, String unidade) {
    final info = infoDoTipo(tipo);
    double kg;
    switch (unidade) {
      case 'kg':
        kg = quantidade;
      case 'litros':
        kg = quantidade * 1.0; // aproximação: 1 litro ~ 1 kg
      case 'metros':
        kg = quantidade * info.kgPorMetro;
      case 'm²':
        kg = quantidade * info.kgPorM2;
      default: // unidades
        kg = quantidade * info.kgPorUnidade;
    }
    return (kg * 10).roundToDouble() / 10; // 1 casa decimal
  }

  // -------------------------------------------------------------------
  // ANÁLISE DA FOTO
  // -------------------------------------------------------------------
  static Future<ResultadoIA> analisarFoto(Uint8List bytesDaFoto) async {
    // Pausa curta só para a animação "Analisando..." aparecer
    final espera = Future<void>.delayed(const Duration(milliseconds: 1200));

    final votos = <String, double>{for (final tipo in base.keys) tipo: 0};
    final faixasDeCor = List<int>.filled(12, 0); // para medir "variedade"
    var somaR = 0, somaG = 0, somaB = 0, pixelsContados = 0, pixelsColoridos = 0;

    try {
      // 1) Reduz a foto para 40x40 pixels (fica muito rápido de analisar)
      final codec = await ui.instantiateImageCodec(
        bytesDaFoto,
        targetWidth: 40,
        targetHeight: 40,
      );
      final quadro = await codec.getNextFrame();
      final dados =
          await quadro.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (dados == null) throw Exception('sem pixels');

      // 2) Cada pixel tem 4 valores: vermelho, verde, azul e transparência
      for (var i = 0; i + 3 < dados.lengthInBytes; i += 4) {
        final r = dados.getUint8(i);
        final g = dados.getUint8(i + 1);
        final b = dados.getUint8(i + 2);
        final a = dados.getUint8(i + 3);
        if (a < 128) continue; // ignora partes transparentes

        somaR += r;
        somaG += g;
        somaB += b;
        pixelsContados++;

        // Converte para HSV: matiz (0-360), saturação (0-1), brilho (0-1)
        final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
        final matiz = hsv.hue, sat = hsv.saturation, brilho = hsv.value;

        if (brilho < 0.15) continue; // sombra muito escura: não ajuda

        if (sat >= 0.25) {
          pixelsColoridos++;
          faixasDeCor[(matiz ~/ 30) % 12]++;
        }
        _votar(votos, matiz, sat, brilho);
      }
    } catch (_) {
      // Formato de foto que não deu para ler: a IA não consegue opinar
      await espera;
      return ResultadoIA(
        tipo: 'Outros',
        confianca: 30,
        alternativas: const ['Madeira', 'Plástico'],
        corPredominante: Colors.grey,
        info: infoDoTipo('Outros'),
      );
    }

    // 3) Muitas cores diferentes na mesma foto lembra tecido estampado
    if (pixelsColoridos > 0) {
      final faixasFortes =
          faixasDeCor.where((qtd) => qtd > pixelsColoridos * 0.08).length;
      if (faixasFortes >= 3) votos['Tecido'] = votos['Tecido']! + pixelsColoridos * 0.6;
    }

    // 4) Ordena os materiais do mais votado para o menos votado
    final ranking = votos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalVotos = votos.values.fold<double>(0, (soma, v) => soma + v);
    final vencedor = totalVotos == 0 ? 'Outros' : ranking.first.key;

    // Confiança: quanto maior a vantagem do 1º lugar, mais confiante
    final participacao = totalVotos == 0 ? 0.0 : ranking.first.value / totalVotos;
    final confianca = (45 + participacao * 50).clamp(35, 94).round();

    final corMedia = pixelsContados == 0
        ? Colors.grey
        : Color.fromARGB(255, somaR ~/ pixelsContados, somaG ~/ pixelsContados,
            somaB ~/ pixelsContados);

    await espera;
    return ResultadoIA(
      tipo: vencedor,
      confianca: confianca,
      alternativas: ranking
          .skip(1)
          .where((e) => e.value > 0)
          .take(2)
          .map((e) => e.key)
          .toList(),
      corPredominante: corMedia,
      info: infoDoTipo(vencedor),
    );
  }

  /// Regras simples: cada pixel dá "votos" para os materiais parecidos.
  static void _votar(Map<String, double> votos, double matiz, double sat, double brilho) {
    void voto(String tipo, double peso) => votos[tipo] = votos[tipo]! + peso;

    // Pouca cor (cinza, branco, prata)
    if (sat < 0.12) {
      if (brilho > 0.85) {
        voto('Papel e papelão', 0.4); // branco: papel, isopor, plástico
        voto('Embalagens', 0.35);
        voto('Plástico', 0.25);
      } else {
        voto('Metal', 0.75); // cinza: metal
        voto('Vidro', 0.25);
      }
      return;
    }

    // Tons de marrom, bege e laranja (matiz 15° a 50°)
    if (matiz >= 15 && matiz < 50) {
      if (sat < 0.45 && brilho >= 0.6) {
        voto('Papel e papelão', 0.6); // bege claro: papelão
        voto('Madeira', 0.4);
      } else if (brilho < 0.72) {
        voto('Madeira', 0.8); // marrom: madeira
        voto('Papel e papelão', 0.2);
      } else {
        voto('Madeira', 0.5);
        voto('Embalagens', 0.3);
        voto('Tecido', 0.2);
      }
      return;
    }

    // Amarelo (50° a 75°)
    if (matiz >= 50 && matiz < 75) {
      voto('Embalagens', 0.5);
      voto('Plástico', 0.3);
      voto('Madeira', 0.2);
      return;
    }

    // Verde (75° a 170°)
    if (matiz >= 75 && matiz < 170) {
      voto('Vidro', 0.5);
      voto('Plástico', 0.4);
      voto('Tecido', 0.1);
      return;
    }

    // Azul e ciano (170° a 260°)
    if (matiz >= 170 && matiz < 260) {
      voto('Plástico', 0.7);
      voto('Vidro', 0.2);
      voto('Tecido', 0.1);
      return;
    }

    // Roxo, rosa, vermelho
    voto('Tecido', 0.6);
    voto('Plástico', 0.4);
  }
}
