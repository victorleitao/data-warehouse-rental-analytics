-- Processso de criação da tabela de staging
DROP TABLE IF EXISTS stg_airbnb_listings;

CREATE TABLE stg_airbnb_listings (
	id TEXT,
	name TEXT,
	host_id TEXT,
	host_profile_id TEXT,
	host_name TEXT,
	neighbourhood_group TEXT,
	neighbourhood TEXT,
	latitude TEXT,
	longitude TEXT,
	room_type TEXT,
	price TEXT,
	minimum_nights TEXT,
	number_of_reviews TEXT,
	last_review TEXT,
	reviews_per_month TEXT,
	calculated_host_listings_count TEXT,
	availability_365 TEXT,
	number_of_reviews_ltm TEXT,
	license TEXT
);

-- Cópia dos dados do CSV para a tabela de staging
COPY stg_airbnb_listings (
	id,
    name,
    host_id,
    host_profile_id,
    host_name,
    neighbourhood_group,
    neighbourhood,
    latitude,
    longitude,
    room_type,
    price,
    minimum_nights,
    number_of_reviews,
    last_review,
    reviews_per_month,
    calculated_host_listings_count,
    availability_365,
    number_of_reviews_ltm,
    license
)
-- Origem ocultada por questões de segurança
FROM 'C:/.../listings.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ';',
	QUOTE '"',
	ESCAPE '"',
	ENCODING 'UTF8'
);

-- Validação da tabela de staging
SELECT * FROM public.stg_airbnb_listings

SELECT COUNT(*) FROM public.stg_airbnb_listings;

SELECT id, name, neighbourhood, price, latitude, longitude
FROM public.stg_airbnb_listings
LIMIT 15;

-- Processo de criação das tabelas dimensão/fato
DROP TABLE IF EXISTS dim_localizacao;
DROP TABLE IF EXISTS dim_acomodacao;

-- Dimensão de Localizacação
CREATE TABLE dim_localizacao (
	id SERIAL PRIMARY KEY,
	nome_bairro VARCHAR(100) NOT NULL,
	zona_cidade VARCHAR(50),
	latitude NUMERIC(18,6),
	longitude NUMERIC(18,6)
);

-- Dimensão de Acomodação
CREATE TABLE dim_acomodacao (
	id SERIAL PRIMARY KEY,
	tipo_quarto VARCHAR(50) NOT NULL,
	nome_anuncio TEXT,
	noites_minimas INT
);

-- Fato Imóveis
DROP TABLE IF EXISTS fato_imoveis;

CREATE TABLE fato_imoveis (
	id SERIAL PRIMARY KEY,
	fk_localizacao INT NOT NULL,
	fk_acomodacao INT NOT NULL,
	preco_noite NUMERIC(10,2),
	disponibilidade_365 INT,
	numero_avaliacoes INT,
	-- Declaração de chaves estrangeiras
	FOREIGN KEY (fk_localizacao) REFERENCES dim_localizacao(id) ON DELETE CASCADE,
	FOREIGN KEY (fk_acomodacao) REFERENCES dim_acomodacao(id) ON DELETE CASCADE
);