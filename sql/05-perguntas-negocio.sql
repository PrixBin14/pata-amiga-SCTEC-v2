-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rodar depois de: 04-fato.sql
--
--  Cada pergunta vira UMA consulta so: um SELECT com JOIN e GROUP BY. A
--  subconsulta aparece na P2 e na P5, sempre pra trazer o total da rede como
--  denominador do percentual.
--
--  Pegadinha do Postgres que ja caí uma vez: int / int TRUNCA o resultado. Por
--  isso, em todo percentual ou taxa, uso o fator 100.0 / 1000.0 com ponto (pra
--  virar decimal), e lembro que ROUND(x, casas) so aceita x numerico.
-- =====================================================================================

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Tiro a media (AVG) dos quatro intervalos que ja calculei la na carga,
--  agrupando por porte de loja. O AVG ignora NULL sozinho - por isso gravei
--  etapa nao cumprida como NULL desde o inicio, em vez de 0.
--  dias_total_ate_entrega e o processo inteiro do começo ao fim, nao um dos
--  quatro intervalos separados.

SELECT
    l.porte,
    COUNT(*) AS pedidos,
    ROUND(AVG(f.dias_integracao_separacao), 1) AS media_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 1)       AS media_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 1)        AS media_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 1)     AS media_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 1)    AS media_total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte
ORDER BY l.porte;


-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Essa e a pergunta que justifica ter criado a dim_categoria. Agrupo pelo
--  nome_categoria ja PADRONIZADO (nunca pela grafia crua, senao a resposta
--  fica toda fragmentada). O percentual do total usa uma subconsulta trazendo
--  o faturamento da rede inteira como denominador.

SELECT
    dc.nome_categoria,
    dc.grupo_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND(100.0 * SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_total
FROM fato_pedido f
JOIN dim_categoria dc ON dc.sk_categoria = f.sk_categoria
GROUP BY dc.nome_categoria, dc.grupo_categoria
ORDER BY faturamento DESC;

-- complemento que fiquei curiosa pra checar: a categoria campeã é a mesma nos três portes de loja?
SELECT
    l.porte,
    dc.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento
FROM fato_pedido f
JOIN dim_categoria dc ON dc.sk_categoria = f.sk_categoria
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte, dc.nome_categoria
ORDER BY l.porte, faturamento DESC;


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Essa aqui nao precisa de JOIN nenhum: desconto e canal ja foram padronizados
--  la na carga e moram direto na fato. Comparo o TICKET MEDIO com e sem
--  desconto DENTRO de cada canal.
--  Uma conferencia rapida que faço: se o WhatsApp nao aparecer no resultado, e
--  sinal de que o CASE do arquivo 04 testou APP antes de WHATS por engano.

SELECT
    canal_pedido,
    ROUND(AVG(CASE WHEN houve_desconto = 'Sim' THEN vl_liquido END), 2) AS ticket_medio_com_desconto,
    ROUND(AVG(CASE WHEN houve_desconto = 'Nao' THEN vl_liquido END), 2) AS ticket_medio_sem_desconto,
    ROUND(SUM(vl_liquido), 2) AS faturamento_canal,
    ROUND(100.0 * SUM(vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_faturamento
FROM fato_pedido
GROUP BY canal_pedido
ORDER BY faturamento_canal DESC;


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Essa e a que justifica ter feito a dim_praca e a tabela ponte.
--  O caminho e: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a
--  ponte entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido,
--  uma vez pra cada praca - e isso mesmo, ta certo. Por isso multiplico por
--  b.fator_publico, senao o faturamento seria contado em dobro (ou triplo).

SELECT
    dp.nome_praca,
    dp.regional,
    dp.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico), 2) AS faturamento_rateado,
    ROUND(SUM(f.vl_liquido * b.fator_publico) / NULLIF(dp.domicilios_com_pet, 0) * 1000, 2)
        AS faturamento_por_mil_domicilios
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
JOIN dim_praca dp ON dp.sk_praca = b.sk_praca
GROUP BY dp.nome_praca, dp.regional, dp.domicilios_com_pet
ORDER BY faturamento_rateado DESC;


-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  Essa pergunta tem tres partes:
--  (a) Ranqueio as lojas por itens POR MIL HABITANTES (numerador vem da fato,
--      denominador vem da dimensao) - calculo isso AQUI na hora da consulta,
--      nunca deixo gravado pronto em lugar nenhum. Cruzo com o tempo medio de
--      entrega tambem.
--  (b) Mostro o faturamento por faixa de franquia, mas explico por que esse
--      numero NAO responde "quanto veio de lojas que JA ERAM Ouro na data do
--      pedido": o cadastro so guarda a foto de hoje, nao o historico.
--  (c) Meço o que ficou de fora da analise: pedidos sem loja, entregas ainda
--      nao concluidas, itens e valores em branco.

-- (a) ranking das lojas por itens vendidos POR MIL HABITANTES (nunca em valor
--     absoluto, senao lojas grandes sempre ganhariam), cruzado com o tempo
--     médio de entrega de cada uma
SELECT
    l.nome_loja,
    l.cidade,
    l.populacao_cidade,
    SUM(f.qt_itens) AS itens_vendidos,
    ROUND(1000.0 * SUM(f.qt_itens) / NULLIF(l.populacao_cidade, 0), 3) AS itens_por_mil_habitantes,
    ROUND(AVG(f.dias_total_ate_entrega), 1) AS tempo_medio_entrega_dias
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.nome_loja, l.cidade, l.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- (b) faturamento por faixa de franquia ATUAL (repetindo: o cadastro so tem a
--     foto de hoje, entao isso NAO responde "quanto veio de lojas que JA ERAM
--     Ouro na data do pedido" - uma loja pode ter subido de faixa entre
--     set/2023 e mar/2024, e o historico da faixa antiga foi sobrescrito)
SELECT
    l.faixa_franquia,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND(100.0 * SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS percentual_do_total
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.faixa_franquia
ORDER BY faturamento DESC;

-- (c) o que ficou de fora: mede exatamente o que os dados nao cobrem, sem fingir que nao existe
SELECT
    (SELECT COUNT(*) FROM fato_pedido WHERE sk_loja = -1)          AS pedidos_sem_loja_identificada,
    (SELECT COUNT(*) FROM fato_pedido WHERE sk_tempo_entrega = -1) AS entregas_ainda_nao_concluidas,
    (SELECT COUNT(*) FROM fato_pedido WHERE qt_itens IS NULL)      AS pedidos_com_itens_em_branco,
    (SELECT COUNT(*) FROM fato_pedido WHERE vl_liquido IS NULL)    AS pedidos_com_valor_em_branco;
