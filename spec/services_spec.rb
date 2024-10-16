# spec/services_spec.rb

require 'rspec'
require 'sqlite3'
require 'tiny_tds'
require_relative '../classes/services'  # Ajuste o caminho conforme sua estrutura

RSpec.describe Services do
  let(:logger) { instance_double(Logger) }
  let(:db) { instance_double(SQLite3::Database) }

  before do
    # Permite a criação de uma nova instância de Logger que retorna o mock
    allow(Logger).to receive(:new).and_return(logger)

    # Permite os métodos que são chamados no Logger
    allow(logger).to receive(:level=)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)

    # Permite a criação de uma nova instância de Database que retorna o mock
    allow(SQLite3::Database).to receive(:new).and_return(db)
  end

  describe '#executar_consulta_loja' do
    let(:service) { Services.new(':memory:') }
    let(:row) { ['127.0.0.1', '000123', 'Filial X'] }

    context 'quando a consulta retorna um valor' do
      it 'retorna os valores formatados corretamente' do
        mock_client_loja = instance_double(TinyTds::Client)
        allow(service).to receive(:conectar_banco_server_loja).and_return(mock_client_loja)
        allow(service).to receive(:executar_banco_server).and_return([{ 'total_pago' => 1500.50 }])

        resultado = service.send(:executar_consulta_loja, row[0], row[1], row[2])

        expect(resultado).to eq(['1500.50', '000123', 'Filial X', '127.0.0.1'])
        expect(logger).to have_received(:info).with("Valor na loja: 1500.50 da filial Filial X (000123)")
      end
    end

    context 'quando a consulta não retorna nenhum valor' do
      it 'retorna nil e registra uma mensagem' do
        mock_client_loja = instance_double(TinyTds::Client)
        allow(service).to receive(:conectar_banco_server_loja).and_return(mock_client_loja)
        allow(service).to receive(:executar_banco_server).and_return([{}])

        resultado = service.send(:executar_consulta_loja, row[0], row[1], row[2])

        expect(resultado).to be_nil
        expect(logger).to have_received(:info).with("Filial Filial X (000123) sem venda no banco da loja")
      end
    end

    context 'quando ocorre um erro na consulta' do
      it 'retorna nil e registra o erro' do
        mock_client_loja = instance_double(TinyTds::Client)
        allow(service).to receive(:conectar_banco_server_loja).and_return(mock_client_loja)
        allow(service).to receive(:executar_banco_server).and_raise(TinyTds::Error.new("Erro de conexão"))

        resultado = service.send(:executar_consulta_loja, row[0], row[1], row[2])

        expect(resultado).to be_nil
        expect(logger).to have_received(:error).with("Erro ao consultar loja Filial X (000123): Erro de conexão")
      end
    end
  end
end
