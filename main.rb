require_relative 'classes/services'
require 'yaml'


config_path = File.expand_path('../Atualizar_Lojas/lib/config.yml', __dir__)
config = YAML.load_file(config_path)
obj = Services.new(config['database']['db'])

obj.datasync("SELECT ip, cod_filial, filial FROM filiais_ip where servidor=1  order by cod_filial")
