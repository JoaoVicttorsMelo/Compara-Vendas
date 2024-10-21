# Importação das classes e bibliotecas necessárias
require_relative 'classes/services'  # Importa a classe Services localizada em 'classes/services.rb'
require 'yaml'                       # Biblioteca para manipulação de arquivos YAML

# Definição do caminho absoluto para o arquivo de configuração 'config.yml'
config_path = File.expand_path('../Atualizar_Lojas/lib/config.yml', __dir__)

# Carrega as configurações do arquivo YAML
config = YAML.load_file(config_path)

# Instancia um objeto da classe Services com o parâmetro do banco de dados
obj = Services.new(config['database']['db'])

# Executa o metodo 'datasync' do objeto Services
obj.datasync
# Explicação:
# - `datasync` é um metodo definido na classe `Services` que realiza a sincronização de dados entre lojas e retaguarda.
# - Este metodo  inclui operações como comparação de valores, atualização de registros e envio de notificações por e-mail sobre o status da sincronização.

