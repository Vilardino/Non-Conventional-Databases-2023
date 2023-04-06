import psycopg2
import os


# Conecta ao banco de dados
conn = psycopg2.connect(
    "dbname=geoDatabase user=postgres password=postgis host=localhost")


print('\n\nBem Vindo ao Sistemas de Gerenciamento de dados Georeferênciados!')


def isValid(res):
    if res.isdigit():
        return
    else:
        print('Opção Inválida, por favor tente novamente.')


def cadastrarUsuario():
    while True:
        res = input(
            '\nCadastrar Usuário:\n1:Organização Interna\n2:Organização Externa\n')
        isValid(res)
        res = int(res)
        if (res == 1):
            with conn.cursor() as cur:
                nome = input('Digite o nome do usuário: ')
                sobrenome = input('Digite o sobrenome do usuário: ')
                cpf = input('Digite o CPF do NOVO usuário: ')
                mat = input('Digite a Mátricula do NOVO usuário: ')
                email = input('Digite o email do NOVO usuário: ')
                try:
                    cur.execute("CALL MembrosInterno(%s, %s, (%s, %s), %s)",
                                (mat, cpf, nome, sobrenome, email))
                    conn.commit()
                except psycopg2.Error as e:
                    # Se ocorrer um erro, exibe a mensagem de erro e faz o rollback da transação
                    print("Ocorreu um erro:", e)
                    conn.rollback()

            cadastrar = input(
                '\nCadastrar Interno:\n1:Pesquisador\n2:Bolsista\nDigite qualquer outra coisa se não deseja cadastrar o interno ou me passa um pix \n')
            if cadastrar == '1':
                cadastrarPesquisador(cpf)
            elif cadastrar == '2':
                cadastrarBolsista(cpf, nome, sobrenome, email)
            break

        elif (res == 2):
            with conn.cursor() as cur:
                nome = input('Digite o nome do NOVO usuário: ')
                sobrenome = input('Digite o sobrenome do NOVO usuário: ')
                cpf = input('Digite o CPF do NOVO usuário: ')
                email = input('Digite o email do NOVO usuário: ')
                try:
                    cur.execute("CALL MembrosExterno( %s, (%s, %s), %s)",
                                (cpf, nome, sobrenome, email))
                    conn.commit()
                except psycopg2.Error as e:
                    # Se ocorrer um erro, exibe a mensagem de erro e faz o rollback da transação
                    print("Ocorreu um erro:", e)
                    conn.rollback()
            break

        else:
            print('Opção Inválida, por favor tente novamente.')


def cadastrarPesquisador(CPF):
    with conn.cursor() as cur:
        titulaçao = input('Qual a titulação do pesquisador? ')
        lattes = input('Qual o perfil lattes do pesquisador? ')
        try:
            cur.execute('CALL insere_pesquisador(%s, %s, %s)',
                        (titulaçao, lattes, CPF))
            conn.commit()
        except psycopg2.Error as e:
            # Se ocorrer um erro, exibe a mensagem de erro e faz o rollback da transação
            print("Ocorreu um erro: ", e)
            conn.rollback()

    return


def cadastrarBolsista(CPF, nome, sobrenome, email):
    with conn.cursor() as cur:
        dataInicio = input(
            'Digite a data de início da Orientaçâo (Ex.:YYYY-MM-DD): ')
        dataFim = input(
            'Insira o final do periodo de orientação (Ex. YYYY-MM-DD): ')
        CPF_orientador = input('Digite o CPF do Orientador: ')
        try:
            cur.execute('CALL insere_bolsista(%s,(%s, %s), %s, (%s, %s, %s ))',
                        (CPF, nome, sobrenome, email, dataInicio, dataFim, CPF_orientador))
            conn.commit()
        except psycopg2.Error as e:
            # Se ocorrer um erro, exibe a mensagem de erro e faz o rollback da transação
            print("Ocorreu um erro:", e)
            conn.rollback()


