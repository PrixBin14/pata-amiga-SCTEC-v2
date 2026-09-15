-- =====================================================================================
--  00-CONFERENCIA.SQL   -   minha "checklist" pra rodar depois de cada etapa
--  Case: Pata Amiga  |  PostgreSQL 16
-- =====================================================================================
--  Isso aqui e so pra eu conferir se ta tudo certo.
--
--  Cada bloco tem do lado o valor que eu esperava encontrar. A ideia e rodar o
--  bloco certo assim que termino o arquivo correspondente - se o numero nao
--  bater, ja paro e corrijo antes de seguir, porque um arquivo depende do outro.
--
--  Um detalhe que quase me confundiu: a contagem de linhas da dim_categoria
--  muda de banco pra banco, porque o Postgres compara letra por letra (entao
--  'Racao' e 'RACAO' contam como coisas diferentes) e o DISTINCT acaba trazendo
--  mais linhas do que traria no MySQL. O que importa mesmo e ter as 7
--  categorias ja padronizadas, nao bater o numero exato de linhas.
-- =====================================================================================

-- =====================================================================================
--  DEPOIS DO 01 - A STAGING
-- =====================================================================================
SELECT 'stg_pedido'     AS tabela, COUNT(*) AS linhas, 4044 AS esperado FROM stg_pedido
UNION ALL SELECT 'stg_loja',       COUNT(*), 32 FROM stg_loja
UNION ALL SELECT 'stg_loja_praca', COUNT(*), 48 FROM stg_loja_praca;

-- Numeros do diagnostico da Tarefa 1 - esses eu levo direto pro README.
SELECT 'grafias distintas de categoria (no PostgreSQL)' AS diagnostico,
       COUNT(DISTINCT "CategoriaProduto") AS valor, '37' AS esperado FROM stg_pedido
UNION ALL SELECT 'grafias distintas de nome de loja',
       COUNT(DISTINCT "Loja-Nome"), '(conte e descreva)' FROM stg_pedido
UNION ALL SELECT 'grafias distintas de HouveDesconto',
       COUNT(DISTINCT "HouveDesconto"), '(conte)' FROM stg_pedido
UNION ALL SELECT 'grafias distintas de CanalPedido',
       COUNT(DISTINCT "CanalPedido"), '(conte)' FROM stg_pedido
UNION ALL SELECT 'pedidos sem Cod Loja preenchido',
       SUM(CASE WHEN "Cod Loja" = '' THEN 1 ELSE 0 END), '1575  (~39%)' FROM stg_pedido
UNION ALL SELECT 'pedidos sem nome de loja (vao para a -1)',
       SUM(CASE WHEN "Loja-Nome" = '' THEN 1 ELSE 0 END), '3' FROM stg_pedido;

-- Os quatro marcos em branco = a etapa ainda nao aconteceu. Vao virar NULL, nunca zero.
SELECT 'Dt Separacao Estoque' AS marco,
       SUM(CASE WHEN "Dt Separacao Estoque" = '' THEN 1 ELSE 0 END) AS em_branco,
       1077 AS esperado FROM stg_pedido
UNION ALL SELECT 'DtNotaFiscal',
       SUM(CASE WHEN "DtNotaFiscal" = '' THEN 1 ELSE 0 END), 1338 FROM stg_pedido
UNION ALL SELECT 'Dt_Despacho_Transportadora',
       SUM(CASE WHEN "Dt_Despacho_Transportadora" = '' THEN 1 ELSE 0 END), 1665 FROM stg_pedido
UNION ALL SELECT 'DtEntregaCliente',
       SUM(CASE WHEN "DtEntregaCliente" = '' THEN 1 ELSE 0 END), 1953 FROM stg_pedido;

-- Testando a mascara da data antes de escrever a fato de verdade.
-- A data do pedido vem em formato americano ('MM/DD/YYYY') - essa contagem tem
-- que dar 4044. Se eu tentasse ler como formato brasileiro ('DD/MM/YYYY') o
-- Postgres nem devolve NULL quietinho, ele da erro na hora que aparece um mes
-- maior que 12 - foi assim, inclusive, que percebi que o formato era americano.
SELECT COUNT(*) AS mascara_americana_ok, '4044' AS esperado
FROM stg_pedido
WHERE TO_TIMESTAMP("DtHoraPedido", 'MM/DD/YYYY HH12:MI AM') IS NOT NULL;

