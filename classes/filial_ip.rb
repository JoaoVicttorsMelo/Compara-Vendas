# Importação da biblioteca ActiveRecord, que fornece funcionalidades de ORM (Object-Relational Mapping)
require 'active_record'

# Definição da classe FiliaisIp, que herda de ActiveRecord::Base para interagir com a tabela 'filiais_ip' no banco de dados
class FiliaisIp < ActiveRecord::Base
  # Especifica o nome da tabela no banco de dados que esta classe representa.
  self.table_name = "filiais_ip"
end

# Definição da classe UltimoEmail, que herda de ActiveRecord::Base para interagir com a tabela 'ultimo_email' no banco de dados
class UltimoEmail < ActiveRecord::Base
  # Especifica o nome da tabela no banco de dados que esta classe representa.
  self.table_name = "ultimo_email"
end
