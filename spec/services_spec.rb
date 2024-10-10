require 'rspec'

require_relative '../classes/services'

config_path = File.expand_path('../lib/config.yml', __dir__)
config = YAML.load_file(config_path)

RSpec.describe Services do
  describe '#initialize' do
    it "configura o log corretamente" do
      service = Services.new(config['database']['db'])
      expect(service.instance_variable_get(:@logger)).to be_an_instance_of(Logger)
    end
  end
end