-- =====================================================================================
--  DEPOIS DO 02 - O QUE VEIO PRONTO
-- =====================================================================================
SELECT 'dim_tempo' AS tabela, COUNT(*) AS linhas, '236  (235 dias + a -1)' AS esperado
FROM dim_tempo
UNION ALL SELECT 'dim_loja', COUNT(*), '33  (32 lojas + a -1)' FROM dim_loja;

-- As quatro tabelas ja existem, criadas no arquivo 02, mas ainda vazias - tem
-- que dar zero em tudo aqui embaixo.
SELECT 'dim_categoria' AS tabela, COUNT(*) AS deve_estar_vazia FROM dim_categoria
UNION ALL SELECT 'dim_praca',         COUNT(*) FROM dim_praca
UNION ALL SELECT 'bridge_loja_praca', COUNT(*) FROM bridge_loja_praca
UNION ALL SELECT 'fato_pedido',       COUNT(*) FROM fato_pedido;

-- =====================================================================================
--  DEPOIS DO 03 - AS MINHAS DIMENSOES
-- =====================================================================================
SELECT 'dim_categoria'     AS tabela, COUNT(*) AS linhas,
       '38 no PostgreSQL - varia por banco' AS esperado FROM dim_categoria
UNION ALL SELECT 'dim_praca',         COUNT(*), '13  (12 pracas + a -1)' FROM dim_praca
UNION ALL SELECT 'bridge_loja_praca', COUNT(*), '48' FROM bridge_loja_praca;

-- Esse aqui e o teste que realmente importa, e nao muda dependendo do banco.
SELECT COUNT(DISTINCT nome_categoria) AS categorias_padronizadas,
       '8 = as 7 categorias + a linha -1' AS esperado FROM dim_categoria;

-- Se aparecer 'Nao Informado' numa linha que nao e a -1, quer dizer que algum
-- WHEN do meu CASE nao pegou aquela grafia. Essa consulta tem que voltar vazia.
SELECT categoria_origem, nome_categoria FROM dim_categoria
WHERE nome_categoria = 'Nao Informado' AND sk_categoria <> -1;

-- Testando a ordem do CASE: "Racao Medicamentosa" tem que cair em Medicamento.
-- Se aparecer 'Racao' na segunda coluna, e sinal de que testei RA antes de MED -
-- foi exatamente isso que quase deu errado aqui.
SELECT categoria_origem, nome_categoria, 'Medicamento' AS esperado
FROM dim_categoria WHERE UPPER(categoria_origem) LIKE '%MEDICAMENTOSA%';


-- Conferindo a ponte: o fator de cada loja tem que somar exatamente 1,00. Se
-- voltar alguma linha aqui, tem loja com rateio errado.
SELECT cod_loja, ROUND(SUM(fator_publico), 4) AS soma_dos_fatores
FROM bridge_loja_praca GROUP BY cod_loja
HAVING ROUND(SUM(fator_publico), 4) <> 1;

-- As 32 lojas tem que aparecer na ponte, e toda praca precisa ter pelo menos
-- uma loja atendendo ela.
SELECT 'lojas na ponte' AS teste, COUNT(DISTINCT cod_loja) AS valor, '32' AS esperado
FROM bridge_loja_praca
UNION ALL SELECT 'pracas na ponte', COUNT(DISTINCT sk_praca), '12' FROM bridge_loja_praca;

-- Toda dimensao precisa ter a linha -1 cadastrada. As duas tem que aparecer aqui.
SELECT 'dim_categoria' AS dimensao, COUNT(*) AS tem_a_linha_menos_1
FROM dim_categoria WHERE sk_categoria = -1
UNION ALL SELECT 'dim_praca',       COUNT(*) FROM dim_praca       WHERE sk_praca = -1;

-- =====================================================================================
--  DEPOIS DO 04 - A FATO
-- =====================================================================================
SELECT COUNT(*) AS linhas, '4044' AS esperado FROM fato_pedido;
-- Se der mais que 4.044 e sinal de JOIN duplicando linha; se der menos, e JOIN

-- Nenhuma FK pode ficar nula, e nenhuma pode apontar pra uma chave que nao existe.
SELECT 'FK nula' AS teste, COUNT(*) AS deve_ser_zero FROM fato_pedido
WHERE sk_loja IS NULL OR sk_categoria IS NULL
   OR sk_tempo_pedido IS NULL OR sk_tempo_entrega IS NULL
