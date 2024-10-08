require 'mail'
require 'yaml'

module EnviarEmail
  def enviar_email(titulo, corpo, corpo2 = nil, informacao = nil , caminho_arquivo_anexo = nil, info_opcional = nil)
    config_path = File.join(__dir__, 'config.yml')
    config = YAML.load_file(config_path)

    # Configuração do e-mail
    sender_email = config['smtp']['sender_email']
    receiver_emails = config['smtp']['receiver_emails']
    adress = config['smtp']['address']
    domain = config['smtp']['domain']

    # Configurações do servidor SMTP interno
    options = {
      address: adress,
      port: 25,
      domain: domain,
      authentication: nil,
      enable_starttls_auto: false
    }

    Mail.defaults do
      delivery_method :smtp, options
    end

    # Gerar as linhas da tabela a partir de 'informacao'
    if informacao != nil
      informacao_array = informacao.split('<br>')
      table_rows = informacao_array.map do |item|
        "<tr><td style='text-align: center; vertical-align: middle;'>#{item}</td></tr>"
      end.join("\n")
    end


    # Criando o e-mail com estilo e prioridade
    mail = Mail.new do
      from    sender_email
      to      receiver_emails.join(', ')
      subject titulo
      content_type 'text/html; charset=UTF-8'

      # Definir prioridade alta
      header['X-Priority'] = '1'
      header['X-MSMail-Priority'] = 'High'
      header['Importance'] = 'High'

      # Corpo do e-mail com HTML e tabela
      body    <<-HTML
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Relatório Datasync</title>
 <style>
  body {
  font-family: 'Arial', sans-serif;
  background-color: #f4f4f9;
  color: #333333;
  line-height: 1.6;
}

/* Título principal - h1 */
h1 {
  color: #d9534f;
  text-align: center;
  font-size: 28px; /* Aumentei para dar mais destaque */
  margin-bottom: 20px;
}

/* Subtítulos destacados - big-bold */
.big-bold {
  font-size: 22px; /* Um pouco maior para destacar */
  font-weight: bold;
  text-align: center;
  margin-bottom: 15px;
}

/* Células da tabela */
table, th, td {
  border: 1px solid #333333;
  padding: 12px;
  font-size: 18px; /* Fonte mais consistente com os outros elementos */
  text-align: center;
  vertical-align: middle;
}

/* Textos menores nas listas */
li {
  font-size: 18px; /* Igual ao tamanho das células, para padronizar */
  text-align: center;
  margin-bottom: 10px;
}

/* Seção de diferenças */
.differences-section h1 {
  color: #d9534f;
  text-align: center;
  margin-bottom: 10px;
  border-bottom: 2px solid red;
  padding-bottom: 10px;
}

/* Ajuste de responsividade */
@media (max-width: 600px) {
  h1 {
    font-size: 24px;
  }

  .big-bold {
    font-size: 20px;
  }

  table, th, td, li {
    font-size: 16px;
  }
}

  /* Ajuste de responsividade */
  @media (max-width: 600px) {
    h1 {
      font-size: 22px;
    }

    h2 {
      font-size: 18px;
    }

    p, li {
      font-size: 14px;
    }

    table, th, td {
      font-size: 14px;
    }
  }
</style>
</head>
<body>
  <h1 id="titulo"><strong>#{corpo}</strong></h1>
  <h2><strong>#{corpo2}</strong></h2>
<table border='1' cellpadding='5' cellspacing='0' style='width: 50%; margin: 20px auto;'>
    #{table_rows}
  </table>
#{info_opcional}
<br><br>
</body>
</html>
HTML
    end

    # Anexar o arquivo se for fornecido
    if caminho_arquivo_anexo && File.exist?(caminho_arquivo_anexo)
      mail.add_file(caminho_arquivo_anexo)
    else
      puts "Arquivo não encontrado: #{caminho_arquivo_anexo}" if caminho_arquivo_anexo
    end

    # Enviando o e-mail com tratamento de exceções
    begin
      mail.deliver!
      puts "E-mail enviado com sucesso!"
    rescue => e
      puts "Erro ao enviar e-mail: #{e.message}"
    end
  end
end
