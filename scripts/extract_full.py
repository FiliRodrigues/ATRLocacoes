"""
Script de extração completa dos veículos do Excel.
Mapeamento de linhas (baseado em debug_rows.py):
  Linha 3:  dados do veículo (tipo, marca, modelo, ano, placa, renavam, chassi, km_inicial)
  Linha 4:  km_vistoria em col J (idx 9)
  Linha 5:  situação em col C (idx 2)
  Linha 9:  financiamento (status col B, val_fin col C, val_entrada col D, val_fipe col E)
            IPVA 2023 total col K (idx 10), status col L (idx 11)
  Linha 10: Licenciamento 2023: total col K, status col L
  Linha 13: IPVA 2024: total col K, status col L
  Linha 14: Licenciamento 2024
  Linha 17: IPVA 2025
  Linha 18: Licenciamento 2025
  Linha 21: IPVA 2026
  Linha 22: Licenciamento 2026
  Linha 25: IPVA 2027
  Linha 26: Licenciamento 2027
  Linhas 33-44: Manutenção mensal (JAN a DEZ)
               col H(7)=2023, I(8)=2024, J(9)=2025, K(10)=2026, L(11)=2027
  Linha 46: Totais manutenção por ano
  Linhas 53-64: Multas mensais (mesma estrutura)
  Linha 66: Totais multas por ano
"""

import openpyxl
from datetime import datetime

wb = openpyxl.load_workbook(
    r'C:\Users\filip\Desktop\Controle Veículos ATR.xlsx', data_only=True
)

ANOS_MANUT = {2023: 7, 2024: 8, 2025: 9, 2026: 10, 2027: 11}  # col index
MESES = ['JANEIRO','FEVEREIRO','MARÇO','ABRIL','MAIO','JUNHO',
         'JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO']

def val(row, idx, default=None):
    if row is None or idx >= len(row):
        return default
    v = row[idx]
    if isinstance(v, datetime):
        return v.date()
    return v if v is not None else default

def safe_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None

veiculos = []

for ws in wb.worksheets:
    rows = {}
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=70, values_only=True), start=1):
        rows[i] = row

    def r(n):
        return rows.get(n, [None]*30)

    placa = val(r(3), 5)
    if not placa or placa == 'Placa':
        continue

    # ── Dados básicos ──────────────────────────────────────────────
    tipo    = val(r(3), 1)
    marca   = val(r(3), 2)
    modelo  = val(r(3), 3)
    ano     = val(r(3), 4)
    renavam = str(val(r(3), 6, '')).strip()
    chassi  = str(val(r(3), 7, '')).strip()
    km_ini  = safe_float(val(r(3), 9))
    km_vist_raw = val(r(4), 9)
    km_vist = safe_float(km_vist_raw) if isinstance(km_vist_raw, (int, float)) else None
    situacao = val(r(5), 2) or val(r(5), 1, 'Desconhecida')

    # ── Financiamento ───────────────────────────────────────────────
    fin = {
        'status':    val(r(9), 1),
        'financiado': safe_float(val(r(9), 2)),
        'entrada':   safe_float(val(r(9), 3)),
        'fipe':      safe_float(val(r(9), 4)),
        'total_pago': safe_float(val(r(11), 4)),
    }

    # ── IPVA por ano ────────────────────────────────────────────────
    ipva_linhas = {2023: 9, 2024: 13, 2025: 17, 2026: 21, 2027: 25}
    ipva = {}
    for ano_i, ln in ipva_linhas.items():
        rv = safe_float(val(r(ln), 10))   # col K = total
        st = val(r(ln), 11)
        if rv or st:
            ipva[ano_i] = {'valor': rv, 'status': st}

    # ── Licenciamento por ano ───────────────────────────────────────
    lic_linhas = {2023: 10, 2024: 14, 2025: 18, 2026: 22, 2027: 26}
    lic = {}
    for ano_i, ln in lic_linhas.items():
        rv = safe_float(val(r(ln), 10))
        st = val(r(ln), 11)
        if rv or st:
            lic[ano_i] = {'valor': rv, 'status': st}

    # ── Manutenção por mês/ano ──────────────────────────────────────
    manut_mensal = {}
    for mi, mes in enumerate(MESES):
        ln = 33 + mi
        row_m = r(ln)
        for ano_i, col_i in ANOS_MANUT.items():
            v = safe_float(val(row_m, col_i))
            if v and v > 0:
                manut_mensal.setdefault(ano_i, {})[mes] = v

    # Totais anuais de manutenção (linha 46)
    manut_totais = {}
    for ano_i, col_i in ANOS_MANUT.items():
        v = safe_float(val(r(46), col_i))
        if v and v > 0:
            manut_totais[ano_i] = v

    # ── Multas por mês/ano ──────────────────────────────────────────
    multas_mensal = {}
    for mi, mes in enumerate(MESES):
        ln = 53 + mi
        row_m = r(ln)
        for ano_i, col_i in ANOS_MANUT.items():
            v = safe_float(val(row_m, col_i))
            if v and v > 0:
                multas_mensal.setdefault(ano_i, {})[mes] = v

    multas_totais = {}
    for ano_i, col_i in ANOS_MANUT.items():
        v = safe_float(val(r(66), col_i))
        if v and v > 0:
            multas_totais[ano_i] = v

    veiculos.append({
        'aba': ws.title,
        'placa': placa, 'tipo': tipo, 'marca': marca, 'modelo': modelo,
        'ano': ano, 'renavam': renavam, 'chassi': chassi,
        'km_inicial': km_ini, 'km_vistoria': km_vist,
        'situacao': situacao,
        'financiamento': fin,
        'ipva': ipva,
        'licenciamento': lic,
        'manutencao': {'mensal': manut_mensal, 'totais': manut_totais},
        'multas': {'mensal': multas_mensal, 'totais': multas_totais},
    })

