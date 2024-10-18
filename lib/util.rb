require 'time'
require 'date'
require_relative File.join(__dir__, '..', 'lib', 'enviar_email')
require_relative File.join(__dir__, '..', 'lib', 'gerar_excel')






module Util
  include EnviarEmail
  include GerarExcel

  def verifica_horario?
    horario = Time.now
    data = Date.today
    if data.sunday?
      if horario.hour >=13 and horario.hour <=21
        true
      else
        puts "Fora de horário de funcionamento"
        false
      end
    else
      if horario.hour >=8 and horario.hour <=23
        true
      else
        puts "Fora de horário de funcionamento"
        false
      end
    end
  end

  def add_list(model=[])
    @lojas_erro ||= []
    @lojas_erro << model
  end

  def show_list(as_string = false)
    @lojas_erro ||= []
    if as_string
      @lojas_erro.join('<br>')
    else
      @lojas_erro
    end
  end
  def formatar_data
    require 'date'
    data = Date.today - 1
    data.strftime("%Y%m%d")
  end

  def comparar_valores(lojas_valores, ret_valores)
    resultado = []
    lojas_valores.each do |valor_loja, cod_filial, filial, ip|
      ret_entry = ret_valores.find { |valor_ret, cod_ret| cod_ret == cod_filial }
      if ret_entry
        valor_ret, _cod_ret = ret_entry
        if valor_loja != valor_ret
          resultado << [valor_loja, valor_ret, cod_filial, filial, ip]
        end
      else
        # Se o valor na retaguarda não for encontrado, considere como discrepância
        resultado << [valor_loja, nil, cod_filial, filial, ip]
      end
    end
    resultado
  end

  def enviar_emails(lista)
    if lista.any?
      anexo =  gerar_excel(lista)
      lojas_erro = show_list(false)
      resultado_consulta = []  # Inicializa como array vazio
      unless lojas_erro.empty?
        resultado_consulta = consulta_caixa_lancamento(lojas_erro)
      end
      if resultado_consulta.any?
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
        enviar_email("Datasync: Lojas com diferenças",'Olá, boa tarde<br> Segue lojas que estão com diferenças entre Retaguarda e Loja em anexo:<br>',nil,
                     "<p class='big-bold'><center>Nenhuma loja deu erro na conexão!</center><p>", anexo)
      end
    else
      lojas_erro = show_list(false)
      resultado_consulta = consulta_caixa_lancamento(lojas_erro)
      if resultado_consulta.any?
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
        if verificacao_emails(1)
          enviar_email("Datasync: Lojas sem diferenças",'Valores Lojas X Retaguarda estão corretos:<br>',
                       "<p class='big-bold'>Nenhuma loja deu erro na conexão!</p>",nil)
        else
        end
      end
    end
  end

  def inserir_novo_registro(data_atual)
    inserir_valor = UltimoEmail.new(
      data_envio_concluido: data_atual
    )
    if inserir_valor.save
      @logger.info("Informação cadastrada no banco de dados na tabela 'ultimo_email', informações enviadas #{data_atual}")
      true
    else
      @logger.error("Erro ao inserir valores na tabela 'ultimo_email', informações enviadas #{data_atual}")
      false
    end
  end

  public
  def verificacao_emails(validacao = 0)
    ultimo_email = UltimoEmail.order(data_envio_concluido: :desc).first
    data_atual = formatar_data
    if validacao == 0 && ultimo_email.data_envio_concluido == data_atual
      @logger.info("Já existe um registro para a data atual: #{data_atual}. Cancelando o envio.")
      return true
    end
    if validacao == 1
      begin
        if ultimo_email.nil? || ultimo_email.data_envio_concluido < data_atual
          return inserir_novo_registro(data_atual)
        else
          @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")
          return false
        end
      rescue ActiveRecord::RecordNotUnique
        @logger.error("#{data_atual} já foi inserido na coluna 'data_envio_concluido', portanto não será salvo novamente")
        false
      rescue StandardError => e
        @logger.error("Erro inesperado na função verificacao_emails: #{e.message}")
        false
      end
    end
  end

  def converter_mb_para_byte(mb)
    mb * 1024 * 1024
  end

end
