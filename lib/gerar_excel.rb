# Importação da biblioteca WriteXLSX para criação de arquivos Excel
require 'write_xlsx'

# Definição do módulo GerarExcel que encapsula a funcionalidade de geração de arquivos Excel
module GerarExcel
  # Metodo para gerar um arquivo Excel com os dados fornecidos
  #
  # @param list [Array<Array>] lista de dados onde cada sub-array representa uma linha no Excel
  # @return [String] caminho absoluto do arquivo Excel gerado
  def gerar_excel(list)
    nome_arquivo = 'relatorio_venda.xlsx'                             # Nome do arquivo Excel a ser criado
    caminho_arquivo = File.expand_path(nome_arquivo, __dir__)         # Caminho absoluto do arquivo Excel
    workbook = WriteXLSX.new(caminho_arquivo)                        # Cria um novo workbook Excel

    if list.any?
      cabecalho = ['Filial', 'Valor Loja', 'Valor Retaguarda', 'Diferença']  # Cabeçalhos das colunas
      worksheet = workbook.add_worksheet                                # Adiciona uma nova planilha ao workbook

      # Definição dos formatos para o Excel
      format_titulo = workbook.add_format(
        bold: true,
        font_size: 14,
        align: 'center',
        bg_color: '#B0E0E6',
        border: 1
      )  # Formato para o título principal

      format_cabecalho = workbook.add_format(
        bold: true,
        bg_color: '#90EE90',
        align: 'center',
        border: 1
      )  # Formato para os cabeçalhos das colunas

      format_moeda = workbook.add_format(
        num_format: 'R$ #,##0.00',
        align: 'right'
      )  # Formato para células com valores monetários

      format_bordas = workbook.add_format(border: 1)  # Formato para adicionar bordas nas células

      # Mescla as células de A1 a D1 para criar o título do relatório
      worksheet.merge_range('A1:D1', 'Relatório de Vendas', format_titulo)

      # Escreve os cabeçalhos na segunda linha (índice 1)
      cabecalho.each_with_index do |valor, index|
        worksheet.write(1, index, valor, format_cabecalho)
      end

      # Define a largura das colunas
      worksheet.set_column(0, 0, 27)  # Coluna A (Filial)
      worksheet.set_column(1, 2, 15)  # Colunas B e C (Valor Loja e Valor Retaguarda)
      worksheet.set_column(3, 3, 12)  # Coluna D (Diferença)

      # Escreve os dados fornecidos na lista a partir da terceira linha (índice 2)
      list.each_with_index do |linha, linha_index|
        linha.each_with_index do |valor, coluna_index|
          linha_excel = linha_index + 2  # Calcula a linha correta no Excel (começa em 2)

          # Determina o formato a ser aplicado com base na coluna
          formato = case coluna_index
                    when 1, 2  # Colunas de valores monetários
                      workbook.add_format(num_format: 'R$ #,##0.00', align: 'right', border: 1)
                    when 3  # Coluna de diferença
                      workbook.add_format(num_format: 'R$ #,##0.00', align: 'right', border: 1)
                    else  # Coluna das filiais
                      workbook.add_format(border: 1)
                    end

          # Escreve o valor na célula correspondente com o formato definido
          worksheet.write(linha_excel, coluna_index, valor, formato)
        end
      end
    end

    # Aplica formatação condicional na coluna de Diferença (D3 até a última linha)
    ultima_linha = list.size + 2  # Calcula a última linha com base no tamanho da lista
    if worksheet
      worksheet.conditional_formatting("D3:D#{ultima_linha}", {
        type: 'cell',
        criteria: '<',
        value: 0,
        format: workbook.add_format(font_color: 'red')  # Formato para valores negativos (diferença < 0)
      })

      workbook.close               # Fecha o workbook e salva o arquivo Excel
      caminho_arquivo              # Retorna o caminho absoluto do arquivo gerado
    end

  end

end
