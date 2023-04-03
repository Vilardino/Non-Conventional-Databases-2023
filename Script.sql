CREATE EXTENSION postgis;

drop function IF EXISTS encontra_cidade;
drop function IF EXISTS encontra_ponto_por_cidade;
drop function IF EXISTS confere_ponto_cidade;

drop procedure IF EXISTS atualiza_descricao_Imagem;
drop procedure IF EXISTS insere_bolsista;
drop procedure IF EXISTS insere_camera;
drop procedure IF EXISTS insere_planodevoo;
drop procedure IF EXISTS insere_local;
drop procedure IF EXISTS insere_pesquisador;
drop procedure IF EXISTS insere_usuario;
drop procedure IF EXISTS MembrosExterno;
drop procedure IF EXISTS MembrosInterno;
drop procedure IF EXISTS insere_Imagem;
drop procedure IF EXISTS insere_orthomosaico;

drop TABLE IF EXISTS Imagem;
drop TABLE IF EXISTS MembrosInterno;
drop TABLE IF EXISTS MembrosExterno;
drop TABLE IF EXISTS Pesquisador;
drop TABLE IF EXISTS Bolsista;
DROP TABLE IF EXISTS "pontosDeControle";
drop TABLE IF EXISTS orthomosaico;
drop TABLE IF EXISTS "PlanoDeVoo";
drop TABLE IF EXISTS "LocalVoo";
drop TABLE IF EXISTS Camera;
drop TABLE IF EXISTS Usuario;
drop type IF EXISTS nome;
drop type IF EXISTS Orientado;

CREATE type Nome as (
        preNome varchar(20),
        sobreNome varchar(20)
    );
   

CREATE type Orientado as(

    inicio date,
    fim date,
    orientador char(11)

);


CREATE TABLE IF NOT EXISTS Usuario(
        CPF char(11) PRIMARY KEY,
        nome Nome NOT NULL,
        email varchar(50) NULL
);	

CREATE TABLE IF NOT EXISTS MembrosInterno(
    matricula varchar(50) PRIMARY KEY,
    CPF char(11) unique NOT NULL,
    FOREIGN KEY (CPF) REFERENCES Usuario (CPF)
);


CREATE TABLE IF NOT EXISTS MembrosExterno(
    idUserExterno serial PRIMARY KEY,
    CPF char(11) unique NOT NULL,
    FOREIGN KEY (CPF) REFERENCES Usuario (CPF)
);


CREATE TABLE IF NOT EXISTS Pesquisador (
        titulaçao varchar(30) NOT NULL,
        lattes varchar(256) NOT NULL,
        CPF char(11) PRIMARY KEY NOT NULL,
        FOREIGN KEY (CPF) REFERENCES Usuario (CPF)
    
);


CREATE TABLE IF NOT EXISTS bolsista (
    orientado Orientado[],
    CPF char(11) PRIMARY KEY NOT NULL,
    FOREIGN KEY (CPF) REFERENCES Usuario (CPF)
);


CREATE TABLE IF NOT EXISTS camera(
    idCamera serial PRIMARY KEY,
    marca varchar(100) NOT NULL,
    lente varchar(100) NOT NULL,
    modelo varchar(100) NOT NULL,
    larguraPixels int NOT NULL,
    alturaPixels int NOT NULL,
    codigoSerial varchar(50) NULL
);



CREATE TABLE IF NOT EXISTS "LocalVoo"(
    cnpj char(14) PRIMARY KEY,
    nome varchar(100) NOT NULL,
    campanha varchar NOT NULL,
    "dataDaCampanha" timestamp NOT NULL
);



CREATE TABLE IF NOT EXISTS "PlanoDeVoo"(
    idVoo serial PRIMARY KEY,
    altitude float NOT NULL,
    gsd float NOT NULL,
    arquivoAgisoft bytea NOT NULL,
    localidade GEOGRAPHY(POINT,4326) NOT NULL,
    cnpj char(14) REFERENCES "LocalVoo"(CNPJ)
);

CREATE TABLE IF NOT EXISTS orthomosaico(
    idOrthomosaico serial PRIMARY KEY,
    imagemOrtho bytea NOT NULL,
    arquivoGis bytea NULL,
    descricao varchar(256) NULL
);

CREATE TABLE IF NOT EXISTS "pontosDeControle"(
    id serial PRIMARY KEY,
	points geometry(point, 4674) NULL,
	"Tag" varchar NULL,
	"Long" float NULL,
	"Lat" float NULL,
    cnpj char(14) REFERENCES "LocalVoo"(cnpj),
	idOrthomosaico int NULL,
    FOREIGN KEY (idOrthomosaico) REFERENCES orthomosaico (idOrthomosaico)  
);

