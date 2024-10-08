require 'write_xlsx'
module GerarExcel

  def gerar_excel(list)
    nome_arquivo = 'relatorio_venda.xlsx'
    caminho_arquivo = File.expand_path(nome_arquivo, __dir__)
    workbook = WriteXLSX.new(caminho_arquivo)
    if list.any?
      cabecalho = ['Filial', 'Valor Loja', 'Valor Retaguarda', 'Diferença']
      worksheet = workbook.add_worksheet

      format_titulo = workbook.add_format(bold: true, font_size: 14, align: 'center',bg_color: '#B0E0E6',border:1)
      format_cabecalho = workbook.add_format(bold: true, bg_color: '#90EE90', align: 'center',border:1)
      format_moeda = workbook.add_format(num_format: 'R$ #,##0.00', align: 'right')
      format_bordas = workbook.add_format(border: 1)

      worksheet.merge_range('A1:D1', 'Relatório de Vendas',format_titulo)

      cabecalho.each_with_index do |valor, index|
        worksheet.write(1, index, valor,format_cabecalho)
      end
      worksheet.set_column(0, 0, 27) # Coluna A
      worksheet.set_column(1, 2, 15) # Colunas B e C
      worksheet.set_column(3, 3, 12) # Coluna D

      list.each_with_index do |linha, linha_index|
        linha.each_with_index do |valor, coluna_index|
          linha_excel = linha_index + 2

          formato = case coluna_index
                    when 1, 2 # Colunas de valores monetários
                      format_moeda
                      format_bordas
                    when 3 # Coluna de diferença
                      format_moeda
                      format_bordas
                    else # coluna das filiais
                      format_bordas
                    end

          worksheet.write(linha_excel, coluna_index, valor, formato)
        end
      end
    end
    # Aplica formatação condicional na coluna de Diferença
    ultima_linha = list.size + 2
    worksheet.conditional_formatting("D3:D#{ultima_linha}", {
      type: 'cell',
      criteria: '<',
      value: 0,
      format: workbook.add_format(font_color: 'red')
    })

    workbook.close
    caminho_arquivo
  end

end
