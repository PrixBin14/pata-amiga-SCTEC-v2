-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rodar depois de: 03-dimensoes.sql
--
--  E uma fato so, um unico INSERT ... SELECT. A tabela ja existe vazia (criada
--  no arquivo 02). No final tem que dar 4.044 linhas = 4.044 pedidos.
--
--  Regra que segui: a limpeza pesada fica nas dimensoes, aqui na fato eu so
--  procuro a linha certa (via JOIN). Nenhuma FK fica nula - quando o dado
--  falta, ela aponta pra linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Dica de quem ja apanhou fazendo isso: comeca pelo esqueleto (numero_pedido
--  + as duas FKs de tempo + o FROM), roda e confere se ja da 4.044 linhas -
--  so depois vai acrescentando as outras colunas aos poucos.
-- =====================================================================================

-- >>> aqui embaixo entra o INSERT INTO fato_pedido (...) SELECT ... FROM stg_pedido ...
--
--  Anotacoes de cada coluna, pra eu nao esquecer o porque de cada escolha:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a propria data no formato
--    AAAAMMDD. Monto com TO_CHAR(<a data>, 'YYYYMMDD')::int. A data do PEDIDO
--    vem em formato americano com AM/PM: a mascara e 'MM/DD/YYYY HH12:MI AM'
--    (TO_TIMESTAMP). Se eu usasse 'DD/MM/YYYY' o Postgres da ERRO na hora nas
--    datas com mes maior que 12. Os marcos da entrega ja vem em ISO, entao um
--    ::date resolve. Entrega em branco vira -1.
--
--  * sk_loja, sk_categoria: vem de um LEFT JOIN; quando nao acha par, fica -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpo o nome direto no ON. Um REPLACE tira o
--    '/SC' e o espaco duplo; e um CASE resolve as 3 grafias que sobram
--    (erro de digitacao, apelido, abreviacao). Como o Postgres compara byte a
--    byte, normalizo acento e caixa com
--    UPPER(TRANSLATE(..., 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç',
--    'AAAAEEIOOOUUCaaaaeeiooouuc')). A chave_loja da dim_loja ja veio pronta
--    nesse mesmo padrao (caixa alta, sem acento).
--
--  * CATEGORIA (LEFT JOIN dim_categoria): so uma linha de JOIN -
--    ON dc.categoria_origem = p."CategoriaProduto".
--
--  * houve_desconto e canal_pedido: padronizo com CASE e gravo direto na
--    propria fato (nao existe dimensao pra eles - nao valia a pena criar uma
--    so pra isso). O de-para completo dos dois campos ta no enunciado, na
--    secao 7. Um detalhe que quase me pegou: a ordem importa, porque
--    'WHATSAPP' contem 'APP' dentro da palavra, entao preciso testar WHATS
--    antes de APP. No desconto, tiro o acento com TRANSLATE antes do UPPER.
--
--  * valores em dinheiro e quantidade de itens: '' e '-' viram NULL; tiro o
--    "R$" e trato o separador de milhar.
--
--  * os lags em dias: no Postgres, data menos data ja da direto o numero de
--    dias, sem precisar de funcao. Etapa que nao aconteceu grava NULL, nunca
--    0. Uso ::date em volta da integracao pra nao misturar hora no calculo.