CREATE TABLE IF NOT EXISTS Imagem(
    idImagem serial PRIMARY KEY,
    imagem bytea NOT NULL,
    dataHora timestamp NOT NULL,
    descricao varchar(256) NULL,
    CPF_descricao char(11) NULL,
    CPF char(11) NOT NULL,
    idVoo int NOT NULL,
    idCamera int NOT NULL,
    idOrthomosaico int NULL,
    localidade_img GEOGRAPHY(POINT,4326) NULL,
	FOREIGN KEY (CPF) REFERENCES Usuario (CPF),
    FOREIGN KEY (CPF_descricao) REFERENCES Usuario (CPF),
	FOREIGN KEY (idVoo) REFERENCES "PlanoDeVoo" (idVoo),
	FOREIGN KEY (idCamera) REFERENCES Camera (idCamera),
	FOREIGN KEY (idOrthomosaico) REFERENCES orthomosaico (idOrthomosaico)   
) ;





-- Proc insere usuario
CREATE OR REPLACE PROCEDURE insere_usuario(CPF char(11), nome Nome, email varchar(50))
LANGUAGE SQL
AS $$
    INSERT INTO Usuario VALUES (CPF, nome, email);
$$;


-- Proc insere MembrosInterno
CREATE OR REPLACE PROCEDURE MembrosInterno(matricula varchar(50), CPF2 char(11), nome Nome, email varchar(50))
AS $$
	BEGIN 
	IF NOT EXISTS(SELECT * FROM usuario U WHERE U.cpf = CPF2) THEN 
	CALL insere_usuario(CPF2, nome, email);
	END IF;		
    INSERT INTO MembrosInterno VALUES (matricula, CPF2);
	END;
$$
LANGUAGE plpgsql;

-- insere MembrosExterno
CREATE OR REPLACE PROCEDURE MembrosExterno(CPF2 char(11), nome Nome, email varchar(50))
AS $$
BEGIN 
	IF NOT EXISTS(SELECT * FROM usuario U WHERE U.cpf = CPF2) THEN 
	CALL insere_usuario(CPF2, nome, email);
	END IF;	
    INSERT INTO MembrosExterno(CPF) VALUES (CPF2);
    end;
$$ LANGUAGE plpgsql;


--insere pesquisador
CREATE OR REPLACE PROCEDURE insere_pesquisador(titulaçao varchar(30), lattes varchar(256), CPF2 char(11))
AS $$
BEGIN
    if NOT exists(select * from bolsista p WHERE cpf2=p.cpf) THEN
        INSERT INTO Pesquisador VALUES (titulaçao, lattes, CPF2);
    else
        RAISE NOTICE 'Não é possivel adicionar um pesquisadoor que já é bolsista';
    end if;
    
END;
$$ LANGUAGE plpgsql;




--insere bolsista 
CREATE
OR REPLACE procedure insere_bolsista(
    CPF2 varchar(11),
    nome Nome,
    email varchar(50),
    orientado_p Orientado
) as $$
BEGIN
    IF EXISTS(SELECT * FROM pesquisador p WHERE orientado_p.orientador = p.cpf) THEN 
        if NOT exists(select * from pesquisador p WHERE cpf2=p.cpf) THEN
            if EXISTS(select * from Bolsista b where b.cpf=cpf2 and b.orientado[array_length(b.orientado,1)].fim < orientado_p.inicio) THEN
                UPDATE Bolsista set orientado[array_length(orientado,1)] = orientado_p where cpf = cpf2 ;
            else
                if NOT EXISTS(select * from Bolsista b where b.cpf=cpf2) THEN
                    INSERT INTO Bolsista VALUES (array[orientado_p], CPF2);
                ELSE
                RAISE NOTICE 'Não é possivel adicionar mais de um orientador por periodo de tempo';
                END IF;
                END IF;
        else
            RAISE NOTICE 'Não é possivel adicionar um bolsista que já é pesquisador';
        end if;
    ELSE
        RAISE NOTICE 'Orientador não existe.';
    END IF;
END;
$$ LANGUAGE plpgsql;



--insere camera
CREATE OR REPLACE PROCEDURE insere_camera(	marca varchar(100),
											lente varchar(100),
											modelo varchar(100),
											larguraPixels int,
											alturaPixels int,
											codigoSerial int)
    LANGUAGE SQL
    AS $$
        INSERT INTO Camera(	marca,
							lente,
							modelo,
							larguraPixels,
							alturaPixels,
							codigoSerial)
							VALUES (marca,
                                    lente,
                                    modelo,
                                    larguraPixels,
                                    alturaPixels,
                                    codigoSerial);
$$;



--insere local
CREATE OR REPLACE PROCEDURE insere_local(cnpj char(14),
                                        nome varchar(100),
                                        campanha varchar,
                                        "dataDaCampanha" timestamp )
LANGUAGE SQL
AS $$
    INSERT INTO "LocalVoo" VALUES (cnpj, nome, campanha, "dataDaCampanha");
$$;


