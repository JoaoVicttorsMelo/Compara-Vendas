# Importação das bibliotecas necessárias
require 'mail'       # Biblioteca para envio de e-mails
require 'yaml'  # Biblioteca para manipulação de arquivos YAML
require_relative '../classes/services'

# Definição do módulo EnviarEmail que encapsula funcionalidades de envio de e-mails
module EnviarEmail
  # Metodo para enviar e-mails com várias opções de conteúdo e anexos
  #
  # @param titulo [String] o assunto do e-mail
  # @param corpo [String] o conteúdo principal do e-mail (título em HTML)
  # @param corpo2 [String, nil] conteúdo secundário do e-mail (subtítulo em HTML)
  # @param informacao [Array, String, nil] informações adicionais para serem incluídas em uma tabela HTML
  # @param caminho_arquivo_anexo [String, nil] caminho para um arquivo a ser anexado ao e-mail
  # @param info_opcional [String, nil] informações opcionais adicionais para serem incluídas no corpo do e-mail
  def enviar_email(titulo, corpo, corpo2 = nil, informacao = nil, caminho_arquivo_anexo = nil, info_opcional = nil)
    # Define o caminho para o arquivo de configuração 'config.yml' localizado na mesma pasta do módulo
    config_path = File.join(__dir__, 'config.yml')
    # Carrega as configurações do arquivo YAML
    config = YAML.load_file(config_path)

    # Configuração do e-mail a partir das configurações carregadas
    sender_email = config['smtp']['sender_email']          # Endereço de e-mail do remetente
    receiver_emails = config['smtp']['receiver_emails']    # Lista de e-mails dos destinatários principais
    bcc_emails = config['smtp']['bcc_emails']              # Lista de e-mails para CCO (cópia oculta)
    adress = config['smtp']['address']                      # Endereço do servidor SMTP
    domain = config['smtp']['domain']                        # Domínio para o SMTP

    # Configurações do servidor SMTP interno
    options = {
      address: adress,                    # Endereço do servidor SMTP
      port: 25,                           # Porta do servidor SMTP (25 é padrão para SMTP sem SSL/TLS)
      domain: domain,                     # Domínio do remetente
      authentication: nil,                # Tipo de autenticação (nil significa sem autenticação)
      enable_starttls_auto: false         # Desativa STARTTLS (transporte seguro)
    }

    # Configura o metodo de entrega do Mail para SMTP com as opções definidas
    Mail.defaults do
      delivery_method :smtp, options
    end

    # Gera as linhas da tabela a partir de 'informacao', se fornecido
    if informacao
      # Converte 'informacao' para um array se não for
      informacao_array = informacao.is_a?(Array) ? informacao : informacao.split('<br>')
      # Mapeia cada item para uma linha de tabela HTML
      table_rows = informacao_array.map do |item|
        "<tr><td style='text-align: center; vertical-align: middle;'>#{item}</td></tr>"
      end.join("\n")  # Junta todas as linhas em uma única string separada por quebras de linha
    end

    # Criação do e-mail com estilo e prioridade definidos
    mail = Mail.new do
      from    sender_email                             # Define o remetente
      to      receiver_emails.join(', ')              # Define os destinatários principais
      bcc     bcc_emails.join(', ')                   # Define os destinatários de CCO
      subject titulo                                  # Define o assunto do e-mail
      content_type 'text/html; charset=UTF-8'         # Define o tipo de conteúdo como HTML com codificação UTF-8

      # Define a prioridade do e-mail como alta
      header['X-Priority'] = '1'                       # Prioridade alta para alguns clientes de e-mail
      header['X-MSMail-Priority'] = 'High'             # Prioridade alta específica para clientes Microsoft Mail
      header['Importance'] = 'High'                    # Define a importância como alta

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

  /* Subtítulos destacados - h2 */
  h2 {
    color: #5bc0de;
    text-align: center;
    font-size: 22px;
    margin-bottom: 15px;
  }

  /* Classe para textos em negrito e grande */
  .big-bold {
    font-size: 22px; /* Um pouco maior para destacar */
    font-weight: bold;
    text-align: center;
    margin-bottom: 15px;
  }

  /* Estilização das tabelas */
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

    # Adiciona o arquivo anexado se o caminho for fornecido e o arquivo existir
    if caminho_arquivo_anexo && File.exist?(caminho_arquivo_anexo)
      mail.add_file(caminho_arquivo_anexo)  # Anexa o arquivo ao e-mail
    else
      # Exibe uma mensagem no console se o arquivo não for encontrado, mas apenas se um caminho foi fornecido
      @logger.info "Arquivo não encontrado: #{caminho_arquivo_anexo}" if caminho_arquivo_anexo
    end

    # Envio do e-mail com tratamento de exceções
    begin
      mail.deliver!  # Tenta enviar o e-mail
      @logger.info "E-mail enviado com sucesso!"  # Mensagem de sucesso no console
    rescue => e
      @logger.error "Erro ao enviar e-mail: #{e.message}"  # Mensagem de erro no console em caso de falha
    end
  end
end
