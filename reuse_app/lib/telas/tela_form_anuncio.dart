// =====================================================================
// tela_form_anuncio.dart
// Formulário para CRIAR ou EDITAR um anúncio:
//   foto (câmera/galeria) + análise da IA, título, tipo, descrição,
//   quantidade, peso, estado de conservação e local de retirada.
// =====================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../ia/assistente_ia.dart';
import '../modelos/anuncio.dart';
import '../servicos/api.dart';
import '../servicos/localizacao.dart';
import '../tema.dart';
import '../util/formatar.dart';
import '../widgets/comuns.dart';
import '../widgets/painel_ia.dart';
import 'tela_escolher_local.dart';

class TelaFormAnuncio extends StatefulWidget {
  /// Se vier um anúncio, a tela entra no modo EDITAR.
  final Anuncio? anuncio;
  const TelaFormAnuncio({super.key, this.anuncio});

  @override
  State<TelaFormAnuncio> createState() => _TelaFormAnuncioState();
}

class _TelaFormAnuncioState extends State<TelaFormAnuncio> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _quantidade = TextEditingController(text: '1');
  final _peso = TextEditingController();
  final _endereco = TextEditingController();

  String? _tipo;
  String _unidade = 'kg';
  String _estado = 'bom';
  LatLng? _local;

  Uint8List? _fotoNova; // foto escolhida agora (ainda não enviada)
  bool _removerFoto = false;
  bool _salvando = false;

  bool get _editando => widget.anuncio != null;

  @override
  void initState() {
    super.initState();
    // Modo editar: preenche os campos com os dados atuais
    final a = widget.anuncio;
    if (a != null) {
      _titulo.text = a.titulo;
      _descricao.text = a.descricao ?? '';
      _quantidade.text = formatarNumero(a.quantidade).replaceAll('.', '');
      _peso.text = formatarNumero(a.pesoEstimadoKg).replaceAll('.', '');
      _endereco.text = a.endereco ?? '';
      _tipo = a.tipoMaterial;
      _unidade = unidades.contains(a.unidade) ? a.unidade : 'kg';
      _estado = a.estadoConservacao;
      _local = a.posicao;
    }
  }

  @override
  void dispose() {
    for (final c in [_titulo, _descricao, _quantidade, _peso, _endereco]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // FOTO
  // ------------------------------------------------------------------
  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      final arquivo = await ImagePicker().pickImage(
        source: origem,
        maxWidth: 1280, // diminui a foto para enviar mais rápido
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (arquivo == null) return; // usuário desistiu
      final bytes = await arquivo.readAsBytes();
      setState(() {
        _fotoNova = bytes;
        _removerFoto = false;
      });
      // Já oferece a análise da IA logo depois de escolher a foto
      _analisarComIA();
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, 'Não foi possível abrir a foto: $erro', erro: true);
      }
    }
  }

  /// Pega os bytes da foto atual (nova, ou a que já estava no servidor).
  Future<Uint8List?> _bytesDaFotoAtual() async {
    if (_fotoNova != null) return _fotoNova;
    final url = Api.urlFoto(widget.anuncio?.fotoUrl);
    if (url == null || _removerFoto) return null;
    try {
      final resposta = await http.get(Uri.parse(url));
      return resposta.statusCode == 200 ? resposta.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // IA
  // ------------------------------------------------------------------
  Future<void> _analisarComIA() async {
    final bytes = await _bytesDaFotoAtual();
    if (!mounted) return;
    if (bytes == null) {
      mostrarMensagem(context, 'Primeiro tire ou escolha uma foto do material.');
      return;
    }

    // Janela "Analisando..." enquanto a IA trabalha
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('A IA está analisando a foto...')),
          ],
        ),
      ),
    );
    final resultado = await AssistenteIA.analisarFoto(bytes);
    if (!mounted) return;
    Navigator.pop(context); // fecha o "Analisando..."

    final tipoEscolhido = await mostrarResultadoIA(context, resultado);
    if (tipoEscolhido == null || !mounted) return;
    _aplicarSugestao(tipoEscolhido);
  }

  /// Preenche o formulário com a sugestão da IA.
  void _aplicarSugestao(String tipo) {
    final info = AssistenteIA.infoDoTipo(tipo);
    setState(() {
      _tipo = tipo;
      if (_titulo.text.trim().isEmpty) _titulo.text = info.tituloSugerido;
      if (_peso.text.trim().isEmpty) _estimarPeso(avisar: false);
    });
    mostrarMensagem(context, 'Sugestão aplicada: $tipo. Confira os campos!');
  }

  /// Calcula um peso aproximado a partir da quantidade e da unidade.
  void _estimarPeso({bool avisar = true}) {
    final quantidade = lerNumero(_quantidade.text);
    if (_tipo == null || quantidade == null) {
      if (avisar) {
        mostrarMensagem(context, 'Escolha o tipo e a quantidade primeiro.');
      }
      return;
    }
    final kg = AssistenteIA.estimarPeso(_tipo!, quantidade, _unidade);
    _peso.text = formatarNumero(kg).replaceAll('.', '');
    if (avisar) mostrarMensagem(context, 'Peso estimado: ${formatarKg(kg)}');
  }

  // ------------------------------------------------------------------
  // LOCAL
  // ------------------------------------------------------------------
  Future<void> _usarMinhaLocalizacao() async {
    mostrarMensagem(context, 'Buscando sua localização...');
    final local = await Localizacao.obter();
    if (!mounted) return;
    if (local == null) {
      mostrarMensagem(context,
          'Não consegui pegar sua localização. Use "Escolher no mapa".',
          erro: true);
      return;
    }
    setState(() => _local = local);
    mostrarMensagem(context, 'Local marcado!');
  }

  Future<void> _escolherNoMapa() async {
    final escolhido = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => TelaEscolherLocal(inicial: _local)),
    );
    if (escolhido != null) setState(() => _local = escolhido);
  }

  // ------------------------------------------------------------------
  // SALVAR
  // ------------------------------------------------------------------
  Future<void> _salvar() async {
    if (!_formulario.currentState!.validate()) return;
    if (_local == null) {
      mostrarMensagem(context,
          'Marque o local de retirada (minha localização ou no mapa).',
          erro: true);
      return;
    }

    final campos = <String, dynamic>{
      'titulo': _titulo.text.trim(),
      'tipo_material': _tipo,
      'descricao': _descricao.text.trim(),
      'quantidade': lerNumero(_quantidade.text),
      'unidade': _unidade,
      'peso_estimado_kg': lerNumero(_peso.text) ?? 0,
      'estado_conservacao': _estado,
      'endereco': _endereco.text.trim(),
      'latitude': _local!.latitude,
      'longitude': _local!.longitude,
      // A foto vai como texto "Base64" dentro do JSON
      if (_fotoNova != null) 'foto_base64': base64Encode(_fotoNova!),
      if (_removerFoto) 'remover_foto': true,
    };

    setState(() => _salvando = true);
    try {
      if (_editando) {
        await Api.editarAnuncio(widget.anuncio!.id, campos);
      } else {
        await Api.criarAnuncio(campos);
      }
      if (mounted) Navigator.pop(context, true); // true = deu certo
    } catch (erro) {
      if (mounted) mostrarMensagem(context, erro.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ------------------------------------------------------------------
  // TELA
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const espaco = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar anúncio' : 'Novo anúncio')),
      body: LarguraMaxima(
        largura: 640,
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _areaFoto(),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _analisarComIA,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Analisar foto com IA'),
              ),
              const TituloSecao('Sobre o material'),
              TextFormField(
                controller: _titulo,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex.: Sobras de madeira pinus',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Dê um título ao anúncio' : null,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                // a "key" faz o campo atualizar quando a IA muda o tipo
                key: ValueKey(_tipo),
                decoration: const InputDecoration(labelText: 'Tipo de material'),
                items: [
                  for (final tipo in tiposMaterial)
                    DropdownMenuItem(
                      value: tipo.nome,
                      child: Row(
                        children: [
                          Icon(tipo.icone, color: tipo.cor, size: 20),
                          const SizedBox(width: 10),
                          Text(tipo.nome),
                        ],
                      ),
                    ),
                ],
                onChanged: (valor) => setState(() => _tipo = valor),
                validator: (v) => v == null ? 'Escolha o tipo de material' : null,
              ),
              espaco,
              TextFormField(
                controller: _descricao,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Tamanho, cor, se tem pregos, se está limpo...',
                  alignLabelWithHint: true,
                ),
              ),
              espaco,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantidade,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantidade'),
                      validator: (v) {
                        final n = lerNumero(v ?? '');
                        return (n == null || n <= 0) ? 'Maior que zero' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidade,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                      items: [
                        for (final u in unidades)
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (valor) => setState(() => _unidade = valor ?? 'kg'),
                    ),
                  ),
                ],
              ),
              espaco,
              TextFormField(
                controller: _peso,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso estimado (kg)',
                  helperText: 'Usado no painel de impacto. Toque na estrela para estimar.',
                  suffixIcon: IconButton(
                    tooltip: 'Estimar com IA',
                    icon: const Icon(Icons.auto_awesome, color: Cores.verde),
                    onPressed: _estimarPeso,
                  ),
                ),
              ),
              const TituloSecao('Estado de conservação'),
              Wrap(
                spacing: 8,
                children: [
                  for (final estado in estadosConservacao.entries)
                    ChoiceChip(
                      label: Text(estado.value),
                      selected: _estado == estado.key,
                      onSelected: (_) => setState(() => _estado = estado.key),
                    ),
                ],
              ),
              const TituloSecao('Local de retirada'),
              TextFormField(
                controller: _endereco,
                decoration: const InputDecoration(
                  labelText: 'Endereço ou ponto de referência',
                  hintText: 'Ex.: Rua X, 100 - Centro',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _usarMinhaLocalizacao,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Minha localização'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _escolherNoMapa,
                      icon: const Icon(Icons.map),
                      label: const Text('Escolher no mapa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(_local != null ? Icons.check_circle : Icons.info_outline,
                      size: 18, color: _local != null ? Cores.verde : Cores.laranja),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _local != null
                          ? 'Ponto marcado no mapa (${_local!.latitude.toStringAsFixed(4)}, '
                              '${_local!.longitude.toStringAsFixed(4)})'
                          : 'Nenhum ponto marcado ainda',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.check),
                label: Text(_editando ? 'Salvar alterações' : 'Publicar anúncio'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Quadro da foto: mostra a foto (nova ou atual) e os botões.
  Widget _areaFoto() {
    Widget imagem;
    final temFotoAntiga =
        widget.anuncio?.fotoUrl != null && !_removerFoto && _fotoNova == null;

    if (_fotoNova != null) {
      imagem = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_fotoNova!,
            height: 220, width: double.infinity, fit: BoxFit.cover),
      );
    } else if (temFotoAntiga) {
      imagem = FotoAnuncio(
        fotoUrl: widget.anuncio!.fotoUrl,
        tipoMaterial: widget.anuncio!.tipoMaterial,
        altura: 220,
        largura: double.infinity,
        raio: 16,
      );
    } else {
      imagem = Container(
        height: 180,
        decoration: BoxDecoration(
          color: Cores.verdeClaro,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Cores.verde.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo, size: 48, color: Cores.verde),
              SizedBox(height: 8),
              Text('Adicione uma foto do material'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        imagem,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _escolherFoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Câmera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _escolherFoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeria'),
              ),
            ),
            if (_fotoNova != null || temFotoAntiga) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remover foto',
                onPressed: () => setState(() {
                  _fotoNova = null;
                  _removerFoto = true;
                }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
