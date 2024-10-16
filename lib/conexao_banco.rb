require 'active_record'

module ConexaoBanco
  def self.parametros(banco)
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: banco
    )
  end
end
