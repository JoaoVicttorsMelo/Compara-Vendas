<div align="center">
  <h1>📊 DataSync - Sincronização de Vendas entre Lojas e Retaguarda</h1>
  <img src="https://img.shields.io/badge/Ruby-2.7%2B-red" alt="Ruby Version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/Status-Em%20Desenvolvimento-orange" alt="Status">
</div>

## 📝 Descrição

**DataSync** é uma aplicação em Ruby que realiza a sincronização de dados de vendas entre as lojas e a retaguarda. Ela compara os valores de vendas diárias, gera relatórios em Excel das discrepâncias encontradas e envia e-mails de notificação para as equipes responsáveis. O objetivo é garantir a consistência dos dados entre os sistemas locais das lojas e o sistema central de retaguarda.

## 🚀 Funcionalidades

- 🔗 **Conexão com Bancos de Dados**: Conecta-se aos bancos de dados SQLite (local), SQL Server das lojas e SQL Server da retaguarda.
- 📝 **Execução de Scripts SQL**: Executa consultas SQL seguras nas bases de dados para obter os valores de vendas.
- 📊 **Comparação de Valores**: Compara os valores de vendas das lojas com os valores da retaguarda para identificar discrepâncias.
- 📈 **Geração de Relatórios**: Gera relatórios em Excel (`.xlsx`) com as diferenças encontradas utilizando o módulo `gerar_excel.rb` e a gem `write_xlsx`.
- ✉️ **Envio de E-mails**: Envia e-mails com os relatórios em anexo para as equipes responsáveis.
- ⏰ **Agendamento de Tarefas**: Pode ser configurado para enviar e-mails a cada 30 minutos até que todas as lojas tenham sido processadas.

## 🛠️ Tecnologias Utilizadas

- **Linguagem**: 
  - ![Ruby](https://img.shields.io/badge/-Ruby-red) Ruby 2.7+
- **Banco de Dados**: SQLite, SQL Server
- **Gems**:
  - `sqlite3`: Interação com o banco de dados SQLite.
  - `tiny_tds`: Conexão com bancos de dados SQL Server.
  - `write_xlsx`: Geração de relatórios em Excel.
  - `yaml`: Carregamento de arquivos de configuração.
  - `time`: Manipulação de datas e horas.
  - `mail`: Envio de e-mails.

## 📋 Pré-requisitos

- Ruby instalado na versão 2.7 ou superior.
- Acesso aos bancos de dados SQLite e SQL Server.
- Configuração adequada do arquivo `config.yml` com as credenciais de acesso aos bancos de dados.
- Configuração do módulo `EnviarEmail` com as credenciais do servidor SMTP.
- Dependências instaladas listadas no `Gemfile`.

## 🔧 Instalação

1. **Clone o repositório**:
    ```bash
    git clone https://github.com/JoaoVicttorsMelo/Compara-Vendas.git
    cd datasync
    ```

2. **Instale as dependências**:
    ```bash
    bundle install
    ```

3. **Configure o arquivo `config.yml`**:
    Crie um arquivo `config.yml` na raiz do projeto com as seguintes informações:
    ```yaml
    database_server:
      username: 'seu_usuario'
      password: 'sua_senha'
      database:
        - 'nome_banco_loja'
        - 'nome_banco_loja_alternativo'
    database_ret:
      username: 'seu_usuario_ret'
      password: 'sua_senha_ret'
      host: 'endereco_do_servidor_ret'
      database: 'nome_banco_ret'
    smtp:
      sender_email: 'seu_email@dominio.com'
      receiver_emails:
        - 'destinatario1@dominio.com'
        - 'destinatario2@dominio.com'
      address: 'smtp.seuprovedor.com'
      domain: 'seudominio.com'
    ```

    Certifique-se de substituir os valores pelas credenciais reais.

4. **Configure o módulo `EnviarEmail`**:
    No arquivo `enviar_email.rb`, configure as credenciais do servidor SMTP:
    ```ruby
    # enviar_email.rb
    module EnviarEmail
      require 'mail'
      require 'yaml'

      def enviar_email(titulo, corpo, corpo2 = nil, informacao = nil, caminho_arquivo_anexo = nil, info_opcional = nil)
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

        # Resto do código...
      end
    end
    ```

## 🚀 Uso

1. **Executando a Sincronização de Dados**:
    Você pode executar o script principal para iniciar o processo de sincronização:
    ```bash
    ruby main.rb
    ```
    Onde `main.rb` é o arquivo que instancia a classe `Services` e chama o método `datasync`.

2. **Agendamento de Tarefas**:
    Para agendar o envio de e-mails a cada 30 minutos, você pode utilizar o `cron` do sistema ou uma gem como `rufus-scheduler`.

    **Exemplo usando `cron`**:
    - Edite o crontab:
      ```bash
      crontab -e
      ```
    - Adicione a seguinte linha para executar o script a cada 30 minutos:
      ```bash
      */30 * * * * /usr/bin/ruby /caminho/para/seu_projeto/main.rb
      ```

3. **Visualizando os Relatórios**:
    Os relatórios gerados serão salvos na raiz do projeto com o nome `relatorio_venda.xlsx`.

## 🗂️ Estrutura do Projeto

```plaintext
datasync/
├── lib/
    └── config.yml
    └── util.rb
    └── enviar_email.rb
    └── gerar_excel.rb
    └── conexao_banco.rb
├── classes/
    └── services.rb
    └── filial_ip
├── main.rb
├── Gemfile
└── README.md