INSERT INTO fato_pedido (
    numero_pedido, sk_tempo_pedido, sk_tempo_entrega, sk_loja, sk_categoria,
    houve_desconto, canal_pedido, dt_pedido, qt_itens, vl_liquido,
    dias_integracao_separacao, dias_separacao_nota, dias_nota_despacho,
    dias_despacho_entrega, dias_total_ate_entrega
)
SELECT
    p."NumeroPedido",

    -- as duas FKs de tempo: a mesma dim_tempo, so que em dois papeis diferentes
    TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int,
    CASE WHEN p."DtEntregaCliente" = '' THEN -1
         ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int END,

    -- FK da loja: quando o LEFT JOIN nao acha par, cai na -1
    CASE WHEN l.sk_loja IS NULL THEN -1 ELSE l.sk_loja END,

    -- FK da categoria: JOIN de uma linha so, direto pela grafia crua
    CASE WHEN dc.sk_categoria IS NULL THEN -1 ELSE dc.sk_categoria END,

    -- houve_desconto: as 17 grafias diferentes viram só 3 valores
    CASE
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
        WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) IN ('N','NAO','0','FALSE','F') THEN 'Nao'
        ELSE 'Nao Informado'
    END,

    -- canal_pedido: aqui a ordem importa - WHATS antes de APP, porque a palavra 'WHATSAPP' contem 'APP' dentro
    CASE
        WHEN UPPER(p."CanalPedido") LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(p."CanalPedido") LIKE '%APP%'   THEN 'App'
        WHEN UPPER(p."CanalPedido") LIKE '%SITE%'  THEN 'Site'
        WHEN UPPER(p."CanalPedido") LIKE '%LOJA%'  THEN 'Loja Fisica'
        WHEN UPPER(p."CanalPedido") LIKE '%TEL%'   THEN 'Telefone'
        ELSE 'Nao Informado'
    END,

    TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'),

    -- qt_itens: campo vazio vira NULL, nunca vira 0
    CASE WHEN TRIM(p."QTD.Itens") IN ('','-') THEN NULL
         ELSE CAST(TRIM(p."QTD.Itens") AS INTEGER) END,

    -- vl_liquido: seguindo a regra de conversao de numero do enunciado
    CASE WHEN TRIM(REPLACE(p."ValorLiquidoPedido(R$)",'R$','')) IN ('','-') THEN NULL
         WHEN p."ValorLiquidoPedido(R$)" LIKE '%,%'
              THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ',''),'.',''),',','.')
                   AS DECIMAL(15,2))
         ELSE CAST(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ','') AS DECIMAL(15,2))
    END,

    -- os cinco lags em dias. Etapa que nao aconteceu (marco em branco) vira NULL, nunca 0.
    CASE WHEN p."Dt Separacao Estoque" = '' THEN NULL
         ELSE p."Dt Separacao Estoque"::date
              - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date END,

    CASE WHEN p."Dt Separacao Estoque" = '' OR p."DtNotaFiscal" = '' THEN NULL
         ELSE p."DtNotaFiscal"::date - p."Dt Separacao Estoque"::date END,

    CASE WHEN p."DtNotaFiscal" = '' OR p."Dt_Despacho_Transportadora" = '' THEN NULL
         ELSE p."Dt_Despacho_Transportadora"::date - p."DtNotaFiscal"::date END,

    CASE WHEN p."Dt_Despacho_Transportadora" = '' OR p."DtEntregaCliente" = '' THEN NULL
         ELSE p."DtEntregaCliente"::date - p."Dt_Despacho_Transportadora"::date END,

    CASE WHEN p."DtEntregaCliente" = '' THEN NULL
         ELSE p."DtEntregaCliente"::date
              - TO_TIMESTAMP(p."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date END

FROM stg_pedido p

-- LOJA: limpo o nome direto no ON (REPLACE tira '/SC' e o espaco duplo; um
-- CASE resolve as 3 grafias que sobram - digitacao, apelido, abreviacao;
-- comparo tudo normalizado em UPPER + TRANSLATE contra a chave_loja, que ja
-- vem padronizada desse mesmo jeito)
LEFT JOIN dim_loja l ON l.chave_loja =
    CASE
        WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome", '/SC', ''), '  ', ' ')),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA BLUMENAL CENTRO'
             THEN 'PATA AMIGA BLUMENAU CENTRO'
        WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome", '/SC', ''), '  ', ' ')),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA FLORIPA NORTE'
             THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
        WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome", '/SC', ''), '  ', ' ')),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) = 'PATA AMIGA JGUA DO SUL'
             THEN 'PATA AMIGA JARAGUA DO SUL'
        ELSE UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome", '/SC', ''), '  ', ' ')),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
    END

-- CATEGORIA: so uma linha de JOIN, direto pela grafia crua
LEFT JOIN dim_categoria dc ON dc.categoria_origem = p."CategoriaProduto";

-- =====================================================================================
--  Pra conferir se deu tudo certo, rodo o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
