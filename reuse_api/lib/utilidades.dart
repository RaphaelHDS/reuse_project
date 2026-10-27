// =====================================================================
// utilidades.dart
// Funções pequenas usadas por todas as rotas: responder em JSON, ler o
// corpo do pedido, conferir login, converter números, calcular distância...
// =====================================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'banco.dart';

// ---------------------------------------------------------------------
// ERROS
// ---------------------------------------------------------------------

/// Erro "esperado" da API (ex.: senha errada). Ele vira uma resposta JSON
/// com o código HTTP certo, por exemplo 400, 401, 404.
class ErroApi implements Exception {
  final int status;
  final String mensagem;
  ErroApi(this.status, this.mensagem);

  @override
  String toString() => 'ErroApi($status): $mensagem';
}

// ---------------------------------------------------------------------
// RESPOSTAS
// ---------------------------------------------------------------------

/// Cabeçalho que diz "a resposta é JSON com acentos (UTF-8)".
const cabecalhoJson = {'content-type': 'application/json; charset=utf-8'};

/// Responde com um JSON. Ex.: return respostaJson({'ok': true});
Response respostaJson(Object? dados, {int status = 200}) {
  return Response(status, body: jsonEncode(dados), headers: cabecalhoJson);
}

/// Responde com uma mensagem de erro em JSON: {"erro": "..."}
Response respostaErro(int status, String mensagem) {
  return respostaJson({'erro': mensagem}, status: status);
}

// ---------------------------------------------------------------------
// LER O PEDIDO
// ---------------------------------------------------------------------

/// Lê o corpo do pedido (o JSON que o app enviou) e transforma em Map.
Future<Map<String, dynamic>> lerJson(Request request) async {
  final texto = await request.readAsString();
  if (texto.trim().isEmpty) return {};
  try {
    final dados = jsonDecode(texto);
    if (dados is Map<String, dynamic>) return dados;
  } catch (_) {
    // cai no erro abaixo
  }
  throw ErroApi(400, 'Os dados enviados não estão em formato JSON válido.');
}

/// Pega um texto do JSON. Se [obrigatorio] e estiver vazio, dá erro.
String? campoTexto(
  Map<String, dynamic> dados,
  String campo, {
  bool obrigatorio = false,
  String? nomeAmigavel,
  int maximo = 255,
}) {
  final valor = dados[campo]?.toString().trim();
  if (valor == null || valor.isEmpty) {
    if (obrigatorio) {
      throw ErroApi(400, 'Preencha o campo "${nomeAmigavel ?? campo}".');
    }
    return null;
  }
  if (valor.length > maximo) {
    throw ErroApi(400,
        'O campo "${nomeAmigavel ?? campo}" pode ter no máximo $maximo caracteres.');
  }
  return valor;
}

/// Pega um número do JSON (aceita 10, 10.5 ou "10,5").
double? campoNumero(Map<String, dynamic> dados, String campo) {
  final valor = dados[campo];
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().replaceAll(',', '.'));
}

// ---------------------------------------------------------------------
// CONVERSÕES (o banco devolve tudo como texto)
// ---------------------------------------------------------------------

int? paraInt(String? valor) => valor == null ? null : int.tryParse(valor);

double? paraDouble(String? valor) =>
    valor == null ? null : double.tryParse(valor);

/// Arredonda para 2 casas decimais (ex.: 1.23456 -> 1.23).
double arredondar(double valor) => (valor * 100).roundToDouble() / 100;

/// Escreve um número do jeito brasileiro: 30.0 -> "30" e 2.5 -> "2,5".
String formatarNumero(num? valor) {
  if (valor == null) return '0';
  if (valor == valor.roundToDouble()) return valor.toInt().toString();
  return valor.toStringAsFixed(1).replaceAll('.', ',');
}

/// O MySQL devolve datas assim: "2026-10-23 14:05:00".
/// Trocamos o espaço por "T" para ficar no padrão ISO que o app entende.
String? paraDataIso(String? valor) => valor?.replaceFirst(' ', 'T');

// ---------------------------------------------------------------------
// SENHAS E LOGIN
// ---------------------------------------------------------------------

final _aleatorio = Random.secure();

/// Gera um texto aleatório em hexadecimal (0-9 e a-f).
String gerarHexAleatorio(int bytes) {
  return List.generate(bytes, (_) => _aleatorio.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// "Sal" da senha: 32 caracteres aleatórios, diferente para cada usuário.
String gerarSal() => gerarHexAleatorio(16);

/// Token de login: 64 caracteres aleatórios.
String gerarToken() => gerarHexAleatorio(32);

/// Código de recuperação de senha com 6 dígitos (ex.: 048213).
String gerarCodigo6() => _aleatorio.nextInt(1000000).toString().padLeft(6, '0');

/// Calcula o hash SHA-256 de (sal + senha).
/// É o mesmo cálculo que o script SQL faz com SHA2(CONCAT(sal, senha), 256).
String hashSenha(String sal, String senha) {
  return sha256.convert(utf8.encode(sal + senha)).toString();
}

/// Descobre QUEM está fazendo o pedido, pelo token enviado no cabeçalho
/// "Authorization: Bearer <token>". Se não tiver login válido, dá erro 401.
Future<int> usuarioLogado(Request request) async {
  final cabecalho = request.headers['authorization'] ?? '';
  final token = cabecalho.startsWith('Bearer ') ? cabecalho.substring(7) : '';
  if (token.isEmpty) {
    throw ErroApi(401, 'Você precisa estar logado.');
  }
  final sessao = await Banco.consultarUm(
    'SELECT usuario_id FROM sessoes WHERE token = :token',
    {'token': token},
  );
  final id = paraInt(sessao?['usuario_id']);
  if (id == null) {
    throw ErroApi(401, 'Sua sessão expirou. Faça login novamente.');
  }
  return id;
}

// ---------------------------------------------------------------------
// DISTÂNCIA ENTRE DOIS PONTOS (fórmula de Haversine)
// ---------------------------------------------------------------------

/// Distância em km entre duas coordenadas (latitude/longitude).
double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
  const raioTerraKm = 6371.0;
  double rad(double graus) => graus * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return raioTerraKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ---------------------------------------------------------------------
// NOTIFICAÇÕES
// ---------------------------------------------------------------------

/// Cria um aviso para o usuário (aparece no sininho do app).
Future<void> notificar(int usuarioId, String titulo, String texto) async {
  // a coluna "texto" aceita até 300 caracteres
  if (texto.length > 300) texto = '${texto.substring(0, 297)}...';
  await Banco.executar(
    'INSERT INTO notificacoes (usuario_id, titulo, texto) '
    'VALUES (:usuario, :titulo, :texto)',
    {'usuario': usuarioId, 'titulo': titulo, 'texto': texto},
  );
}
