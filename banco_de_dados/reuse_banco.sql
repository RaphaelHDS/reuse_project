-- =====================================================================
--  ReUse - Plataforma para reaproveitamento de materiais
--  Script do banco de dados (MySQL / MariaDB do XAMPP)
-- ---------------------------------------------------------------------
--  COMO USAR:
--    1. Abra o phpMyAdmin (http://localhost/phpmyadmin)
--    2. Clique na aba "Importar"
--    3. Escolha este arquivo e clique em "Importar" (ou "Executar")
--
--  ATENÇÃO: este script APAGA o banco "reuse_db" (se existir) e cria
--  tudo de novo, já com dados de exemplo para testar o app.
--  Ele também cria o usuário de banco "reuse_app" que a API usa.
--
--  Usuários de teste (senha de todos: 123456)
--    marcenaria@reuse.com  -> Marcenaria Bom Corte (empresa)
--    ana@reuse.com         -> Ana Souza, artesã (pessoa)
--    escola@reuse.com      -> Escola Técnica Futuro (empresa)
--    confeccao@reuse.com   -> Confecção Fio de Ouro (empresa)
--    carlos@reuse.com      -> Carlos Lima, serralheiro (pessoa)
-- =====================================================================

-- Garante que os acentos sejam importados corretamente
SET NAMES utf8mb4;

DROP DATABASE IF EXISTS reuse_db;
CREATE DATABASE reuse_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Usuário do banco que a API usa (em vez do "root").
--   usuário: reuse_app     senha: ReUse@2026
-- É uma boa prática: a API só tem acesso ao banco reuse_db.
-- (Criamos para "localhost" e "127.0.0.1" para funcionar nos dois jeitos.)
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'reuse_app'@'localhost';
DROP USER IF EXISTS 'reuse_app'@'127.0.0.1';
CREATE USER 'reuse_app'@'localhost' IDENTIFIED BY 'ReUse@2026';
CREATE USER 'reuse_app'@'127.0.0.1' IDENTIFIED BY 'ReUse@2026';
GRANT ALL PRIVILEGES ON reuse_db.* TO 'reuse_app'@'localhost';
GRANT ALL PRIVILEGES ON reuse_db.* TO 'reuse_app'@'127.0.0.1';
FLUSH PRIVILEGES;

USE reuse_db;

-- ---------------------------------------------------------------------
-- TABELA: usuarios
-- Guarda todas as contas (pessoas e empresas).
-- A senha NUNCA é guardada pura: guardamos um "hash" (SHA-256) da senha
-- misturada com um "sal" (texto aleatório de cada usuário).
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  tipo        ENUM('pessoa', 'empresa') NOT NULL DEFAULT 'pessoa',
  nome        VARCHAR(120) NOT NULL,
  email       VARCHAR(120) NOT NULL,
  telefone    VARCHAR(20)  NULL,          -- usado no botão de WhatsApp
  cidade      VARCHAR(80)  NULL,
  senha_hash  CHAR(64)     NOT NULL,
  senha_salt  CHAR(32)     NOT NULL,
  criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_usuarios_email (email)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: empresas
-- Dados extras de quem se cadastrou como empresa (1 para 1 com usuarios).
-- ---------------------------------------------------------------------
CREATE TABLE empresas (
  usuario_id      INT PRIMARY KEY,
  cnpj            VARCHAR(18)  NULL,
  ramo_atividade  VARCHAR(100) NULL,
  CONSTRAINT fk_empresas_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: sessoes
-- Cada login gera um "token" (uma chave secreta). O app envia esse
-- token em toda requisição para provar quem é o usuário.
-- ---------------------------------------------------------------------
CREATE TABLE sessoes (
  token       CHAR(64) PRIMARY KEY,
  usuario_id  INT      NOT NULL,
  criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sessoes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: recuperacoes_senha
-- Códigos de 6 dígitos para quem esqueceu a senha.
-- ---------------------------------------------------------------------
CREATE TABLE recuperacoes_senha (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id  INT        NOT NULL,
  codigo      CHAR(6)    NOT NULL,
  expira_em   DATETIME   NOT NULL,
  usado       TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_recuperacoes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: anuncios
-- Cada material cadastrado para reaproveitamento.
-- status: disponivel -> reservado -> retirado
-- peso_estimado_kg: usado no painel de impacto (kg de resíduo evitado).
-- ---------------------------------------------------------------------
CREATE TABLE anuncios (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id          INT           NOT NULL,
  titulo              VARCHAR(120)  NOT NULL,
  tipo_material       VARCHAR(40)   NOT NULL,
  descricao           TEXT          NULL,
  quantidade          DECIMAL(10,2) NOT NULL DEFAULT 1,
  unidade             VARCHAR(20)   NOT NULL DEFAULT 'kg',
  peso_estimado_kg    DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado_conservacao  ENUM('novo', 'bom', 'regular', 'desgastado') NOT NULL DEFAULT 'bom',
  foto_url            VARCHAR(255)  NULL,
  endereco            VARCHAR(200)  NULL,
  latitude            DECIMAL(10,7) NULL,
  longitude           DECIMAL(10,7) NULL,
  status              ENUM('disponivel', 'reservado', 'retirado') NOT NULL DEFAULT 'disponivel',
  criado_em           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_anuncios_status (status),
  INDEX idx_anuncios_tipo (tipo_material),
  CONSTRAINT fk_anuncios_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: solicitacoes
-- Pedido de retirada feito por um interessado em um anúncio.
-- finalidade = "destino do material" (o que a pessoa vai fazer com ele).
-- ---------------------------------------------------------------------
CREATE TABLE solicitacoes (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  anuncio_id      INT          NOT NULL,
  solicitante_id  INT          NOT NULL,
  mensagem        VARCHAR(500) NULL,
  finalidade      VARCHAR(150) NULL,
  status          ENUM('pendente', 'aceita', 'recusada', 'concluida', 'cancelada') NOT NULL DEFAULT 'pendente',
  criado_em       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_solicitacoes_anuncio FOREIGN KEY (anuncio_id)
    REFERENCES anuncios (id) ON DELETE CASCADE,
  CONSTRAINT fk_solicitacoes_usuario FOREIGN KEY (solicitante_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: mensagens
-- Chat interno: cada conversa pertence a uma solicitação.
-- ---------------------------------------------------------------------
CREATE TABLE mensagens (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  solicitacao_id  INT           NOT NULL,
  remetente_id    INT           NOT NULL,
  texto           VARCHAR(1000) NOT NULL,
  criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mensagens_solicitacao FOREIGN KEY (solicitacao_id)
    REFERENCES solicitacoes (id) ON DELETE CASCADE,
  CONSTRAINT fk_mensagens_usuario FOREIGN KEY (remetente_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TABELA: notificacoes
-- Avisos que aparecem no sininho do app.
-- ---------------------------------------------------------------------
CREATE TABLE notificacoes (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id  INT          NOT NULL,
  titulo      VARCHAR(120) NOT NULL,
  texto       VARCHAR(300) NOT NULL,
  lida        TINYINT(1)   NOT NULL DEFAULT 0,
  criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notificacoes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE = InnoDB;


-- =====================================================================
--  DADOS DE EXEMPLO
--  As senhas são calculadas aqui mesmo com SHA2(sal + senha, 256),
--  exatamente como a API faz.
-- =====================================================================

INSERT INTO usuarios (id, tipo, nome, email, telefone, cidade, senha_salt, senha_hash, criado_em) VALUES
(1, 'empresa', 'Marcenaria Bom Corte',  'marcenaria@reuse.com', '11988880001', 'Mogi das Cruzes',
    '5f1c9a0e7b3d4a2c8e6f1b0d9c7a5e3f', SHA2(CONCAT('5f1c9a0e7b3d4a2c8e6f1b0d9c7a5e3f', '123456'), 256), NOW() - INTERVAL 40 DAY),
(2, 'pessoa',  'Ana Souza (artesã)',     'ana@reuse.com',        '11977770002', 'Mogi das Cruzes',
    'a3e8c1f5d7b9024e6c8a1f3d5b7e9c0a', SHA2(CONCAT('a3e8c1f5d7b9024e6c8a1f3d5b7e9c0a', '123456'), 256), NOW() - INTERVAL 35 DAY),
(3, 'empresa', 'Escola Técnica Futuro',  'escola@reuse.com',     '11966660003', 'Mogi das Cruzes',
    'c7d2e9f1a4b6083c5e7d9f1a3b5c7e9d', SHA2(CONCAT('c7d2e9f1a4b6083c5e7d9f1a3b5c7e9d', '123456'), 256), NOW() - INTERVAL 30 DAY),
(4, 'empresa', 'Confecção Fio de Ouro',  'confeccao@reuse.com',  '11955550004', 'Suzano',
    'e1f3a5c7b9d0e2f4a6c8b0d2e4f6a8c0', SHA2(CONCAT('e1f3a5c7b9d0e2f4a6c8b0d2e4f6a8c0', '123456'), 256), NOW() - INTERVAL 28 DAY),
(5, 'pessoa',  'Carlos Lima (serralheiro)', 'carlos@reuse.com',  '11944440005', 'Mogi das Cruzes',
    '0b2d4f6a8c1e3a5c7e9b1d3f5a7c9e1b', SHA2(CONCAT('0b2d4f6a8c1e3a5c7e9b1d3f5a7c9e1b', '123456'), 256), NOW() - INTERVAL 20 DAY);

INSERT INTO empresas (usuario_id, cnpj, ramo_atividade) VALUES
(1, '12.345.678/0001-90', 'Marcenaria'),
(3, '23.456.789/0001-01', 'Educação técnica'),
(4, '34.567.890/0001-12', 'Confecção de roupas');

-- Anúncios espalhados por Mogi das Cruzes e região
INSERT INTO anuncios (id, usuario_id, titulo, tipo_material, descricao, quantidade, unidade, peso_estimado_kg,
                      estado_conservacao, endereco, latitude, longitude, status, criado_em) VALUES
(1, 1, 'Sobras de madeira pinus', 'Madeira',
    'Retalhos de pinus de 20 a 80 cm, sem pregos. Ótimo para artesanato e pequenos móveis.',
    30, 'kg', 30, 'bom', 'Rua Coronel Souza Franco, Centro - Mogi das Cruzes', -23.5230000, -46.1855000, 'disponivel', NOW() - INTERVAL 2 DAY),
(2, 4, 'Retalhos de tecido de algodão', 'Tecido',
    'Retalhos coloridos de algodão, tamanhos variados. Bons para patchwork, bonecas e panos.',
    8, 'kg', 8, 'novo', 'Av. Francisco Marengo - Suzano', -23.5420000, -46.3110000, 'disponivel', NOW() - INTERVAL 1 DAY),
(3, 1, 'Chapas de MDF com pequenos defeitos', 'Madeira',
    'Chapas de MDF 15 mm com riscos leves. Servem para prateleiras, caixas e maquetes.',
    12, 'unidades', 60, 'regular', 'Rua Coronel Souza Franco, Centro - Mogi das Cruzes', -23.5235000, -46.1860000, 'disponivel', NOW() - INTERVAL 5 DAY),
(4, 3, 'Garrafas PET limpas', 'Plástico',
    'Garrafas PET de 2 litros, lavadas e sem rótulo. Ideal para hortas verticais e projetos escolares.',
    200, 'unidades', 8, 'bom', 'Av. Voluntário Fernando Pinheiro Franco - Mogi das Cruzes', -23.5150000, -46.1750000, 'disponivel', NOW() - INTERVAL 3 DAY),
(5, 2, 'Caixas de papelão desmontadas', 'Papel e papelão',
    'Caixas médias e grandes, secas e em bom estado. Boas para mudança ou organização.',
    40, 'unidades', 12, 'bom', 'Vila Oliveira - Mogi das Cruzes', -23.5320000, -46.1950000, 'disponivel', NOW() - INTERVAL 4 HOUR),
(6, 5, 'Tubos e cantoneiras de metal', 'Metal',
    'Sobras de tubos de aço e cantoneiras de 30 cm a 1 m. Algumas com ferrugem leve.',
    25, 'kg', 25, 'regular', 'Jardim Santista - Mogi das Cruzes', -23.5400000, -46.2200000, 'disponivel', NOW() - INTERVAL 6 DAY),
(7, 2, 'Potes de vidro com tampa', 'Vidro',
    'Potes de vidro de conserva, limpos e com tampa. Ótimos para velas, temperos e decoração.',
    30, 'unidades', 9, 'bom', 'Vila Oliveira - Mogi das Cruzes', -23.5325000, -46.1945000, 'disponivel', NOW() - INTERVAL 8 DAY),
(8, 4, 'Paletes de madeira', 'Madeira',
    'Paletes em bom estado, podem virar sofás, hortas e bancos.',
    5, 'unidades', 100, 'bom', 'Av. Francisco Marengo - Suzano', -23.5425000, -46.3100000, 'reservado', NOW() - INTERVAL 10 DAY),
(9, 4, 'Sacos de retalhos de malha', 'Tecido',
    'Retalhos de malha para enchimento de almofadas e artesanato.',
    5, 'kg', 5, 'bom', 'Av. Francisco Marengo - Suzano', -23.5428000, -46.3105000, 'retirado', NOW() - INTERVAL 20 DAY),
(10, 5, 'Latas de alumínio', 'Metal',
    'Latas de alumínio amassadas, limpas.',
    15, 'kg', 15, 'desgastado', 'Jardim Santista - Mogi das Cruzes', -23.5405000, -46.2205000, 'retirado', NOW() - INTERVAL 18 DAY),
(11, 1, 'Sarrafos de madeira de demolição', 'Madeira',
    'Sarrafos de peroba de demolição, alguns com marcas de prego.',
    40, 'kg', 40, 'regular', 'Rua Coronel Souza Franco, Centro - Mogi das Cruzes', -23.5232000, -46.1858000, 'retirado', NOW() - INTERVAL 15 DAY),
(12, 3, 'Embalagens de isopor e plástico bolha', 'Embalagens',
    'Embalagens de equipamentos que chegaram na escola. Limpas e sem rasgos grandes.',
    3, 'kg', 3, 'bom', 'Av. Voluntário Fernando Pinheiro Franco - Mogi das Cruzes', -23.5155000, -46.1755000, 'disponivel', NOW() - INTERVAL 12 HOUR);

-- Solicitações de retirada (pedidos)
INSERT INTO solicitacoes (id, anuncio_id, solicitante_id, mensagem, finalidade, status, criado_em) VALUES
(1, 8, 3, 'Olá! Podemos buscar os paletes na sexta à tarde?', 'Montar bancos e hortas com os alunos', 'aceita', NOW() - INTERVAL 9 DAY),
(2, 9, 2, 'Tenho interesse nos retalhos de malha.', 'Enchimento de almofadas artesanais', 'concluida', NOW() - INTERVAL 19 DAY),
(3, 10, 3, 'As latas servem para nosso projeto de reciclagem.', 'Oficina de reciclagem na escola', 'concluida', NOW() - INTERVAL 17 DAY),
(4, 11, 2, 'Quero fazer porta-retratos com essa madeira.', 'Porta-retratos e caixas artesanais', 'concluida', NOW() - INTERVAL 14 DAY),
(5, 1, 2, 'Oi! Posso retirar as sobras de pinus amanhã de manhã?', 'Caixas organizadoras artesanais', 'pendente', NOW() - INTERVAL 3 HOUR);

-- Conversas do chat interno
INSERT INTO mensagens (solicitacao_id, remetente_id, texto, criado_em) VALUES
(1, 3, 'Olá! Podemos buscar os paletes na sexta à tarde?', NOW() - INTERVAL 9 DAY),
(1, 4, 'Pode sim! Estamos aqui até as 17h.', NOW() - INTERVAL 9 DAY + INTERVAL 30 MINUTE),
(1, 3, 'Combinado, obrigado!', NOW() - INTERVAL 9 DAY + INTERVAL 45 MINUTE),
(5, 2, 'Oi! Posso retirar as sobras de pinus amanhã de manhã?', NOW() - INTERVAL 3 HOUR);

-- Notificações (avisos no sininho)
INSERT INTO notificacoes (usuario_id, titulo, texto, lida, criado_em) VALUES
(1, 'Nova solicitação', 'Ana Souza (artesã) quer retirar "Sobras de madeira pinus".', 0, NOW() - INTERVAL 3 HOUR),
(3, 'Pedido aceito', 'Seu pedido de "Paletes de madeira" foi aceito. Combine a retirada pelo chat.', 1, NOW() - INTERVAL 9 DAY);

-- Pronto! Confira as tabelas no menu da esquerda do phpMyAdmin.
