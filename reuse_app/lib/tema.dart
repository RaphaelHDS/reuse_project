// =====================================================================
// tema.dart
// Cores, ícones e estilo visual do app. Quer mudar a cor principal?
// Troque Cores.verde aqui e o app inteiro muda.
// =====================================================================

import 'package:flutter/material.dart';

class Cores {
  static const verde = Color(0xFF2E7D32); // cor principal
  static const verdeEscuro = Color(0xFF1B5E20);
  static const verdeClaro = Color(0xFFE8F5E9);
  static const laranja = Color(0xFFEF6C00);
  static const vermelho = Color(0xFFC62828);
  static const azul = Color(0xFF1565C0);
  static const cinza = Color(0xFF757575);
}

/// Monta o tema (visual) do app usando Material 3.
ThemeData criarTema() {
  final esquema = ColorScheme.fromSeed(seedColor: Cores.verde);
  final cantos = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: const Color(0xFFF7F9F7),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF7F9F7),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: cantos),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: cantos,
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: cantos),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: cantos),
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// TIPOS DE MATERIAL
// Os textos precisam ser IGUAIS aos da API (rotas_anuncios.dart).
// ---------------------------------------------------------------------

class TipoMaterial {
  final String nome;
  final IconData icone;
  final Color cor;
  const TipoMaterial(this.nome, this.icone, this.cor);
}

const tiposMaterial = <TipoMaterial>[
  TipoMaterial('Madeira', Icons.carpenter, Color(0xFF8D6E63)),
  TipoMaterial('Tecido', Icons.checkroom, Color(0xFFAB47BC)),
  TipoMaterial('Metal', Icons.hardware, Color(0xFF607D8B)),
  TipoMaterial('Plástico', Icons.local_drink, Color(0xFF039BE5)),
  TipoMaterial('Papel e papelão', Icons.inventory_2, Color(0xFFC08A3E)),
  TipoMaterial('Vidro', Icons.wine_bar, Color(0xFF00897B)),
  TipoMaterial('Embalagens', Icons.takeout_dining, Color(0xFFFB8C00)),
  TipoMaterial('Outros', Icons.category, Color(0xFF9E9E9E)),
];

/// Procura as informações (ícone e cor) de um tipo pelo nome.
TipoMaterial tipoPorNome(String? nome) {
  return tiposMaterial.firstWhere(
    (t) => t.nome == nome,
    orElse: () => tiposMaterial.last, // "Outros"
  );
}

/// Unidades aceitas pela API.
const unidades = ['kg', 'unidades', 'metros', 'm²', 'litros'];

/// Estados de conservação: valor no banco -> texto bonito.
const estadosConservacao = {
  'novo': 'Novo',
  'bom': 'Bom',
  'regular': 'Regular',
  'desgastado': 'Desgastado',
};

// ---------------------------------------------------------------------
// STATUS (texto e cor de cada situação)
// ---------------------------------------------------------------------

class InfoStatus {
  final String texto;
  final Color cor;
  final IconData icone;
  const InfoStatus(this.texto, this.cor, this.icone);
}

/// Status do anúncio: disponivel -> reservado -> retirado
InfoStatus statusAnuncio(String? status) {
  switch (status) {
    case 'reservado':
      return const InfoStatus('Reservado', Cores.laranja, Icons.schedule);
    case 'retirado':
      return const InfoStatus('Retirado', Cores.cinza, Icons.task_alt);
    default:
      return const InfoStatus('Disponível', Cores.verde, Icons.check_circle);
  }
}

/// Status do pedido de retirada.
InfoStatus statusPedido(String? status) {
  switch (status) {
    case 'aceita':
      return const InfoStatus('Aceito', Cores.verde, Icons.thumb_up);
    case 'recusada':
      return const InfoStatus('Recusado', Cores.vermelho, Icons.block);
    case 'concluida':
      return const InfoStatus('Retirada concluída', Cores.azul, Icons.task_alt);
    case 'cancelada':
      return const InfoStatus('Cancelado', Cores.cinza, Icons.cancel);
    default:
      return const InfoStatus('Aguardando resposta', Cores.laranja, Icons.hourglass_top);
  }
}
