# Importação das bibliotecas necessárias
require 'time'                   # Biblioteca para manipulação de datas e horários
require 'date'                   # Biblioteca para manipulação de datas
require_relative File.join(__dir__, '..', 'lib', 'enviar_email')  # Módulo para envio de e-mails
require_relative File.join(__dir__, '..', 'classes', 'services')  # classe para conectar no banco
require_relative File.join(__dir__, '..', 'lib', 'gerar_excel')    # Módulo para geração de arquivos Excel

# Definição do módulo Util que inclui funcionalidades de envio de e-mails e geração de Excel
module Util
  include EnviarEmail   # Inclusão do módulo EnviarEmail para funcionalidades de e-mail
  include GerarExcel     # Inclusão do módulo GerarExcel para funcionalidades de geração de Excel

  # Verifica se o horário atual está dentro do horário de funcionamento permitido
  def verifica_horario?
    horario = Time.now       # Obtém o horário atual
    data = Date.today        # Obtém a data atual

    if data.sunday?          # Se for domingo
      if horario.hour >= 13 && horario.hour <= 21  # Horário permitido: 13h às 21h
        true
      else
        puts "Fora de horário de funcionamento"   # Mensagem informando fora do horário
        false
      end
    else
      if horario.hour >= 8 && horario.hour <= 23    # Horário permitido: 8h às 23h nos demais dias
        true
      else
        puts "Fora de horário de funcionamento"     # Mensagem informando fora do horário
        false
      end
    end
  end

  # Formata o código da filial para ter 6 dígitos, preenchendo com zeros à esquerda
  def formatar_codigo_filial(cod_filial)
    cod_filial.to_s.rjust(6, '0')
  end

  # Converte o hash retornado pela consulta para obter o valor desejado
  def converter_hash_vazias(hash)
    converter = hash
    converter[""]
  end


  # Converte megabytes para bytes
  def converter_mb_para_byte(mb)
    mb * 1024 * 1024  # Multiplica por 1024 duas vezes para converter MB em bytes
  end

  # Formata o valor para ter duas casas decimais
  def formatar_valor(valor)
    sprintf("%.2f", valor)
  end

  # Adiciona uma filial à lista de erros
  def add_list(model = [])
    @lojas_erro ||= []     # Inicializa a lista de erros se ainda não estiver definida
    @lojas_erro << model   # Adiciona o modelo à lista de erros
  end

  # Exibe a lista de erros, podendo retornar como string ou array
  def show_list(as_string = false)
    @lojas_erro ||= []  # Inicializa a lista de erros se ainda não estiver definida
    if as_string
      @lojas_erro.join('<br>')  # Retorna a lista de erros como uma string HTML com quebras de linha
    else
      @lojas_erro  # Retorna a lista de erros como array
    end
  end

  # Formata a data para o formato "YYYYMMDD", considerando o dia anterior
  def formatar_data
    data = Date.today - 1  # Obtém a data do dia anterior
    data.strftime("%Y%m%d") # Formata a data no formato "YYYYMMDD"
  end

  # Compara os valores das lojas com os valores da retaguarda
  def comparar_valores(lojas_valores, ret_valores)
    resultado = []
    lojas_valores.each do |valor_loja, cod_filial, filial, ip|
      # Encontra a entrada correspondente na retaguarda com base no código da filial
      ret_entry = ret_valores.find { |valor_ret, cod_ret| cod_ret == cod_filial }
      if ret_entry
        valor_ret, _cod_ret = ret_entry
        # Se os valores diferirem, adiciona à lista de resultados
        if valor_loja != valor_ret
          resultado << [valor_loja, valor_ret, cod_filial, filial, ip]
        end
      else
        # Se não encontrar a entrada na retaguarda, considera como discrepância
        resultado << [valor_loja, nil, cod_filial, filial, ip]
      end
    end
    resultado
  end

  # Envia e-mails com os resultados da sincronização
  def enviar_emails(lista)
    lojas_erro = show_list(false)
    resultado_consulta = consulta_caixa_lancamento(lojas_erro) unless lojas_erro.empty?

    if lista.any?
      anexo = gerar_excel(lista)
      enviar_email_diferencas(anexo, resultado_consulta)
    else
      enviar_email_sem_diferencas(resultado_consulta)
    end
  end

  def enviar_email_diferencas(anexo, resultado_consulta)
    info_opcional = if resultado_consulta.any?
                      "<h1>Possíveis Diferenças nas Vendas!</h1>
    <p class='big-bold'>As lojas listadas acima não puderam ser conectadas para verificação automática. Essas diferenças serão validadas somente após: 'Abertura das lojas e reativação dos terminais, especialmente se estiverem em fusos horários diferentes.
