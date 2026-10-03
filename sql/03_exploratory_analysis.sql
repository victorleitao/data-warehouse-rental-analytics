-- Respondendo a problemática dde negócio:
-- Quais bairros geram mais receita potencial e como definir preços competitivos?

-- Perguntas guia:
-- 1. Quais bairros possuem os imóveis mais caros?
-- 2. Qual o preço médio por tipo de acomodação?
-- 3. Existe relação entre disponibilidade e preço?
-- 4. Quais bairros possuem maior potencial de faturamento anual?
-- 5. Quais imóveis parecem subvalorizados ou supervalorizados?
-- 6. Quais são os bairros mais caros (maior preço médio da diária)?
-- 7. Quais bairros possuem o maior potencial de faturamento total e médio?


-- 1. Quais bairros possuem os imóveis mais caros?
-- Agrupando por bairro
SELECT
	dl.nome_bairro,
	ROUND(MAX(fi.preco_noite), 2) AS preco_maximo
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
JOIN dim_acomodacao da ON fi.fk_acomodacao = da.id
GROUP BY dl.nome_bairro
ORDER BY preco_maximo DESC;

-- Agrupando por imóvel
SELECT
	dl.nome_bairro,
	da.nome_anuncio AS anuncio,
	ROUND(MAX(fi.preco_noite), 2) AS preco_maximo
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
JOIN dim_acomodacao da ON fi.fk_acomodacao = da.id
GROUP BY dl.nome_bairro, da.nome_anuncio
ORDER BY preco_maximo DESC;

-- 2. Qual o preço médio por tipo de acomodação?
SELECT
	da.tipo_quarto AS tipo_quarto,
	COUNT(fi.id) AS total_imoveis,
	ROUND(AVG(fi.preco_noite), 2) AS preco_medio_absoluto_diaria,
	ROUND(AVG(NULLIF(fi.preco_noite, 0)), 2) AS preco_medio_nao_nulos_diaria
FROM fato_imoveis fi
JOIN dim_acomodacao da ON fi.fk_acomodacao = da.id
GROUP BY tipo_quarto
ORDER BY preco_medio_nao_nulos_diaria DESC;

-- 3. Existe relação entre disponibilidade e preço?
-- Criação de uma faixa de disponibilidade para ser possível a análise
SELECT
	CASE
		WHEN fi.disponibilidade_365 <= 90 THEN '1. Baixa Disponibilidade (Alta Procura: 0-90 dias)'
		WHEN fi.disponibilidade_365 BETWEEN 91 AND 180 THEN '2. Média Disponibilidade (81-180 dias)'
		WHEN fi.disponibilidade_365 BETWEEN 181 AND 270 THEN '3. Alta Disponibilidade (181-270 dias)'
		ELSE '4. Muito Alta Disponibilidade (Baixa Procura > 270 dias)'
	END AS faixa_disponibilidade,
	COUNT(fi.id) AS quantidade_imoveis,
	ROUND(AVG(NULLIF(fi.preco_noite, 0)), 2) AS preco_media_diaria,
	ROUND(AVG(365 - fi.disponibilidade_365), 1) AS media_dias_ocupados
FROM fato_imoveis fi
WHERE fi.preco_noite > 0
GROUP BY 1
ORDER BY 1

-- Utilização do Coeficiente de Pearson para verificar a relação causal entre as variáveis disponibilidade e preço
SELECT
	ROUND(CORR(fi.disponibilidade_365, fi.preco_noite)::NUMERIC, 4) AS coeficiente_correlacao
FROM fato_imoveis fi
WHERE fi.preco_noite > 0;

-- 4. Quais bairros possuem maior potencial de faturamento anual?
SELECT
	dl.nome_bairro,
	COUNT(fi.id) AS total_imoveis,
	ROUND(AVG(NULLIF(fi.preco_noite, 0)), 2) AS preco_medio_diaria,
	ROUND(AVG(365 - fi.disponibilidade_365), 1) AS media_dias_ocupados_ano,
	ROUND(SUM((365 - fi.disponibilidade_365) * fi.preco_noite), 2) AS faturamento_potencial_total_bairro,
	ROUND(AVG((365 - fi.disponibilidade_365) * fi.preco_noite), 2) AS faturamento_potencial_medio_imovel,
	-- Coluna que vai considerar os 365 dias do ano pra verificar o faturamento máximo possível
	ROUND(SUM(365 * fi.preco_noite), 2) AS faturamento_maximo_total_bairro,
	ROUND(AVG(365 * fi.preco_noite), 2) AS faturamento_maximo_medio_imovel
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
WHERE fi.preco_noite > 0
GROUP BY dl.nome_bairro
ORDER BY faturamento_potencial_total_bairro DESC;
--ORDER BY faturamento_maximo_total_bairro DESC;

