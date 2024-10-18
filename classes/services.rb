require 'sqlite3'
require 'tiny_tds'
require 'yaml'
require 'logger'
require 'fileutils'
require_relative 'filial_ip'  # Model para acessar a tabela filiais_ip
require_relative '../lib/conexao_banco'  # Módulo para gerenciar a conexão com o banco de dados


require_relative File.join(__dir__, '..', 'lib', 'util')
class Services
  include ConexaoBanco
  include Util
  def initialize(db=nil)
    setup_logger
    @db=db
    abrir_conexao_banco_lite

  end

  private
  def setup_logger
    project_root = File.expand_path(File.join(__dir__, '..'))
    log_dir = File.join(project_root, 'log')
    @log_file = File.join(log_dir, 'database.log')

    ensure_log_file_exists

    @logger = Logger.new(@log_file)
    @logger.level = Logger::INFO

    # Teste inicial do logger
    @logger.info("Logger iniciado com sucesso")
  rescue StandardError => e
    p "Erro ao configurar logger: #{e.message}"
    p "Stacktrace: #{e.backtrace.join("\n")}"
    @logger = Logger.new(STDOUT)
  end

  def ensure_log_file_exists
    FileUtils.mkdir_p(File.dirname(@log_file))

    unless File.exist?(@log_file)
      FileUtils.touch(@log_file)
    end

    # Verifica se o arquivo é gravável
    unless File.writable?(@log_file)
      raise "Arquivo de log não é gravável: #{@log_file}"
    end
  end


  def abrir_conexao_banco_lite
    ConexaoBanco.parametros(@db)
      @logger.info "Conexão estabelecida com sucesso"
    rescue SQLite3::Exception => e
      @logger.error "Erro ao abrir conexão: #{e.message}"
      retry_connection(e) # Tenta reconectar em caso de erro.
  end


  public
  def conectar_banco_server_loja(ip,cod_filial,filial)

    begin
      config = conectar_yml
      TinyTds::Client.new(
        username: config["database_server"]["username"],
        password: config["database_server"]["password"],
        host: ip,
        database: cod_filial == 102 ? config["database_server"]["database"][1] : config["database_server"]["database"][0],
        port: 1433
      )
    rescue TinyTds::Error => e
      @logger.error("Não foi possivel conectar no banco da loja #{e.message}")
      add_list([filial, cod_filial.to_s.rjust(6, '0')])
      nil
    end
  end

  private
  def conectar_banco_server_ret
    begin
      config = conectar_yml
      TinyTds::Client.new(
        username: config["database_ret"]["username"],
        password: config["database_ret"]["password"],
        host: config["database_ret"]["host"],
        database: config["database_ret"]["database"],
        port: 1433
      )
    rescue TinyTds::NotFoundException => e
      @logger.error("Não foi possivel conectar no banco da retaguarda: #{e.message}")
      add_list([filial, cod_filial.to_s.rjust(6, '0')])
      false
    end
  end

  def fecha_conexao_server(client)
  if client && !client.closed?
      client.close
      @logger.info("conexão SQL Server da loja e/ou retaguarda fechada")
    end
  rescue TinyTds::Client::Timeout => e
    @logger.error("Erro ao fechar conexão do SQL Server da loja e/ou retaguarda: #{e.message}")
  end


  public
    def datasync
      lojas_para_email = []
      lojas_valores = []
      ret_valores = []
      if verifica_horario?
            ips = FiliaisIp.where(servidor: 1).select(:ip, :filial, :cod_filial)
            ips.each do |row|
              ip = row.IP
              filial = row.FILIAL
              cod_filial = row.COD_FILIAL
              client_loja = conectar_banco_server_loja(ip,cod_filial,filial)
              executar_banco_server(client_loja,"select sum(valor_pago) from LOJA_VENDA where DATA_VENDA='#{formatar_data}'") do |linhas|
                  linhas.each do |roww|
                    hash = roww
                    valor = hash[""]
                    if valor
                      valor_formatado = sprintf("%.2f",valor)
                      @logger.info "valor na loja: #{valor_formatado} da filial #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                      lojas_valores << [valor_formatado, cod_filial, filial, ip]
                    else
                      @logger.info "Filial #{filial} (#{cod_filial}) sem venda no banco da loja"
                    end
                  end
                rescue TinyTds::Error, SQLException::Exception
                  add_list([filial, cod_filial.to_s.rjust(6, '0')])
                ensure
                  fecha_conexao_server(client_loja)
                end
              client_ret = conectar_banco_server_ret
                executar_banco_server(client_ret,"SELECT SUM(VALOR_PAGO) FROM LOJA_VENDA WHERE DATA_VENDA='#{formatar_data}' AND CODIGO_FILIAL='#{cod_filial.to_s.rjust(6,'0')}'") do |ret|
                  ret.each do |valor_ret|
                    hash = valor_ret
                    valor = hash[""]
                    if valor
                      valor_formatado = sprintf("%.2f",valor)
                      @logger.info "valor na retaguarda: #{valor_formatado} da filial #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                      ret_valores << [valor_formatado, cod_filial]
                    else
                      @logger.info "Filial #{filial} (#{cod_filial}) sem venda no banco da retaguarda"
                    end
                  end
                end
            end
            comparar_valores(lojas_valores,ret_valores).each do |valor_loja, valor_ret, cod_filial, filial, ip|
              rodar_script_update(ip, filial, cod_filial)
            lojas_para_email << ["#{filial} (#{cod_filial.to_s.rjust(6,'0')})", valor_loja, valor_ret || 0, valor_loja.to_f - (valor_ret || 0).to_f]
            end
              enviar_emails(lojas_para_email)
      end
    end

  public
  def rodar_script_update(ip, filial, cod_filial)
    cliente = conectar_banco_server_loja(ip, cod_filial, filial)
    unless cliente
      @logger.error "Não foi possível conectar à filial #{filial} (#{cod_filial})."
      add_list([filial, cod_filial])
      return
    end

    formatar_data_valor = formatar_data
    begin
      # Iniciar transação
      cliente.execute("BEGIN TRANSACTION").do

      # Definir variável SQL para a data
      cliente.execute("DECLARE @data DATE = '#{formatar_data_valor}'").do

      updates = [
        "UPDATE LOJA_VENDA_PGTO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = '#{formatar_data_valor}'",
        "UPDATE LOJA_CAIXA_LANCAMENTOS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = '#{formatar_data_valor}'",
        "UPDATE LOJA_NOTA_FISCAL SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_SAIDAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_ENTRADAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE LOJA_CF_SAT SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = '#{formatar_data_valor}'",
        "UPDATE CLIENTES_VAREJO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE CODIGO_CLIENTE IN (SELECT CODIGO_CLIENTE FROM LOJA_VENDA WHERE DATA_VENDA = '#{formatar_data_valor}')"
      ]

      total_linhas_afetadas = 0

      updates.each do |query|
        result = cliente.execute(query)
        result.do # Executa o comando

        linhas_afetadas = result.affected_rows
        total_linhas_afetadas += linhas_afetadas

        @logger.info "Comando executado na filial #{filial} (#{cod_filial.to_s.rjust(6,'0')}): #{linhas_afetadas} linhas afetadas."
      end

      # Confirmar transação
      cliente.execute("COMMIT TRANSACTION").do

      @logger.info "Atualização concluída na filial #{filial} (#{cod_filial.to_s.rjust(6,'0')}). Total de linhas afetadas: #{total_linhas_afetadas}."
    rescue TinyTds::Error => e
      # Reverter transação em caso de erro
      begin
        cliente.execute("ROLLBACK TRANSACTION").do
      rescue
        # Ignora erros no rollback
      end
      @logger.error "Erro ao executar os scripts na filial #{filial} (#{cod_filial.to_s.rjust(6,'0')}): #{e.message}"
      add_list([filial, cod_filial.to_s.rjust(6,'0')])
    ensure
      fecha_conexao_server(cliente)
    end
  end

  public
  def verificacao_emails
    begin
      # Obter o último registro ordenado por data_envio_concluido desc
      ultimo_email = UltimoEmail.order(data_envio_concluido: :desc).first
      data_atual = formatar_data # Supondo que formatar_data retorna um objeto Date ou DateTime

      if ultimo_email.nil?
        # Não há registros, então inserir um novo registro para a data atual
        inserir_valor = UltimoEmail.new(
          data_envio_pendente: data_atual,
          data_envio_concluido: data_atual
        )
        if inserir_valor.save
          @logger.info("Informação cadastrada no banco de dados na tabela 'ultimo_email', informações enviadas #{data_atual}")
          return true
        else
          @logger.error("Erro ao inserir valores na tabela 'ultimo_email', informações enviadas #{data_atual}")
          return false
        end
      else
        # Verificar se data_envio_concluido é anterior à data_atual
        if ultimo_email.data_envio_concluido < data_atual
          # Criar um novo registro para a data atual
          inserir_valor = UltimoEmail.new(
            data_envio_pendente: data_atual,
            data_envio_concluido: data_atual
          )
          if inserir_valor.save
            @logger.info("Informação cadastrada no banco de dados na tabela 'ultimo_email', informações enviadas #{data_atual}")
            return true
          else
            @logger.error("Erro ao inserir valores na tabela 'ultimo_email', informações enviadas #{data_atual}")
            return false
          end
        else
          # Já existe um registro para a data atual
          @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")
          return false
        end
      end
    rescue ActiveRecord::RecordNotUnique => e
      @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")
      return false
    rescue StandardError => e
      @logger.error("Erro inesperado na função verificacao_emails: #{e.message}")
      return false
    end
  end


  def processar_loja(list)
    qtd_abertura = []
    qtd_fechamento = []
    if list
      filial, cod_filial = list
      client = conectar_banco_server_ret
      script = "SELECT TIPO_LANCAMENTO_CAIXA FROM LOJA_CAIXA_LANCAMENTOS WHERE CODIGO_FILIAL='#{cod_filial}' AND DATA='#{formatar_data}' AND TIPO_LANCAMENTO_CAIXA in ('00','99')"
        executar_banco_server(client, script) do |linhas|
          linhas.each do |row|
            valor = row["TIPO_LANCAMENTO_CAIXA"]
            qtd_abertura << valor if valor == '00'
            qtd_fechamento << valor if valor == '99'
          end
        end
        if qtd_abertura.length != qtd_fechamento.length
          return "#{filial} (#{cod_filial})"
        end
    end
  end

  def consulta_caixa_lancamento(lista_de_lojas)
    resultados = []
    if lista_de_lojas&.any?
      lista_de_lojas.each do |list|
        resultado = processar_loja(list)
        resultados << resultado if resultado
      end
      else
    end
    resultados
  end

  def executar_banco_server(client,script)
      if client
          row = client.execute(script)
          yield(row) if block_given?
      end
  end

  def conectar_yml
    config_path = File.expand_path('../../Atualizar_Lojas/lib/config.yml', __dir__)
    YAML.load_file(config_path)
  end
  end
