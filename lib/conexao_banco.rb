# Importação da biblioteca ActiveRecord, que fornece funcionalidades de ORM (Object-Relational Mapping)
require 'active_record'

# Definição do módulo ConexaoBanco que gerencia a conexão com o banco de dados
module ConexaoBanco
  # Metodo de classe para estabelecer a conexão com o banco de dados
  # @param banco [String] o caminho para o arquivo do banco de dados SQLite
  def self.parametros(banco)
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',  # Define o adaptador como SQLite3
      database: banco      # Especifica o caminho do banco de dados
    )
  end
end