def planoDeVoo():
    print('Salvar Plano de Voo')
    cnpj = input('\nDigite o CNPJ do Local: ')
    altitude = float(input('Altitude do Voo: '))
    gsd = float(input('Qual o GSD estimado: '))
    diretorio = input('Entre com o diretório da arquivo:')
    with open(diretorio, "rb") as f:
        arquivo = f.read()
    lat = float(input('Entre com o valor da latitude do local: '))
    log = float(input('Entre com o valor da longitude do local: '))
    with conn.cursor() as cur:
        cur.execute("CALL insere_planodevoo(%s, %s, %s, %s, ST_GeographyFromText('POINT(%s %s)'))",
                    (cnpj, altitude, gsd, arquivo, lat, log))
        conn.commit()


def defineLocal():
    print('Local de Voo')
    nome = input('Insira o nome do Local do Voo: ')
    cnpj = input('Informe o CNPJ: ')
    campanha = input('Insira o nome da campanha: ')
    dataDaCampanha = input('Insira a data da campanha: ')
    with conn.cursor() as cur:
        try:
            cur.execute('CALL insere_local(%s, %s, %s, %s)',
                        (cnpj, nome, campanha, dataDaCampanha))
            conn.commit()
        except psycopg2.Error as e:  # Se ocorrer um erro, exibe a mensagem de erro e faz o rollback da transação
            print("Ocorreu um erro:", e)
            conn.rollback()


def imagens():
    from exif import Image
    import datetime
    print('''
    Para inserir as imagens crie uma pasta coloque as imagens desejadas depois
    copie o diretório da pasta correspondente e cole no campo quando solicitado''')
    CPF = input('Digite o seu CPF: ')
    with conn.cursor() as cur:
        cur.execute('SELECT * FROM "LocalVoo"')
        list_local_voo = cur.fetchall()
        for i in list_local_voo:
            print(list_local_voo.index(i), ':', 'Local:', i[1], 'CNPJ:', i[0])
        res = int(input('Escolha o Local do Voo: '))
        cur.execute(
            f"SELECT * FROM planodevoo where cnpj = '{list_local_voo[res][0]}'")
        list_plano_voo = cur.fetchall()
        for i in list_plano_voo:
            print(list_plano_voo.index(i), ':',
                  ' Altitude:', i[1], ' GSD:', i[2])
        res_voo = int(input('Escolha o plano de voo: '))
        cur.execute('SELECT * FROM camera')
        list_camera = cur.fetchall()
        for i in list_camera:
            print(list_camera.index(i), ':', 'Modelo:', i[3], 'Marca:', i[1])
        res_camera = int(input('Escolha o tipo da camera: '))
        diretorio = input('Insira o diretório da pasta imagens: ')
        # Problemas aqui ele não está recebendo somente o valor
        idVoo = (list_plano_voo[res_voo][0])
        idCamera = (list_camera[res_camera][0])
        # C:\Users\phcmo\OneDrive\Doutorado\2022_2\DBNC\Project\python\pics
        for diretorio, subpastas, arquivos in os.walk(diretorio):
            for arquivo in arquivos:
                with open(diretorio + '\\' + arquivo, "rb") as f:
                    img = Image(f)
                    if (img.has_exif):
                        lat = img.get('gps_latitude')
                        lat = lat[2]
                        log = img.get('gps_longitude')
                        log = log[2]
                        coordenada = "ST_GeographyFromText('POINT(%s %s)')", (
                            lat, log)
                        dataHora = img.get('datetime_original')
                        dataHora = dataHora[:10].replace(
                            ':', '-') + dataHora[10:]
                    else:
                        DateSys = datetime.datetime.now()
                        dataHora = DateSys.strftime('%Y-%m-%d %H:%M:%S')
                with open(diretorio + '\\' + arquivo, "rb") as f:
                    imagem = f.read()
                    cur.execute("CALL insere_Imagem(%s, %s, %s, %s, %s, ST_GeographyFromText('POINT(%s %s)'))",
                                (imagem, dataHora, CPF, idVoo, idCamera, lat*-1, log*-1))
                    conn.commit()


