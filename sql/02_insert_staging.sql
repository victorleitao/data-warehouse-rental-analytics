-- Processo de INSERT das tabelas fato e dimensão
-- INSERT dim_localizacao
INSERT INTO dim_localizacao (nome_bairro, zona_cidade, latitude, longitude)
SELECT
	TRIM(neighbourhood) AS nome_bairro,
	-- Tratamento de espaços e nulos
	NULLIF(TRIM(neighbourhood_group), '') AS zona_cidade,
	-- Média da latitude dos imóveis por bairro para estipular uma latitude média do bairro
	AVG(
		CASE
			WHEN latitude IS NULL OR TRIM(latitude) = '' THEN NULL
			WHEN LENGTH(REPLACE(latitude, '.', '')) > 3 AND latitude LIKE '-%'
				THEN (LEFT(REPLACE(latitude, '.', ''), 3) || '.' || SUBSTRING(REPLACE(latitude, '.', '') FROM 4))::NUMERIC
			ELSE REPLACE(latitude, ',', '.')::NUMERIC
		END
	)::NUMERIC(18,6) AS latitude,
	-- Média da longitude dos imóveis por bairro para estipular uma longitude média do bairro
	AVG(
		CASE
			WHEN longitude IS NULL OR TRIM(longitude) = '' THEN NULL
			WHEN LENGTH(REPLACE(longitude, '.', '')) > 3 AND longitude LIKE '-%'
				THEN (LEFT(REPLACE(longitude, '.', ''), 3) || '.' || SUBSTRING(REPLACE(longitude, '.', '') FROM 4))::NUMERIC
			ELSE REPLACE(longitude, ',', '.')::NUMERIC
		END
	)::NUMERIC(18,6) AS longitude
FROM stg_airbnb_listings
WHERE neighbourhood IS NOT NULL AND TRIM(neighbourhood) <> ''
GROUP BY TRIM(neighbourhood), NULLIF(TRIM(neighbourhood_group), '')
ORDER BY nome_bairro;

-- Validação do INSERT dim_localizacao
SELECT COUNT(*) FROM dim_localizacao;

SELECT * FROM dim_localizacao;

-- INSERT dim_acomodacao
INSERT INTO dim_acomodacao (tipo_quarto, nome_anuncio, noites_minimas)
SELECT
	-- Tratamento de espaços, valores nulos e em branco
	COALESCE(TRIM(room_type), 'Não Informado') AS tipo_quarto,
	COALESCE(NULLIF(TRIM(name), ''), 'Anúncio sem título') AS nome_anuncio,
	-- Deixando apenas os caracteres numéricos na coluna do tipo INT
	CASE
		WHEN minimum_nights IS NULL OR TRIM(minimum_nights) = '' THEN 1
		ELSE NULLIF(REGEXP_REPLACE(minimum_nights, '[^0-9]', '', 'g'), '')::INTEGER
	END AS noites_minimas
FROM stg_airbnb_listings
WHERE room_type IS NOT NULL AND TRIM(room_type) <> ''
GROUP BY
	COALESCE(TRIM(room_type), 'Não Informado'),
	COALESCE(NULLIF(TRIM(name), ''), 'Anúncio sem título'),
	CASE
		WHEN minimum_nights IS NULL OR TRIM(minimum_nights) = '' THEN 1
		ELSE NULLIF(REGEXP_REPLACE(minimum_nights, '[^0-9]', '', 'g'), '')::INTEGER
	END
ORDER BY tipo_quarto, nome_anuncio;

-- Validação do INSERT dim_acomodacao
SELECT COUNT(*) FROM dim_acomodacao;

SELECT * FROM dim_acomodacao;

-- INSERT fato_imoveis
INSERT INTO fato_imoveis (
	fk_localizacao,
	fk_acomodacao,
	preco_noite,
	disponibilidade_365,
	numero_avaliacoes
)
SELECT
	dl.id AS fk_localizacao,
	da.id AS fk_acomodacao,
	-- Tratamento de espaços, nulos e tipologia da coluna preco_noite
	CASE
		WHEN s.price IS NULL OR TRIM(s.price) = '' THEN 0.00
		ELSE COALESCE (
			NULLIF(
				REGEXP_REPLACE(
					REPLACE(REPLACE(s.price, '$', ''), ',', ''),
					'[^0-9.]', '', 'g'
				), ''
			)::NUMERIC(10,2),
			0.00
		)
	END AS preco_noite,
	-- Tratamento de espaços, nulos e tipologia da coluna disponibilidade_365
	CASE
		WHEN s.availability_365 IS NULL OR TRIM(s.availability_365) = '' THEN 0
		ELSE COALESCE(
			NULLIF(REGEXP_REPLACE(s.availability_365, '[^0-9]', '', 'g'), '')::INTEGER,
			0
		)
	END AS disponibilidade_365,
	-- Tratamento de espaços, nulos e tipologia da coluna numero_avaliacoes
	CASE
		WHEN s.number_of_reviews IS NULL OR TRIM(s.number_of_reviews) = '' THEN 0
		ELSE COALESCE(	
			NULLIF(REGEXP_REPLACE(s.number_of_reviews, '[^0-9]', '', 'g'), '')::INTEGER,
			0
		)
	END AS numero_avaliacoes
FROM stg_airbnb_listings s
-- JOIN para obter o id do bairro
JOIN dim_localizacao dl
	ON dl.nome_bairro = TRIM(s.neighbourhood)
-- JOIN para obter o id do tipo de acomodação
JOIN dim_acomodacao da
	ON da.tipo_quarto = COALESCE(TRIM(s.room_type), 'Não Informado')
	AND da.nome_anuncio = COALESCE(NULLIF(TRIM(s.name), ''), 'Anúncio sem título')
	AND da.noites_minimas = (
		CASE
			WHEN s.minimum_nights IS NULL OR TRIM(s.minimum_nights) = '' THEN 1
			ELSE COALESCE(NULLIF(REGEXP_REPLACE(s.minimum_nights, '[^0-9]', '', 'g'), '')::INTEGER, 1)
		END
	);

-- Validação do INSERT fato_imoveis
SELECT COUNT(*) FROM fato_imoveis;

SELECT * FROM fato_imoveis;

SELECT
	*
FROM fato_imoveis fi
JOIN dim_localizacao dl ON fi.fk_localizacao = dl.id
WHERE dl.nome_bairro = 'Joá'
ORDER BY fi.preco_noite DESC;