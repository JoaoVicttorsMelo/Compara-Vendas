require 'mail'
require 'yaml'

module EnviarEmail

  def enviar_email(titulo, corpo, informacao,caminho_arquivo_anexo=nil,info_opcional=nil)
    config_path = File.join(__dir__, 'config.yml')
    config = YAML.load_file(config_path)

    # Configuração do e-mail
    sender_email = config['smtp']['sender_email']
    receiver_emails = config['smtp']['receiver_emails']
    smtp_username = config['smtp']['username']
    smtp_password = config['smtp']['password']

    # Configurações do Gmail
    options = {
      address: 'smtp.gmail.com',
      port: 587,
      domain: 'gmail.com',
      user_name: smtp_username,
      password: smtp_password,
      authentication: 'plain',
      enable_starttls_auto: true
    }

    Mail.defaults do
      delivery_method :smtp, options
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

      # Corpo do e-mail com HTML e estilo
      body    <<-HTML
  <html>
  <body>
    <H1 style="color: red;"><p><strong><center>#{corpo}</center></strong></p></H1>
    <H2><p><center>#{informacao}</center></p></H2><br><br>
    <H3><p><center>#{info_opcional}</center></p></H3>
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
    # Enviando o e-mail
    mail.deliver!
  end
  end