--insere PlanoDeVoo
CREATE OR REPLACE PROCEDURE insere_planodevoo ( cnpj char(14),
                                                altitude float,
                                                gsd float,
                                                arquivoAgisoft bytea,
                                                localidade GEOGRAPHY(POINT,4326)) --ST_GeographyFromText('POINT(-46.633309 -23.550520)')
LANGUAGE SQL
AS $$
    INSERT INTO "PlanoDeVoo"( altitude,
							gsd,
							arquivoAgisoft,
							localidade,
                            cnpj)
							VALUES ( altitude,
							gsd,
							arquivoAgisoft,
							localidade,
                            cnpj)
$$;

CREATE OR REPLACE PROCEDURE insere_pontos_de_controle(points geometry(point, 4674),
                                                        "Tag" varchar,
                                                        "Long" float,
                                                        "Lat" float,
                                                        cnpj char(14),
                                                        idOrthomosaico int)
LANGUAGE SQL
AS $$
INSERT INTO "pontosDeControle"(points,
                                "Tag",
                                "Long",
                                "Lat",
                                cnpj,
                                idOrthomosaico
                                )
                            values (points,
                                "Tag",
                                "Long",
                                "Lat",
                                cnpj,
                                idOrthomosaico)
$$;

CREATE OR REPLACE PROCEDURE insere_orthomosaico(imagemOrtho bytea,
                                                arquivoGis bytea, 
                                                descricao varchar(256))
LANGUAGE SQL
AS $$
INSERT INTO orthomosaico(   imagemOrtho,
                            arquivoGis,
                            descricao)
                            values (imagemOrtho,
                                    arquivoGis,
                                    descricao)
$$;


CREATE OR REPLACE PROCEDURE insere_Imagem(
    imagem bytea,
    dataHora timestamp,
    CPF char(11),
    idVoo int,
    idCamera int,
    localidade_img GEOGRAPHY(POINT,4326))
LANGUAGE SQL
AS $$
INSERT INTO Imagem( imagem,
                    dataHora,
                    CPF,
                    idVoo,
                    idCamera,
                    localidade_img)
                    values( imagem,
                            dataHora,
                            CPF,
                            idVoo,
                            idCamera,
                            localidade_img)
$$;


-- Atualiza com a descrição e quem a colocou a descrição
CREATE OR REPLACE PROCEDURE atualiza_descricao_Imagem(
	idImagemP int,
	descricaoP varchar(256),
    CPF_descricaoP char(11))
LANGUAGE SQL
AS $$
	UPDATE Imagem SET descricao = descricaoP, CPF_descricao = CPF_descricaoP WHERE idImagem = idImagemP;
$$;

-- Atualiza com o id do orthomosaico que ela participa
CREATE OR REPLACE PROCEDURE atualiza_Orthomosaico_da_Imagem(
	idImagemP int,
	idOrthomosaicoP int)
LANGUAGE SQL
AS $$
	UPDATE Imagem SET idOrthomosaico = idOrthomosaicoP WHERE idImagem = idImagemP;
$$;

-----------------------------------------------------------------------------
--------------- Verifica se o ponto está contido no poligono ---------------
CREATE OR REPLACE FUNCTION confere_ponto_cidade (
    id_ponto INT,
    id_cidade INT
)RETURNS boolean

AS $$
DECLARE
pertence boolean;
BEGIN
    SELECT ST_Contains(m.geom, p.geom) INTO pertence
    FROM "Municipios_MT_2021" m
    JOIN pontos p ON ST_Contains(m.geom, p.geom)
    WHERE p.id = id_ponto and m.id = id_cidade;
	RETURN CASE
        WHEN pertence THEN true
        ELSE false
    END;
END;
$$ LANGUAGE plpgsql;


-----------------------------------------------------------------------------
--------------- Passa a cidade e encontra os pontos -------------------------
CREATE OR REPLACE FUNCTION encontra_ponto_por_cidade (
    id_cidade INT
)RETURNS SETOF geometry

AS $$
DECLARE
pontos geometry;
BEGIN FOR pontos IN 
    SELECT p.geom
    FROM "Municipios_MT_2021" m
    JOIN pontos p ON ST_Contains(m.geom, p.geom)
    WHERE m.id = id_cidade
	LOOP
	RETURN NEXT pontos;
	END LOOP;
    
	RETURN;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--------------- Encontra a cidade através de um ponto ---------------
CREATE OR REPLACE FUNCTION encontra_cidade (
    id_ponto INT
)RETURNS text

AS $$
DECLARE
nome_cidade text;
BEGIN
    SELECT m.nm_mun INTO nome_cidade
    FROM "Municipios_MT_2021" m
    JOIN pontos p ON ST_Contains(m.geom, p.geom)
    WHERE p.id = id_ponto;
	RETURN nome_cidade;
END;
$$ LANGUAGE plpgsql;

