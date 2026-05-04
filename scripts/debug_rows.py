import openpyxl

wb = openpyxl.load_workbook(r'C:\Users\filip\Desktop\Controle Veículos ATR.xlsx', data_only=True)
ws = wb.worksheets[0]
print(f'=== {ws.title} === dims: {ws.dimensions}')
print('Primeiras 15 linhas (indices reais):')
for i, row in enumerate(ws.iter_rows(min_row=1, max_row=15, values_only=True), start=1):
    nao_nulos = [(j, c) for j, c in enumerate(row) if c is not None]
    if nao_nulos:
        print(f'  Linha {i:02d}: {nao_nulos[:8]}')
