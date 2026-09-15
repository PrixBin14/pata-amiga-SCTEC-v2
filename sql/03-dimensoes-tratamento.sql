-- =====================================================================================
--  ARQUIVO 3:  AS DIMENSOES QUE EU PREENCHO NA MAO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rodar depois de: 01-carga-staging.sql  e  02-dimensoes-prontas.sql
--
--  As tabelas ja existem vazias, criadas la no arquivo 02. Aqui eu preencho
--  elas de verdade. Sao duas dimensoes e uma ponte:
--      dim_categoria       o "de-para" das grafias bagunçadas pras 7 categorias
--      dim_praca           uma linha por praca de atendimento
--      bridge_loja_praca   a ligacao N:N entre loja e praca, com o rateio
--
--  Regras que segui nas duas dimensoes:
--    * PK = surrogate key inteira (ja veio definida no 02 como IDENTITY)
--    * a chave natural (a grafia crua, o codigo da praca) fica guardada como atributo
--    * sempre insiro a linha -1 = "Nao Informado" ANTES do INSERT ... SELECT
--    * as tabelas stg_ eu nao toco - continuam intactas
--
--  Comandos usados aqui: INSERT ... VALUES, INSERT ... SELECT, SELECT DISTINCT,
--  JOIN, GROUP BY, CASE WHEN, REPLACE, UPPER, TRIM, TRANSLATE, CAST, MAX
-- =====================================================================================

-- =====================================================================================
--  DIM_CATEGORIA        grao: UMA GRAFIA DA ORIGEM
-- =====================================================================================
--  Guardo a grafia CRUA em categoria_origem e a versao ja padronizada em
--  nome_categoria (uma linha por grafia - varias grafias podem apontar pro
--  mesmo nome padronizado). Depois, la na fato, eu acho a linha certa
--  procurando por categoria_origem.
--  Primeiro insiro a linha -1. Depois, no INSERT ... SELECT DISTINCT, um CASE
--  traduz todas as grafias pras 7 categorias.
--  Pegadinha que quase caí: a ordem do CASE importa - "Racao Medicamentosa" e
--  Medicamento, entao preciso testar MED antes de RA (senao ela cai em Racao
--  por engano). Comparo tudo em UPPER e sem acento pra nao ter erro bobo.

INSERT INTO dim_categoria (sk_categoria, categoria_origem, nome_categoria, grupo_categoria)
VALUES (-1, 'N/I', 'Nao Informado', 'Nao Informado');

INSERT INTO dim_categoria (categoria_origem, nome_categoria, grupo_categoria)
SELECT DISTINCT
    "CategoriaProduto",
    CASE
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%MED%'    THEN 'Medicamento'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%PETISC%' THEN 'Petisco'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%RA%'     THEN 'Racao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%HIG%'    THEN 'Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%BRINQ%'  THEN 'Brinquedo'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%ACESS%'  THEN 'Acessorio'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%SERV%'   THEN 'Servico'
        ELSE 'Nao Informado'
    END AS nome_categoria,
    CASE
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%MED%'    THEN 'Saude e Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%PETISC%' THEN 'Alimentacao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%RA%'     THEN 'Alimentacao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%HIG%'    THEN 'Saude e Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%BRINQ%'  THEN 'Bem-estar'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%ACESS%'  THEN 'Bem-estar'
        WHEN UPPER(TRANSLATE("CategoriaProduto",
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) LIKE '%SERV%'   THEN 'Bem-estar'
        ELSE 'Nao Informado'
    END AS grupo_categoria
FROM stg_pedido;


-- =====================================================================================
--  DIM_PRACA  +  BRIDGE_LOJA_PRACA
-- =====================================================================================
--  A stg_loja_praca tem 48 linhas, porque a mesma loja aparece uma vez pra
--  cada praca que ela atende. Um GROUP BY por CodPraca colapsa isso em 12
--  pracas. Toda coluna que nao entra no GROUP BY precisa de uma funcao de
--  agregacao - usei MAX, que resolve bem aqui. E domicilios_com_pet vem
--  formatado tipo '148.000', entao preciso tirar o ponto de milhar antes de
--  converter pra numero.

INSERT INTO dim_praca (sk_praca, cod_praca, nome_praca, regional, domicilios_com_pet)
VALUES (-1, 'N/I', 'Nao Informado', 'Nao Informado', NULL);

INSERT INTO dim_praca (cod_praca, nome_praca, regional, domicilios_com_pet)
SELECT
    "CodPraca",
    MAX("NomePraca"),
    MAX("Regional"),
    MAX(CAST(REPLACE("DomiciliosComPet", '.', '') AS INTEGER))
FROM stg_loja_praca
GROUP BY "CodPraca";


-- -------------------------------------------------------------------------------------
--  A TABELA PONTE
-- -------------------------------------------------------------------------------------
--  Como uma loja entrega em mais de uma praca (é N:N), essa ligacao nao cabe
--  numa FK normal - precisa de uma tabela propria, com o FATOR DE RATEIO
--  dentro dela (os fatores de uma mesma loja somam 1,00 juntos). E essa ponte
--  usa o COD DA LOJA pra se ligar, nao a sk_loja.

INSERT INTO bridge_loja_praca (cod_loja, sk_praca, fator_publico)
SELECT
    sp."CodLoja",
    dp.sk_praca,
    CAST(sp."PercentualPublico" AS DECIMAL(6,4))
FROM stg_loja_praca sp
JOIN dim_praca dp ON dp.cod_praca = sp."CodPraca";


-- =====================================================================================
--  Depois disso eu confiro tudo rodando o 00-conferencia.sql (bloco "DEPOIS DO 03").
-- =====================================================================================
