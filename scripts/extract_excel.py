import openpyxl
from datetime import datetime

wb = openpyxl.load_workbook(r'C:\Users\filip\Desktop\Controle Veículos ATR.xlsx', data_only=True)

veiculos = []
for ws in wb.worksheets:
    rows = list(ws.iter_rows(min_row=1, max_row=66, values_only=True))
    def r(i):
        return rows[i-1] if i <= len(rows) else [None]*30

    info = r(2)
    tipo    = info[1]
    marca   = info[2]
    modelo  = info[3]
    ano     = info[4]
    placa   = info[5]
    renavam = info[6]
    chassi  = info[7]
    km_ini  = info[9]
    km_vist = r(3)[9]

    sit4    = r(4)
    sit_val = sit4[2]

    fin = r(7)
    fin_status  = fin[1]
    val_fin     = fin[2]
    val_entrada = fin[3]
    val_fipe    = fin[4]

    # IPVA por ano (linha 9=2023, 13=2024, 17=2025, 21=2026, 25=2027) col H=valor, L=status
    ipva = {}
    for ano_idx, linha in [(2023, 9), (2024, 13), (2025, 17), (2026, 21), (2027, 25)]:
        row = r(linha)
        ipva[ano_idx] = {'valor': row[7], 'status': row[11]}

    # Licenciamento por ano
    lic = {}
    for ano_idx, linha in [(2023, 9), (2024, 9), (2025, 17), (2026, 21), (2027, 25)]:
        row = r(linha)
        lic[ano_idx] = {'valor': row[10], 'status': row[11]}

    # Manutenção mensal por ano (cols H=2023, I=2024, J=2025, K=2026, L=2027)
    meses = ['JAN','FEV','MAR','ABR','MAI','JUN','JUL','AGO','SET','OUT','NOV','DEZ']
    manut = {}
    for mi, mes in enumerate(meses):
        linha = 33 + mi
        row = r(linha)
        manut[mes] = {
            2023: row[7],
            2024: row[8],
            2025: row[9],
            2026: row[10],
            2027: row[11],
        }

    veiculos.append({
        'aba': ws.title,
        'tipo': tipo, 'marca': marca, 'modelo': modelo, 'ano': ano,
        'placa': placa, 'renavam': renavam, 'chassi': chassi,
        'km_inicial': km_ini, 'km_vistoria': km_vist,
        'situacao': sit_val,
        'fin_status': fin_status, 'val_financiado': val_fin,
        'val_entrada': val_entrada, 'val_fipe': val_fipe,
        'ipva': ipva,
        'manut': manut,
    })

print("=" * 70)
print(f"TOTAL DE VEÍCULOS: {len(veiculos)}")
print("=" * 70)

for v in veiculos:
    print(f"\n{'='*60}")
    print(f"PLACA: {v['placa']}  |  ABA: {v['aba']}")
    print(f"  Tipo:    {v['tipo']}")
    print(f"  Marca:   {v['marca']}")
    print(f"  Modelo:  {v['modelo']}")
    print(f"  Ano:     {v['ano']}")
    print(f"  Renavam: {v['renavam']}")
    print(f"  Chassi:  {v['chassi']}")
    print(f"  KM Ini:  {v['km_inicial']}  |  KM Vist: {v['km_vistoria']}")
    print(f"  Situação: {v['situacao']}")
    print(f"  Financ:  {v['fin_status']}  |  Val.Fin: {v['val_financiado']}  |  Entrada: {v['val_entrada']}  |  FIPE: {v['val_fipe']}")

    print("  IPVA:")
    for ano_i, dados in v['ipva'].items():
        if dados['valor']:
            print(f"    {ano_i}: R$ {dados['valor']}  [{dados['status']}]")

    print("  MANUT (total anual):")
    totais = {2023:0, 2024:0, 2025:0, 2026:0, 2027:0}
    for mes, anos in v['manut'].items():
        for ano_i, val in anos.items():
            if val and isinstance(val, (int, float)):
                totais[ano_i] += val
    for ano_i, tot in totais.items():
        if tot > 0:
            print(f"    {ano_i}: R$ {tot:.2f}")
