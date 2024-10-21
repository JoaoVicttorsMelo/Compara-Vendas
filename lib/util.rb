# Importação das bibliotecas necessárias
require 'time'                   # Biblioteca para manipulação de datas e horários
require 'date'                   # Biblioteca para manipulação de datas
require_relative File.join(__dir__, '..', 'lib', 'enviar_email')  # Módulo para envio de e-mails
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
  def converter_hash(hash)
    converter = hash
    converter[""]
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
    if lista.any?  # Se houver lojas para notificar
      anexo = gerar_excel(lista)  # Gera um arquivo Excel com a lista
      lojas_erro = show_list(false)  # Obtém a lista de lojas com erros
      resultado_consulta = []  # Inicializa a lista de resultados da consulta

      unless lojas_erro.empty?
        resultado_consulta = consulta_caixa_lancamento(lojas_erro)  # Verifica consistência de caixa nas lojas com erros
      end

      if resultado_consulta.any?
        # Envia e-mail informando lojas com diferenças e anexando o Excel
        enviar_email(
          "Datasync: Lojas com diferenças",
          "Lojas com diferenças:<br>",
          "<p class='big-bold'> Segue as lojas que não foram possíveis de fazer a verificação automática:</p>",
          resultado_consulta,
          anexo,
          "<h1>Possíveis Diferenças nas Vendas!</h1>
          <p class='big-bold'>As lojas listadas acima não puderam ser conectadas para verificação automática. Essas diferenças serão validadas somente após:</p>
          <table border='1' cellpadding='5' cellspacing='0' style='width: 100%; margin-top: 10px;'>
            <tr>
              <td style='text-align: center; vertical-align: middle;'>Abertura das lojas e reativação dos terminais, especialmente se estiverem em fusos horários diferentes.</td>
            </tr>
          </table>"
        )
      else
        # Envia e-mail informando que nenhuma loja teve erro de conexão
        enviar_email(
          "Datasync: Lojas com diferenças",
          'Olá, boa tarde<br> Segue lojas que estão com diferenças entre Retaguarda e Loja em anexo:<br>',
          nil,
          "<p class='big-bold'><center>Nenhuma loja deu erro na conexão!</center><p>",
          anexo
        )
      end
    else
      lojas_erro = show_list(false)  # Obtém a lista de lojas com erros
      resultado_consulta = consulta_caixa_lancamento(lojas_erro)  # Verifica consistência de caixa

      if resultado_consulta.any?
        # Envia e-mail informando que existem lojas sem diferenças, mas com erros na conexão
        enviar_email(
          "Datasync: Lojas sem diferenças",
          "Valores Lojas X Retaguarda estão Corretos, exceto as filiais abaixo:<br>",
          "<p class='big-bold'>Segue as lojas que não foram possíveis de fazer a verificação automática:<p><br>",
          resultado_consulta,
          nil,
          "<h1>Possíveis Diferenças nas Vendas!</h1>
          <p class='big-bold'>As lojas listadas acima não puderam ser conectadas para verificação automática.Essas diferenças serão validadas somente após:</p>
          <table border='1' cellpadding='5' cellspacing='0' style='width: 100%; margin-top: 10px;'>
            <tr>
              <td style='text-align: center; vertical-align: middle;'>Abertura das lojas e reativação dos terminais, especialmente se estiverem em fusos horários diferentes.</td>
            </tr>
          </table>"
        )
      else
        # Se não houver erros na conexão e nenhuma discrepância, envia e-mail confirmando tudo está correto
        if verificacao_emails(1)
          enviar_email(
            "Datasync: Lojas sem diferenças",
            'Valores Lojas X Retaguarda estão corretos:<br>',
            "<p class='big-bold'>Nenhuma loja deu erro na conexão!</p>",
            nil
          )
        end
      end
    end
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

  # Converte megabytes para bytes
  def converter_mb_para_byte(mb)
    mb * 1024 * 1024  # Multiplica por 1024 duas vezes para converter MB em bytes
  end
end
