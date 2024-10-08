module Util

  def verifica_horario
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
      if horario.hour >=9 and horario.hour <=23
        true
      else
        puts "Fora de horário de funcionamento"
        false
      end
    end
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
  def formatar_data
    (Date.today -1 ).strftime("%y%m%d")
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
        enviar_email(
          "Datasync: Lojas com diferenças",
          "Lojas com diferenças:<br>",
          "<p class='big-bold'> Segue as lojas que não foram possíveis de fazer a verificação automática:</p>",
          consulta_caixa_lancamento(show_list),
          nil,
          "<h1>Possíveis Diferenças nas Vendas!</h1>
  <p class='big-bold'>As lojas listadas acima não puderam ser conectadas para verificação automática. Essas diferenças serão validadas somente após:</p>
  <table border='1' cellpadding='5' cellspacing='0' style='width: 100%; margin-top: 10px;'>
    <tr>
      <td style='text-align: center; vertical-align: middle;'>Abertura das lojas e reativação dos terminais, especialmente se estiverem em fusos horários diferentes.</td>
    </tr>
  </table>"
        )
      else
        enviar_email("Datasync: Lojas com diferenças",'Olá, boa tarde<br> Segue lojas que estão com diferenças entre Retaguarda e Loja em anexo:<br>',
                     "<p class='big-bold'><center>Nenhuma loja deu erro na conexão!</center><p>", anexo)
      end
    else
      if show_list
        enviar_email(
          "Datasync: Lojas sem diferenças",
          "Valores Lojas X Retaguarda estão Corretos, exceto as filiais abaixo:<br>",
          "<p class='big-bold'>Segue as lojas que não foram possíveis de fazer a verificação automática:<p><br>",
          consulta_caixa_lancamento(show_list),
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
        enviar_email("Datasync: Lojas sem diferenças",'Valores Lojas X Retaguarda estão corretos:<br>',
                     "<p class='big-bold'>Nenhuma loja deu erro na conexão!</p>",nil)
      end
    end
  end

end
