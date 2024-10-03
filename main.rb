require_relative 'config'
require 'yaml'

config_path = File.join(__dir__, 'config.yml')
config = YAML.load_file(config_path)
obj = Config.new(config['database']['db'])
obj.datasync("SELECT ip, cod_filial, filial FROM filiais_ip where servidor=1 order by cod_filial")