UNION ALL SELECT 'FK orfa (loja)', COUNT(*)
FROM fato_pedido f LEFT JOIN dim_loja d ON d.sk_loja = f.sk_loja
WHERE d.sk_loja IS NULL
UNION ALL SELECT 'FK orfa (categoria)', COUNT(*)
FROM fato_pedido f LEFT JOIN dim_categoria d ON d.sk_categoria = f.sk_categoria
WHERE d.sk_categoria IS NULL
UNION ALL SELECT 'FK orfa (tempo da entrega)', COUNT(*)
FROM fato_pedido f LEFT JOIN dim_tempo d ON d.sk_tempo = f.sk_tempo_entrega
WHERE d.sk_tempo IS NULL;

SELECT 'pedidos sem loja (na linha -1)' AS informativo, COUNT(*) AS valor,
       '3' AS esperado FROM fato_pedido WHERE sk_loja = -1
UNION ALL SELECT 'entregas ainda nao feitas (tempo na -1)', COUNT(*), '1953'
FROM fato_pedido WHERE sk_tempo_entrega = -1;

-- Testando a ordem do CASE do canal (la no arquivo 04): o WhatsApp precisa
-- aparecer na fato. Se essa consulta voltar vazia e porque testei APP antes de
-- WHATS, e todo pedido de WhatsApp acabou classificado como App.
SELECT canal_pedido, COUNT(*) AS pedidos FROM fato_pedido
WHERE canal_pedido = 'WhatsApp' GROUP BY canal_pedido;

-- O periodo dos pedidos tem que ir de 01/09/2023 a 31/03/2024. Se a data
-- minima ou maxima fugir disso, e sinal de mascara de data errada em algum lugar.
SELECT MIN(dt_pedido::date) AS primeiro_pedido, MAX(dt_pedido::date) AS ultimo_pedido,
       '2023-09-01 a 2024-03-31' AS esperado FROM fato_pedido;

-- Os dias nunca podem dar negativo - o processo e sequencial, uma etapa sempre
-- vem depois da outra.
SELECT 'dias negativos' AS teste, COUNT(*) AS deve_ser_zero FROM fato_pedido
WHERE dias_integracao_separacao < 0 OR dias_separacao_nota < 0
   OR dias_nota_despacho < 0 OR dias_despacho_entrega < 0
   OR dias_total_ate_entrega < 0;

-- =====================================================================================
--  DEPOIS DO 05 - AS RESPOSTAS
-- =====================================================================================
-- Conferindo se a soma da P2 bate com o total da fato. Se nao bater, tem JOIN
-- comendo alguma linha em algum lugar.
SELECT
    (SELECT ROUND(SUM(vl_liquido)) FROM fato_pedido)             AS total_na_fato,
    (SELECT ROUND(SUM(f.vl_liquido)) FROM fato_pedido f
       JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria)  AS total_pela_P2;
-- As duas colunas tem que dar exatamente o mesmo numero.

-- Rateio da P4: somando o valor rateado por praca com os pedidos sem loja, tem
-- que fechar com o total da rede. A ultima coluna tem que dar ZERO.
-- Arredondei a diferenca inteira de uma vez so (nao cada soma separada) - senao
-- o arredondamento deixa parecer que sobrou 1 ou 2 reais quando na verdade
-- fecha certinho.
SELECT
    (SELECT ROUND(SUM(vl_liquido)) FROM fato_pedido) AS total_da_rede,
    (SELECT ROUND(SUM(f.vl_liquido * b.fator_publico))
       FROM fato_pedido f
       JOIN dim_loja l ON l.sk_loja = f.sk_loja
       JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja) AS soma_rateada,
    (SELECT ROUND(SUM(vl_liquido)) FROM fato_pedido WHERE sk_loja = -1) AS sem_loja,
    ROUND(
        (SELECT SUM(vl_liquido) FROM fato_pedido)
        - (SELECT SUM(f.vl_liquido * b.fator_publico)
             FROM fato_pedido f
             JOIN dim_loja l ON l.sk_loja = f.sk_loja
             JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja)
        - (SELECT SUM(vl_liquido) FROM fato_pedido WHERE sk_loja = -1)
    )                                                AS tem_de_dar_ZERO;