'</p>"
                    else
                      nil
                    end

    enviar_email(
      titulo: "Datasync: Lojas com diferenças",
      corpo: "Lojas com diferenças:<br>",
      corpo2: "<p class='big-bold'>Segue as lojas que não foram possíveis de fazer a verificação automática:</p>",
      informacao: resultado_consulta,
      caminho_arquivo_anexo: anexo,
      info_opcional: info_opcional
    )
  end

  def enviar_email_sem_diferencas(resultado_consulta)
    if resultado_consulta.any?
      enviar_email(
        titulo: "Datasync: Lojas sem diferenças",
        corpo: "Valores Lojas X Retaguarda estão corretos, exceto as filiais abaixo:<br>",
        corpo2: "<p class='big-bold'>Segue as lojas que não foram possíveis de fazer a verificação automática:</p>",
        informacao: resultado_consulta,
        info_opcional: "<h1>Possíveis Diferenças nas Vendas!</h1>
      <p class='big-bold'>As lojas listadas acima não puderam ser conectadas para verificação automática. Essas diferenças serão validadas somente após: 'Abertura das lojas e reativação dos terminais, especialmente se estiverem em fusos horários diferentes.
</p>"
      )
    else
      if verificacao_emails(1)
        enviar_email(
          titulo: "Datasync: Lojas sem diferenças",
          corpo: 'Valores Lojas X Retaguarda estão corretos:<br>',
          informacao: "<p class='big-bold'>Nenhuma loja deu erro na conexão!</p>"
        )
      end
    end
  end

  def preparar_conteudo_email_venda_travada(filial, cod_filial, lancamento_caixa, terminal, ticket, total, data_venda)
    "<p>
    A loja <strong>#{filial}</strong> (<strong>#{formatar_codigo_filial(cod_filial)}</strong>)
    está com uma venda travada detectada, segue informações -
    Lançamento de caixa: <strong>#{lancamento_caixa}</strong> no terminal:
    <strong>#{terminal}</strong> do ticket: <strong>#{ticket}</strong>, com o valor
    <strong>#{total}</strong> na data de venda: <strong>#{data_venda}</strong>.
  </p>"
  end

  def venda_travada(ip, cod_filial, filial)
    client_loja = conectar_banco_server_loja(ip, cod_filial, filial)
    vendas_travadas = []

    script = "SELECT LANCAMENTO_CAIXA, TERMINAL, TOTAL_VENDA FROM LOJA_VENDA_PGTO WHERE VENDA_FINALIZADA = '0' AND DATA='#{formatar_data}' AND CODIGO_FILIAL=#{formatar_codigo_filial(cod_filial)};"

    executar_banco_server(client_loja, script) do |linhas|
      linhas.each do |linha|
        lancamento_caixa = linha["LANCAMENTO_CAIXA"]
        terminal = linha["TERMINAL"]
        total = linha["TOTAL_VENDA"]

        ticket_query = "SELECT ticket FROM loja_venda WHERE data_venda='#{formatar_data}' AND LANCAMENTO_CAIXA='#{lancamento_caixa}' AND TERMINAL='#{terminal}'"

        executar_banco_server(client_loja, ticket_query) do |row|
          row.each do |rows|
            ticket = rows["ticket"]

            vendas_travadas << {
              filial: filial,
              cod_filial: cod_filial,
              lancamento_caixa: lancamento_caixa,
              terminal: terminal,
              ticket: ticket,
              total: total,
              data_venda: formatar_data
            }
          end
        end
      end
    end

    unless vendas_travadas.empty?
      conteudo_email = vendas_travadas.map do |venda|
        preparar_conteudo_email_venda_travada(
          venda[:filial],
          venda[:cod_filial],
          venda[:lancamento_caixa],
          venda[:terminal],
          venda[:ticket],
          venda[:total],
          venda[:data_venda]
        )
      end.join("<br>")

      enviar_email_vendas_travadas(conteudo_email)
    end
  end



  def enviar_email_vendas_travadas(conteudo_email)
    enviar_email(
      titulo: 'Loja com venda travada',
      corpo: 'Segue lojas com venda travada na data de hoje',
      informacao: conteudo_email,
      incluir_style: true
    )
  end


  # Insere um novo registro na tabela 'ultimo_email' para registrar o envio de e-mail
  def inserir_novo_registro(data_atual)
    inserir_valor = UltimoEmail.new(
      data_envio_concluido: data_atual
    )
    if inserir_valor.save
      @logger.info("Informação cadastrada no banco de dados na tabela 'ultimo_email', informações enviadas #{data_atual}")  # Log de sucesso
      true
    else
      @logger.error("Erro ao inserir valores na tabela 'ultimo_email', informações enviadas #{data_atual}")  # Log de erro
      false
    end
  end

  # Verifica se os e-mails já foram enviados para a data atual ou insere um novo registro
  def verificacao_emails(validacao = 0)
    ultimo_email = UltimoEmail.order(data_envio_concluido: :desc).first  # Obtém o último registro de envio de e-mail
    data_atual = formatar_data  # Formata a data atual

    if validacao == 0 && ultimo_email&.data_envio_concluido == data_atual
      @logger.info("Já existe um registro para a data atual: #{data_atual}. Cancelando o envio.")  # Log informando que o e-mail já foi enviado
      return true
    end

    if validacao == 1
      begin
        if ultimo_email.nil? || ultimo_email.data_envio_concluido < data_atual
          return inserir_novo_registro(data_atual)  # Insere um novo registro se não existir ou se for uma nova data
        else
          @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")  # Log de erro
          return false
        end
      rescue ActiveRecord::RecordNotUnique
        @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")  # Log de erro de unicidade
        false
      rescue StandardError => e
        @logger.error("Erro inesperado na função verificacao_emails: #{e.message}")  # Log de erro genérico
        false
      end
    end
  end

end