def test():
    import csv
    print('Inserir Orthomosaico')
    diretorioOrthomosaico = input(
        '\nInsira o diretório com o nome do arquivo do Orthomosaico: ')
    with open(diretorioOrthomosaico, "rb") as arq1:
        imagemOrthomosaico = arq1.read()
    ditetorioArquivoGis = input(
        'Insira o diretório com o nome do arquivo do Arquivo GIS: ')
    with open(ditetorioArquivoGis, "rb") as arq2:
        arquivoGis = arq2.read()

    descrição = input(
        'Escreva algum comentário sobre a imagem, caso contrário deixe vazio: ')
    with conn.cursor() as cur:
        cur.execute("CALL insere_orthomosaico(%s, %s, %s)",
                    (imagemOrthomosaico, arquivoGis, descrição))
        conn.commit()
    while True:
        res = input(
            '\nDeseja Inserir os pontos de controle:\n1:SIM\n2:NÃO\n')
        isValid(res)
        res = int(res)
        if (res == 1):
            with conn.cursor() as cur:
                cur.execute('SELECT idorthomosaico FROM orthomosaico')
                list_local_voo = cur.fetchall()
            diretorioCsv = input(
                '\nInsira o "diretório + nome_do_arquivo" csv dos pontos GPS: ')
            with open(diretorioCsv) as arquivo_csv:
                pontos = csv.reader(arquivo_csv, newline='')
                print(pontos)
        elif (res == 2):
            return
        else:
            return


def test2(idortho=None):
    import pandas as pd
    cnpj = '12345678912301'
    diretorioCsv = 'C:\\Users\\phcmo\\OneDrive\\Doutorado\\2022_2\\DBNC\\Project\\python\\points\\Sorriso.csv'
    with open(diretorioCsv) as arquivo_csv:
        pontos = pd.read_csv(arquivo_csv, header=None)
    for i in range(len(pontos)):
        tag = pontos.iloc[i, 0]
        lon = pontos.iloc[i, 1]
        lat = pontos.iloc[i, 2]
        with conn.cursor() as cur:
            cur.execute("CALL insere_pontos_de_controle(ST_MakePoint(%s, %s), %s, %s, %s, %s, %s)",
                        (lon, lat, tag, lon, lat, cnpj, idortho))
            conn.commit()


def test3():
    import rasterio
    import psycopg2

    # Abre o arquivo raster com o Rasterio
    with rasterio.open("python/ortho/IMA_Sorriso.tif") as src:
        # Extrai os metadados do raster
        meta = src.meta

        # Cria uma nova tabela no PostGIS para armazenar o raster
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE t_raster (rid serial PRIMARY KEY, rast raster)")
            conn.commit()

        # Carrega o conteúdo do arquivo raster para o PostGIS
        with conn.cursor() as cur:
            with open("python/ortho/IMA_Sorriso.tif", "rb") as f:
                cur.execute(
                    "INSERT INTO your_table (rast) VALUES (ST_SetBandNoDataValue(ST_AddBand(ST_MakeEmptyRaster(%(width)s, %(height)s, %(resolution)s, %(bounds)s), 1), 1, %(nodata)s)) RETURNING rid;",
                    {
                        "width": meta["width"],
                        "height": meta["height"],
                        "resolution": meta["transform"][0],
                        "bounds": meta["bounds"],
                        "nodata": meta["nodata"]
                    },
                    psycopg2.Binary(f.read()),
                )

    # Fecha a conexão com o banco de dados PostGIS
    conn.close()


######################################################### MENU PRINCIPAL #########################################################
while True:
    res = input('''\nEscolha as opções a seguir:
    1:Cadastrar Usuário
    2:Cadastrar Local "Campo"
    3:Salvar Plano de Voo
    4:Inserir imagens
    5:Inserir Orthomosaico
    6:Inserir descrição
    7:Inserir pontos de controle
    8:Testes dev\n''')
    isValid(res)
    res = int(res)
    if (res >= 1 and res <= 8):
        if res == 1:
            cadastrarUsuario()
        if res == 2:
            defineLocal()
        if res == 3:
            planoDeVoo()
        if res == 4:
            imagens()
        if res == 8:
            test3()
        break
    else:
        print('Opção Inválida, por favor tente novamente.')