# ── RELATÓRIO ──────────────────────────────────────────────────────────
print(f'\n{"="*65}')
print(f'  CONTROLE VEÍCULOS ATR — {len(veiculos)} veículos extraídos')
print(f'{"="*65}')

for v in veiculos:
    print(f'\n{"─"*60}')
    print(f'  PLACA: {v["placa"]:12} | {v["marca"]} {v["modelo"]} | {v["ano"]}')
    print(f'  Tipo: {v["tipo"]}  |  Situação: {v["situacao"]}')
    print(f'  Renavam: {v["renavam"]}')
    print(f'  Chassi:  {v["chassi"]}')
    print(f'  KM Inicial: {v["km_inicial"]}  |  KM Vistoria: {v["km_vistoria"]}')

    f = v['financiamento']
    print(f'  Financiamento: {f["status"]}  |  Financiado: R${f["financiado"]}  |  '
          f'Entrada: R${f["entrada"]}  |  FIPE: R${f["fipe"]}')

    if v['ipva']:
        ipva_str = '  '.join(
            f'{a}: R${d["valor"]} [{d["status"]}]' for a, d in sorted(v['ipva'].items())
        )
        print(f'  IPVA:  {ipva_str}')

    if v['licenciamento']:
        lic_str = '  '.join(
            f'{a}: R${d["valor"]} [{d["status"]}]' for a, d in sorted(v['licenciamento'].items())
        )
        print(f'  Lic:   {lic_str}')

    if v['manutencao']['totais']:
        tot_str = '  '.join(
            f'{a}: R${t:.2f}' for a, t in sorted(v['manutencao']['totais'].items())
        )
        print(f'  Manut: {tot_str}')
        for ano_i, meses_d in sorted(v['manutencao']['mensal'].items()):
            for mes, val_m in meses_d.items():
                print(f'    {ano_i}/{mes}: R${val_m:.2f}')

    if v['multas']['totais']:
        mul_str = '  '.join(
            f'{a}: R${t:.2f}' for a, t in sorted(v['multas']['totais'].items())
        )
        print(f'  Multas: {mul_str}')

print(f'\n{"="*65}')
print(f'Placas: {", ".join(v["placa"] for v in veiculos)}')
