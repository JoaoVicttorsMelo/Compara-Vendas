require 'sqlite3'
require 'tiny_tds'
require 'yaml'
require 'time'
require_relative 'enviar_email'
require_relative 'gerar_excel'


class Config
  include EnviarEmail
  include GerarExcel
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
    rescue TinyTds::Error, SQLException::Exception
      add_list("#{filial} - (#{cod_filial.to_s.rjust(6,'0')})")
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
    rescue TinyTds::Error, SQLException::Exception
      add_list("Erro na conexão com o banco retaguarda")
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
    if script_permitido?(script)
      executar_banco_lite(script) do |rows|
        rows.each do |row|
          ip = row[0]
          cod_filial = row[1]
          filial = row[2]
          client_loja = conectar_banco_server_loja(ip,cod_filial,filial)
          if client_loja
            executar_banco_server(client_loja,"select sum(valor_pago) from LOJA_VENDA where DATA_VENDA='#{formatar_data}'",filial,cod_filial) do |linhas|
              linhas.each do |roww|
                hash = roww
                valor = hash[""]
                if valor
                  valor_formatado = sprintf("%.2f",valor)
                  puts "valor na loja: #{valor_formatado} da filial #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                  lojas_valores << [valor_formatado, cod_filial, filial]
                else
                  add_list("#{filial} - (#{cod_filial.to_s.rjust(6,'0')})")
                end
              end
            rescue TinyTds::Error, SQLException::Exception
              add_list("#{filial} - (#{cod_filial.to_s.rjust(6,'0')})")
            ensure
              fecha_conexao_server(client_loja)
            end
          else
            puts "Não foi possivel estabelecer comunicação"
          end
          client_ret = conectar_banco_server_ret
          if client_ret
            executar_banco_server(client_ret,"SELECT SUM(VALOR_PAGO) FROM LOJA_VENDA WHERE DATA_VENDA='#{formatar_data}' AND CODIGO_FILIAL='#{cod_filial.to_s.rjust(6,'0')}'",filial, cod_filial) do |ret|
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
        if comparar_valores(lojas_valores,ret_valores).each do |loja, retaguarda, cod_filial, filial|
          lojas_para_email << ["#{filial} (#{cod_filial.to_s.rjust(6,'0')})",loja, loja.to_f-retaguarda.to_f, retaguarda]
        end
        end
      end
    else
      puts "Script não permitido"
    end
    enviar_emails(lojas_para_email)
  end

  def rodar_script_update(script)
    if script_permitido?(script)
      executar_banco_lite(script) do |rows|
        rows.each do |row|
          ip = row[0]
          cod_filial = row[1]
          filial = row[2]
          cliente = conectar_banco_server_loja(ip, filial, cod_filial)
          begin
            # Executa o comando de UPDATE e pega o resultado
            result = cliente.execute("") #colocar script aqui
            if result
              result.do  # Executa o update
              if result.affected_rows > 0
                puts "Update executado com sucesso na filial: #{filial} (#{cod_filial.to_s.rjust(6,'0')})"
                puts "#{result.affected_rows} linhas afetadas"
              else
                puts "Nenhuma linha foi atualizada na filial #{cod_filial}"
              end
            else
              puts "Não foi possivel fazer a conexão"
            end
          rescue TinyTds::Error, SQLException::Exception
            add_list("Erro na conexão ou execução na loja:<br> #{filial} (#{cod_filial.to_s.rjust(6, '0')})")
          ensure
            fecha_conexao_server(cliente)
          end
        end
      end
      fechar_conexao_lite
    else
      puts "Script não permitido"
    end
  end


  private
  def executar_banco_lite(script)
    if script_permitido?(script)
      row = @db.execute(script)
      yield(row) if block_given?
    end
  end

  def executar_banco_server(client,script,filial,cod_filial)
    begin
      if client
        if script_permitido?(script)
          row = client.execute(script)
          yield(row) if block_given?
        end
      else
      end
    rescue TinyTds::Error, SQLException::Exception
      add_list("Erro na conexão ou execução na loja:<br> #{filial} (#{cod_filial.to_s.rjust(6, '0')})")
    end
  end


  private
  def script_permitido?(script)
    # Lista de scripts permitidos para maior segurança
    scripts_permitidos = ["select", "where"]
    scripts_permitidos.any? { |palavra| script.downcase.include?(palavra) }
  end

  def conectar_yml
    config_path= File.join(__dir__, 'config.yml')
    YAML.load_file(config_path)
  end

  def add_list(model)
    @lojas_erro ||= []
    @lojas_erro << model
  end

  def show_list
    if @lojas_erro
      @lojas_erro.join('<br>')
    end
  end
end

def formatar_data
  (Date.today - 1).strftime("%y%m%d")
end


def comparar_valores(lojas_valores, ret_valores)
  resultado = []
  lojas_valores.each do |valor_loja, cod_filial, filial|
    valor_ret = ret_valores.find { |cod_ret| cod_ret == cod_filial }&.first
    if valor_ret == valor_loja
      resultado << [valor_loja, valor_ret || 0, cod_filial, filial]
    end
  end
  resultado
end

def enviar_emails(lista)
  if lista.any?

    anexo =  gerar_excel(lista)
    if show_list
      enviar_email("Datasync: Lojas com diferenças",'Olá, boa tarde<br> Segue lojas que estão com diferenças entre Retaguarda e Loja em anexo:<br>',
                   "Segue as lojas que não foram possiveis de fazer a verificação automática:<br><br> #{show_list}", anexo,
                   'Essas lojas que não conseguimos conectar, podem ou não acrescentar na diferença de vendas, só vamos conseguir validar quando o
problema for resolvido ou a loja abrir e ligar os terminais caso seja uma loja de fuso horário diferente')
    else
      enviar_email("Datasync: Lojas com diferenças",'Olá, boa tarde<br> Segue lojas que estão com diferenças entre Retaguarda e Loja em anexo:<br>',
                   "Nenhuma loja deu erro na conexão!", anexo)
      end
  else
    if show_list
      enviar_email("Datasync: Lojas sem diferenças",'Valores Lojas X Retaguarda estão certos:<br>',"Segue as lojas que não foram possiveis de fazer a verificação automática:<br><br> #{show_list}",nil,
                   'Essas lojas que não conseguimos conectar, podem ou não acrescentar na diferença de vendas, só vamos conseguir validar quando o
problema for resolvido ou a loja abrir e ligar os terminais caso seja uma loja de fuso horário diferente')
    else
      enviar_email("Datasync: Lojas sem diferenças",'Valores Lojas X Retaguarda estão corretos:<br>',"Nenhuma loja deu erro na conexão!",nil)
    end
  end
end