-- 5. Quais imóveis parecem subvalorizados ou supervalorizados?
-- Por bairro
WITH analise_precos AS (
	SELECT
		fi.id AS id_fato,
		dl.nome_bairro,
		fi.preco_noite,
		AVG(NULLIF(fi.preco_noite, 0)) OVER(
			PARTITION BY fi.fk_localizacao, da.tipo_quarto
		) AS preco_medio_categoria
	FROM fato_imoveis fi
	JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
	JOIN dim_acomodacao da ON fi.fk_acomodacao = da.id
	WHERE fi.preco_noite > 0
),
classificacao_imoveis AS (
	SELECT
		nome_bairro,
		-- Considerando a subjetividade dos termos "supervalorizado" e "subvalorizado", aqui esse parâmetro foi definido lelvando-se em consideração o seguinte:
		-- Valores duas vezes maior que a média: Supervalorizado
		-- Valores equivalentes à metade ou menos que a média: Subvalorizado
		CASE
			WHEN preco_noite >= (preco_medio_categoria * 2.0) THEN 'Supervalorizado'
			WHEN preco_noite <= (preco_medio_categoria * 0.5) THEN 'Subvalorizado'
			ELSE 'Dentro da Média'
		END AS classificacao
	FROM analise_precos
)
SELECT
	nome_bairro,
	COUNT(*) AS total_imoveis,
	-- Contagem de cada categoria por bairro
	COUNT(*) FILTER (WHERE classificacao = 'Supervalorizado') AS qtd_supervalorizados,
	COUNT(*) FILTER (WHERE classificacao = 'Subvalorizado') AS qtd_subvalorizados,
	COUNT(*) FILTER (WHERE classificacao = 'Dentro da Média') AS qtd_dentro_media,
	-- Percentual de imóveis fora da curva no bairro
	ROUND(
		(COUNT(*) FILTER (WHERE classificacao IN ('Supervalorizado', 'Subvalorizado'))::NUMERIC / COUNT(*)) * 100,
		2
	) AS pct_fora_da_media
FROM classificacao_imoveis
GROUP BY nome_bairro
HAVING COUNT(*) >= 100
--ORDER BY total_imoveis DESC;
ORDER BY pct_fora_da_media DESC;
--ORDER BY qtd_supervalorizados DESC;
--ORDER BY qtd_subvalorizados DESC;

-- Por imóvel
WITH analise_precos AS (
	SELECT
		fi.id AS id_fato,
		da.nome_anuncio,
		dl.nome_bairro,
		da.tipo_quarto,
		fi.preco_noite,
		AVG(NULLIF(fi.preco_noite, 0)) OVER(
			PARTITION BY fi.fk_localizacao, da.tipo_quarto
		) AS preco_medio_categoria
	FROM fato_imoveis fi
	JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
	JOIN dim_acomodacao da ON fi.fk_acomodacao = da.id
	WHERE fi.preco_noite > 0
)
SELECT
	id_fato,
	nome_anuncio,
	nome_bairro,
	tipo_quarto,
	preco_noite,
	ROUND(preco_medio_categoria, 2) AS media_bairro_categoria,
	ROUND(((preco_noite - preco_medio_categoria) / preco_medio_categoria) * 100, 2) AS desvio_percentual,
	CASE
		WHEN preco_noite >= (preco_medio_categoria * 2.0) THEN 'Supervalorizado'
		WHEN preco_noite <= (preco_medio_categoria * 0.5) THEN 'Subvalorizado'
		ELSE 'Dentro da Média'
	END AS classificacao
FROM analise_precos
WHERE preco_noite >= (preco_medio_categoria * 2.0)
   OR preco_noite <= (preco_medio_categoria * 0.5)
ORDER BY desvio_percentual DESC;

-- 6. Quais são os bairros mais caros (maior preço médio da diária)?
SELECT
	dl.nome_bairro,
	COUNT(fi.id) AS total_imoveis,
	ROUND(AVG(fi.preco_noite), 2) AS preco_medio_absoluto_diaria,
	ROUND(AVG(NULLIF(fi.preco_noite, 0)), 2) AS preco_medio_nao_nulos_diaria,
	ROUND(MIN(NULLIF(fi.preco_noite, 0)), 2) AS preco_minimo,
	ROUND(MAX(fi.preco_noite), 2) AS preco_maximo
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
GROUP BY dl.nome_bairro
HAVING COUNT(fi.id) >= 10
ORDER BY preco_medio_nao_nulos_diaria DESC;
--ORDER BY preco_maximo DESC;

-- 7. Quais bairros possuem o maior potencial de faturamento total e médio?
SELECT
	dl.nome_bairro,
	COUNT(fi.id) AS total_imoveis,
	ROUND(AVG(365 - fi.disponibilidade_365), 1) AS media_dias_ocupados,
	ROUND(SUM((365 - fi.disponibilidade_365) * fi.preco_noite), 2) AS receita_potencial_total,
	ROUND(AVG((365 - fi.disponibilidade_365) * fi.preco_noite), 2) AS receita_potencial_media_imovel
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
GROUP BY dl.nome_bairro
ORDER BY receita_potencial_total DESC;