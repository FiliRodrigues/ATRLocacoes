# -*- coding: utf-8 -*-
"""
Extrai o valor de recebimento_mensal de cada veículo a partir da tabela
"Entrada de valores de Locação" presente em cada aba da planilha.
"""
import openpyxl

CAMINHO = r'C:\Users\filip\Desktop\Controle Ve\u00edculos ATR.xlsx'

wb = openpyxl.load_workbook(CAMINHO, data_only=True)

recebimentos = {}

for ws in wb.worksheets:
    rows = {i: row for i, row in enumerate(
        ws.iter_rows(min_row=1, max_row=120, values_only=True), start=1
    )}

    # Encontra a linha com "Entrada de valores de Locação" ou "Parcela"
    header_line = None
    for ln in range(1, 120):
        row = rows.get(ln, [])
        row_strs = [str(c).strip() if c is not None else '' for c in row[:10]]
        if 'Parcela' in row_strs or any('Entrada de valores' in s for s in row_strs):
            header_line = ln
            break

    if header_line is None:
        continue

    # Procura coluna "Valor" no header
    header = rows.get(header_line, [])
    valor_col = None
    for ci, cell in enumerate(header):
        if cell is not None and 'Valor' in str(cell):
            valor_col = ci
            break

    if valor_col is None:
        continue

    # Pega o primeiro valor numérico na coluna Valor (linha header+1)
    for ln in range(header_line + 1, header_line + 5):
        cell_val = (rows.get(ln) or [None] * 10)[valor_col]
        if isinstance(cell_val, (int, float)) and cell_val > 0:
            # Extrai placa do título da aba
            title = ws.title
            # Placa é geralmente os últimos 7 chars: ex "FDI4E96"
            import re
            match = re.search(r'[A-Z]{3}\d[A-Z0-9]\d{2}', title)
            placa = match.group(0) if match else title.strip()[-7:]
            recebimentos[placa] = cell_val
            break

print("\nRecebimento mensal por veículo:")
print("-" * 40)
for placa, val in sorted(recebimentos.items()):
    print(f"  {placa}: R$ {val:,.2f}")

print("\n\nSQL para atualizar o banco:")
print("-" * 60)
for placa, val in sorted(recebimentos.items()):
    print(f"UPDATE public.financiamentos f")
    print(f"  SET recebimento_mensal = {val:.2f}")
    print(f"  FROM public.veiculos v")
    print(f"  WHERE f.veiculo_id = v.id AND v.placa = '{placa}';")
