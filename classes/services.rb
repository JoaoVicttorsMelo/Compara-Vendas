# Importação das bibliotecas necessárias
require 'sqlite3'                # Biblioteca para interação com bancos de dados SQLite
require 'tiny_tds'               # Biblioteca para interação com bancos de dados SQL Server
require 'yaml'                   # Biblioteca para manipulação de arquivos YAML
require 'logger'                 # Biblioteca para logging de informações e erros
require 'fileutils'              # Biblioteca para manipulação de arquivos e diretórios

# Importação de arquivos relativos ao projeto
require_relative 'filial_ip'    # Modelo para acessar a tabela filiais_ip
require_relative '../lib/conexao_banco'  # Módulo para gerenciar a conexão com o banco de dados
require_relative File.join(__dir__, '..', 'lib', 'util')  # Utilitários adicionais

# Definição da classe Services responsável por diversos serviços relacionados a banco de dados
class Services
  include ConexaoBanco  # Inclusão do módulo de conexão com banco de dados
  include Util           # Inclusão do módulo de utilitários


  # Metodo inicializador da classe
  def initialize(db = nil)
    setup_logger            # Configura o logger para registrar informações e erros
    @db = db                # Atribui o banco de dados fornecido à variável de instância
    abrir_conexao_banco_lite  # Abre a conexão com o banco de dados SQLite
  end

  private

  # Configura o logger para registrar logs no arquivo especificado
  def setup_logger
    project_root = File.expand_path(File.join(__dir__, '..'))  # Define o diretório raiz do projeto
    log_dir = File.join(project_root, 'log')                    # Define o diretório de logs
    @log_file = File.join(log_dir, 'database.log')              # Define o caminho do arquivo de log

    ensure_log_file_exists  # Garante que o arquivo de log exista e seja gravável

    shift_age = 5                            # Define a quantidade de arquivos de log antigos a serem mantidos
    shift_size = converter_mb_para_byte(10)  # Define o tamanho máximo do arquivo de log em bytes

    @logger = Logger.new(@log_file, shift_age, shift_size)  # Inicializa o logger com rotação de arquivos
    @logger.level = Logger::INFO                           # Define o nível de log para INFO

    @logger.info("Logger iniciado com sucesso")            # Log de inicialização bem-sucedida
  rescue StandardError => e
    # Em caso de erro na configuração do logger, exibe mensagem no console e usa STDOUT
    p "Erro ao configurar logger: #{e.message}"
    p "Stacktrace: #{e.backtrace.join("\n")}"
    @logger = Logger.new(STDOUT)
  end

  # Garante que o arquivo de log exista e seja gravável
  def ensure_log_file_exists
    FileUtils.mkdir_p(File.dirname(@log_file))  # Cria o diretório de log caso não exista

    unless File.exist?(@log_file)
      FileUtils.touch(@log_file)  # Cria o arquivo de log se ele não existir
    end

    # Verifica se o arquivo de log é gravável
    unless File.writable?(@log_file)
      raise "Arquivo de log não é gravável: #{@log_file}"
    end
  end

  # Abre a conexão com o banco de dados SQLite
  def abrir_conexao_banco_lite
    ConexaoBanco.parametros(@db)           # Configura os parâmetros de conexão
    @logger.info "Conexão estabelecida com sucesso"  # Log de conexão bem-sucedida
  rescue SQLite3::Exception => e
    @logger.error "Erro ao abrir conexão: #{e.message}"  # Log de erro na conexão
    retry_connection(e)  # Tenta reconectar em caso de erro
  end

  # Metodo para conectar ao banco de dados SQL Server da loja específica
  public
  def conectar_banco_server_loja(ip, cod_filial, filial)
    begin
      config = conectar_yml  # Carrega as configurações do arquivo YAML
      TinyTds::Client.new(
        username: config["database_server"]["username"],
        password: config["database_server"]["password"],
        host: ip,
        database: cod_filial == 102 ? config["database_server"]["database"][1] : config["database_server"]["database"][0],
        port: 1433
      )
    rescue TinyTds::Error => e
      @logger.error "Não foi possivel conectar no banco da loja: #{e.message}"  # Log de erro na conexão
      add_list([filial, formatar_codigo_filial(cod_filial)])  # Adiciona a filial à lista de erros com código formatado
      nil  # Retorna nil em caso de falha na conexão
    end
  end

  private

  # Metodo para conectar ao banco de dados SQL Server da retaguarda
  def conectar_banco_server_ret(filial, cod_filial)
    begin
      config = conectar_yml  # Carrega as configurações do arquivo YAML
      TinyTds::Client.new(
        username: config["database_ret"]["username"],
        password: config["database_ret"]["password"],
        host: config["database_ret"]["host"],
        database: config["database_ret"]["database"],
        port: 1433
      )
    rescue TinyTds::NotFoundException => e
      @logger.error "Não foi possivel conectar no banco da retaguarda: #{e.message}"  # Log de erro na conexão
      add_list([filial, formatar_codigo_filial(cod_filial)])  # Adiciona a filial à lista de erros com código formatado
      false  # Retorna false em caso de falha na conexão
    end
  end

  # Fecha a conexão com o servidor SQL
  def fecha_conexao_server(client)
    if client && !client.closed?
      client.close  # Fecha a conexão se estiver aberta
      @logger.info "Conexão SQL Server da loja e/ou retaguarda fechada"  # Log de fechamento
    end
  rescue TinyTds::Client::Timeout => e
    @logger.error "Erro ao fechar conexão do SQL Server da loja e/ou retaguarda: #{e.message}"  # Log de erro ao fechar
  end
  public
  # Metodo principal para sincronização de dados
  def datasync
    lojas_para_email = []  # Lista de lojas para envio de e-mail
    lojas_valores = []     # Lista de valores das lojas
    ret_valores = []       # Lista de valores da retaguarda

    if verifica_horario?  # Verifica se está no horário permitido para execução
      unless verificacao_emails  # Verifica condições para envio de e-mails
        # Obtém as filiais com servidor igual a 1 e ordena por cod_filial
        ips = FiliaisIp.where(servidor: 1).select(:ip, :filial, :cod_filial).order(:cod_filial)
        ips.each do |row|
          ip = row.IP
          filial = row.FILIAL
          cod_filial = row.COD_FILIAL
          script = "SELECT SUM(VALOR_PAGO) FROM LOJA_VENDA WHERE DATA_VENDA='#{formatar_data}' AND CODIGO_FILIAL='#{formatar_codigo_filial(cod_filial)}'"
          # Conecta ao banco da loja
          client_loja = conectar_banco_server_loja(ip, cod_filial, filial)

          # Executa uma consulta no banco da loja para obter o valor total de vendas
          executar_banco_server(client_loja, script) do |linhas|
            linhas.each do |roww|
              valor = converter_hash_vazias(roww)  # Extrai o valor do hash
              if valor
                @logger.info "valor na loja: #{formatar_valor(valor)} da filial #{filial} (#{formatar_codigo_filial(cod_filial)})"
                lojas_valores << [formatar_valor(valor), cod_filial, filial, ip]  # Adiciona à lista de valores das lojas
              else
                @logger.info "Filial #{filial} (#{cod_filial}) sem venda no banco da loja"  # Log de ausência de vendas
              end
            end
          rescue TinyTds::Error, SQLException::Exception
            add_list([filial, formatar_codigo_filial(cod_filial)])  # Adiciona à lista de erros em caso de falha
          ensure
            fecha_conexao_server(client_loja)  # Fecha a conexão com a loja
          end
          # Conecta ao banco da retaguarda
          client_ret = conectar_banco_server_ret(filial, cod_filial)
          # Executa uma consulta no banco da retaguarda para obter o valor total de vendas
          executar_banco_server(client_ret, script) do |ret|
            ret.each do |valor_ret|
              valor = converter_hash_vazias(valor_ret)  # Extrai o valor do hash
              if valor
                @logger.info "valor na retaguarda: #{formatar_valor(valor)} da filial #{filial} (#{formatar_codigo_filial(cod_filial)})"
                ret_valores << [formatar_valor(valor), cod_filial]  # Adiciona à lista de valores da retaguarda
              else
                @logger.info "Filial #{filial} (#{cod_filial}) sem venda no banco da retaguarda"  # Log de ausência de vendas
              end
            end
          end
        end
        # Compara os valores das lojas com os da retaguarda e atualiza conforme necessário
        comparar_valores(lojas_valores, ret_valores).each do |valor_loja, valor_ret, cod_filial, filial, ip|
          venda_travada(ip,cod_filial,filial)
          rodar_script_update(ip, filial, cod_filial)  # Executa os scripts de atualização no banco da loja
          lojas_para_email << ["#{filial} (#{formatar_codigo_filial(cod_filial)})", valor_loja, valor_ret || 0, valor_loja.to_f - (valor_ret || 0).to_f]
        end
        enviar_emails(lojas_para_email)  # Envia e-mails com os resultados da sincronização
      end
    end
  end

  public

  # Executa scripts de atualização no banco da loja
  def rodar_script_update(ip, filial, cod_filial)
    cliente = conectar_banco_server_loja(ip, cod_filial, filial)  # Conecta ao banco da loja
    unless cliente
      @logger.error "Não foi possível conectar à filial #{filial} (#{cod_filial})."  # Log de erro na conexão
      add_list([filial, formatar_codigo_filial(cod_filial)])  # Adiciona à lista de erros
      return
    end

    formatar_data_valor = formatar_data  # Formata a data para uso nos scripts
    begin
      # Inicia uma transação no banco da loja
      cliente.execute("BEGIN TRANSACTION").do

      # Define uma variável SQL para a data
      cliente.execute("DECLARE @data DATE = '#{formatar_data_valor}'").do

      # Lista de comandos SQL para atualizar diversas tabelas
      updates = [
        "UPDATE LOJA_VENDA_PGTO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = '#{formatar_data_valor}'",
        "UPDATE LOJA_CAIXA_LANCAMENTOS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = '#{formatar_data_valor}'",
        "UPDATE LOJA_NOTA_FISCAL SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_SAIDAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_ENTRADAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_CF_SAT SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE CLIENTES_VAREJO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE CODIGO_CLIENTE IN (SELECT CODIGO_CLIENTE FROM LOJA_VENDA WHERE DATA_VENDA = '#{formatar_data_valor}')"
      ]

      total_linhas_afetadas = 0  # Contador para o total de linhas afetadas

      # Executa cada comando de atualização
      updates.each do |query|
        result = cliente.execute(query)
        result.do  # Executa o comando

        linhas_afetadas = result.affected_rows  # Obtém o número de linhas afetadas
        total_linhas_afetadas += linhas_afetadas  # Incrementa o total

        @logger.info "Comando executado na filial #{filial} (#{formatar_codigo_filial(cod_filial)}): #{linhas_afetadas} linhas afetadas."
      end

      # Confirma a transação no banco da loja
      cliente.execute("COMMIT TRANSACTION").do

      @logger.info "Atualização concluída na filial #{filial} (#{formatar_codigo_filial(cod_filial)}). Total de linhas afetadas: #{total_linhas_afetadas}."
    rescue TinyTds::Error => e
      # Em caso de erro, tenta reverter a transação
      begin
        cliente.execute("ROLLBACK TRANSACTION").do
      rescue
        # Ignora erros no rollback
      end
      @logger.error "Erro ao executar os scripts na filial #{filial} (#{formatar_codigo_filial(cod_filial)}): #{e.message}"  # Log de erro
      add_list([filial, formatar_codigo_filial(cod_filial)])  # Adiciona à lista de erros
    ensure
      fecha_conexao_server(cliente)  # Fecha a conexão com a loja
    end
  end

  # Processa informações da loja para verificar consistência de abertura e fechamento
  def processar_loja(list)
    qtd_abertura = []    # Lista para contar aberturas
    qtd_fechamento = []  # Lista para contar fechamentos

    if list
      filial, cod_filial = list  # Desestrutura a lista recebida
      client = conectar_banco_server_ret(filial, cod_filial)  # Conecta ao banco da retaguarda com código formatado

      # Define o script SQL para verificar tipos de lançamento no caixa
      script = "SELECT TIPO_LANCAMENTO_CAIXA FROM LOJA_CAIXA_LANCAMENTOS WHERE CODIGO_FILIAL='#{cod_filial}' AND DATA='#{formatar_data}' AND TIPO_LANCAMENTO_CAIXA in ('00','99')"

      # Executa o script no banco da retaguarda
      executar_banco_server(client, script) do |linhas|
        linhas.each do |row|
          valor = row["TIPO_LANCAMENTO_CAIXA"]
          qtd_abertura << valor if valor == '00'      # Conta aberturas
          qtd_fechamento << valor if valor == '99'    # Conta fechamentos
        end
      end

      # Verifica se a quantidade de aberturas é igual à de fechamentos
      if qtd_abertura.length != qtd_fechamento.length
        return "#{filial} (#{cod_filial})"  # Retorna a filial com inconsistência
      end
    end
  end

  # Consulta lançamentos de caixa para uma lista de lojas
  def consulta_caixa_lancamento(lista_de_lojas)
    resultados = []
    if lista_de_lojas&.any?
      lista_de_lojas.each do |list|
        resultado = processar_loja(list)  # Processa cada loja individualmente
        resultados << resultado if resultado  # Adiciona resultados com inconsistências
      end
    end
    resultados
  end

  # Executa um script no banco de dados SQL Server e permite processamento via bloco
  def executar_banco_server(client, script)
    if client
      row = client.execute(script)  # Executa o script
      yield(row) if block_given?     # Passa o resultado para o bloco, se fornecido
    end
  end

  # Carrega as configurações do arquivo YAML
  def conectar_yml
    config_path = File.expand_path('../../Atualizar_Lojas/lib/config.yml', __dir__)  # Define o caminho do arquivo de configuração
    YAML.load_file(config_path)  # Carrega e retorna o conteúdo do arquivo YAML
  end
end
