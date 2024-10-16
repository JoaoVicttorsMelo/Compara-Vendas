require_relative 'classes/services'
require 'yaml'


config_path = File.expand_path('../Atualizar_Lojas/lib/config.yml', __dir__)
config = YAML.load_file(config_path)
obj = Services.new(config['database']['db'])
obj.datasync
