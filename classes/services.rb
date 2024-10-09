require 'sqlite3'
require 'tiny_tds'
require 'yaml'

require_relative File.join(__dir__, '..', 'lib', 'util')
class Services
  include Util
  def initialize(db=nil)
    @db=db
    conectar_banco_lite
  end

  private
  def conectar_banco_lite
    @db = SQLite3::Database.new @db
    puts "Conectado com sucesso"
  rescue SQLite3::Exception
    puts 'Erro ao conectar no banco'
  end

  private
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
    rescue TinyTds::Error
      add_list([filial, cod_filial.to_s.rjust(6, '0')])
      false
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
    rescue TinyTds::Error
      add_list([filial, cod_filial.to_s.rjust(6, '0')])
      false
    end
  end

  def fechar_conexao_lite
    if @db
      @db.close
      puts "Banco Fechado"
    else
      puts "Não existe nenhuma conexão"
    end
  rescue SQLite3::Exception
    puts "Erro ao fechar o banco"
  ensure
    @db.close
  end

  def fecha_conexao_server(client)
    if client
      client.close
      puts 'conexão client fechado'
    end
  rescue TinyTds::Client::Timeout
    puts 'Erro ao fechar conexão'
  end

  public
    def datasync(script)
      lojas_para_email = []
      lojas_valores = []
      ret_valores = []
      scripts = obter_scripts_update(formatar_data)
      if verifica_horario
        if script_permitido?(script)
          executar_banco_lite(script) do |rows|
            rows.each do |row|
              ip = row[0]
              cod_filial = row[1].to_s.rjust(6,'0')
              filial = row[2]
              client_loja = conectar_banco_server_loja(ip,cod_filial,filial)
              if client_loja
                executar_banco_server(client_loja,"select sum(valor_pago) from LOJA_VENDA where DATA_VENDA='#{formatar_data}'") do |linhas|
                  linhas.each do |roww|
                    hash = roww
                    valor = hash[""]
                    if valor
                      valor_formatado = sprintf("%.2f",valor)
                      puts "valor na loja: #{valor_formatado} da filial #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                      lojas_valores << [valor_formatado, cod_filial, filial,ip]
                    else
                      puts "Filial #{filial} (#{cod_filial}) sem venda"
                    end
                  end
                rescue TinyTds::Error, SQLException::Exception
                  add_list([filial, cod_filial.to_s.rjust(6, '0')])
                ensure
                  fecha_conexao_server(client_loja)
                end
              else
                puts "Não foi possivel estabelecer comunicação"
              end
              client_ret = conectar_banco_server_ret
              if client_ret
                executar_banco_server(client_ret,"SELECT SUM(VALOR_PAGO) FROM LOJA_VENDA WHERE DATA_VENDA='#{formatar_data}' AND CODIGO_FILIAL='#{cod_filial.to_s.rjust(6,'0')}'") do |ret|
                  ret.each do |valor_ret|
                    hash = valor_ret
                    valor = hash[""]
                    if valor
                      valor_formatado = sprintf("%.2f",valor)
                      puts "valor na retaguarda: #{valor_formatado} da filial #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                      ret_valores << [valor_formatado, cod_filial]
                    end
                  end
                end
              else
                puts "Não foi possivel achar a loja"
              end
            end
            fechar_conexao_lite
            comparar_valores(lojas_valores,ret_valores).each do |valor_loja, valor_ret, cod_filial, filial, ip|
            lojas_para_email << ["#{filial} (#{cod_filial})", valor_loja, valor_loja.to_f - (valor_ret || 0).to_f, valor_ret || 0]
            rodar_script_update(ip, filial, cod_filial,scripts)
            end
          end
        else
          puts "Script não permitido"
        end
        enviar_emails(lojas_para_email)
      end
    end

  def rodar_script_update(ip, filial, cod_filial,scripts)
    cliente = conectar_banco_server_loja(ip, filial, cod_filial)
    begin
      if script_permitido?(scripts)
        result = cliente.execute(scripts)
        if result
          result.do  # Executa o update
          if result.affected_rows > 0
            puts "Update executado com sucesso na filial: #{filial} (#{cod_filial})"
            puts "#{result.affected_rows} linhas afetadas"
          else
            puts "Nenhuma linha foi atualizada na filial #{cod_filial}"
          end
        else
          puts "Não foi possível executar o script na filial #{cod_filial}"
        end
      else
        puts "Script não permitido"
      end
    rescue TinyTds::Error, SQLException::Exception => e
      puts "Erro ao executar o script na filial #{cod_filial}: #{e.message}"
      add_list([filial, cod_filial])
    ensure
      fecha_conexao_server(cliente)
    end
  end





  def processar_loja(list)
    qtd_abertura = []
    qtd_fechamento = []
    if list
      filial, cod_filial = list
      client = conectar_banco_server_ret
      script = "SELECT TIPO_LANCAMENTO_CAIXA FROM LOJA_CAIXA_LANCAMENTOS WHERE CODIGO_FILIAL='#{cod_filial}' AND DATA='#{formatar_data}' AND TIPO_LANCAMENTO_CAIXA in ('00','99')"
      if script_permitido?(script)
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
  end

  def consulta_caixa_lancamento(lista_de_lojas)
    resultados = []
    if lista_de_lojas&.any?
      lista_de_lojas.each do |list|
        resultado = processar_loja(list)
        resultados << resultado if resultado
      end
    end
    resultados
  end


  private
  def executar_banco_lite(script)
    if script_permitido?(script)
      row = @db.execute(script)
      yield(row) if block_given?
    end
  end

  def executar_banco_server(client,script)
      if client
        if script_permitido?(script)
          row = client.execute(script)
          yield(row) if block_given?
        end
      end
  end

  private
  def script_permitido?(script)
    # Lista de scripts permitidos para maior segurança
    scripts_permitidos = %w[select where]
    scripts_permitidos.any? { |palavra| script.downcase.include?(palavra) }
  end

  public
  def conectar_yml
    config_path = File.expand_path('../../Atualizar_Lojas/lib/config.yml', __dir__)
    YAML.load_file(config_path)
  end
end

def obter_scripts_update(data_formatada)
  [
    {
      consulta: "UPDATE LOJA_VENDA_PGTO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE LOJA_CAIXA_LANCAMENTOS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE DATA = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE LOJA_NOTA_FISCAL SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE LOJA_SAIDAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE LOJA_ENTRADAS SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE LOJA_CF_SAT SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE EMISSAO = @data",
      parametros: { data: data_formatada }
    },
    {
      consulta: "UPDATE CLIENTES_VAREJO SET DATA_PARA_TRANSFERENCIA = GETDATE() WHERE CODIGO_CLIENTE IN (SELECT CODIGO_CLIENTE FROM LOJA_VENDA WHERE DATA_VENDA = @data)",
      parametros: { data: data_formatada }
    }
  ]
end