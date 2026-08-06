# Plan — Filter Sektor Multi-Lapis pada Daftar Saham

## Tujuan

Saat ini `StockListScreen` hanya punya filter satu lapis: dropdown `Sector`
(IDX 12 sektor, mis. "Energi", "Keuangan"). Padahal data `dim_stocks` punya
3 lapis sektor: `Sector` → `Primary_Sector` → `Sub_Sector`.

Filter multi-lapis (berjenjang / cascading):

```
Sektor (Energi) → Sub Sektor Primer (Minyak & Gas) → Sub Sektor (Eksplorasi & Produksi)
```

Pemilihan di level atas **membatasi** pilihan di level bawah (chained
dropdown). Total & paginasi tetap akurat karena filter dijalankan server-side
(di SQL, bukan difilter client-side).

## Arsitektur

Semua filter via query param backend:

- `GET /api/idx/stocks?limit=&offset=&q=&sector=&primary_sector=&sub_sector=`

Backend menyediakan **2 endpoint baru** (opsional/helper) + perluasan filter
yang sudah ada. Client membangun pilihan dropdown dari data nyata DB, bukan
hardcoded.

## Perubahan Backend (Python/FastAPI)

### 1. `api/idx.py` — perluas endpoint list

Tambah query params `primary_sector`, `sub_sector`, teruskan ke service.
Ganti `list_stocks(...)`:

```python
@router.get("/stocks")
async def list_stocks(
    q: Optional[str] = Query(None),
    sector: Optional[str] = Query(None),
    primary_sector: Optional[str] = Query(None),
    sub_sector: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user: dict = Depends(get_current_user),
):
    return stock_service.get_all_stocks(
        limit, offset,
        q=q or "",
        sector=sector or "",
        primary_sector=primary_sector or "",
        sub_sector=sub_sector or "",
    )
```

### 2. `core/stock/__init__.py` — teruskan param

```python
def get_all_stocks(limit: int = 100, offset: int = 0, q: str = "",
                   sector: str = "", primary_sector: str = "",
                   sub_sector: str = "") -> dict:
    return queries.get_all_stocks(limit, offset, q, sector,
                                  primary_sector, sub_sector)
```

### 3. `core/stock/queries.py` — SQL filter berjenjang + helper

Perluas `get_all_stocks(...)` dengan 3 klausa `AND` (satu per level).
Hanya level yang terisi yang ikut di WHERE:

```python
def get_all_stocks(limit: int = 100, offset: int = 0,
                   q: str = "", sector: str = "",
                   primary_sector: str = "", sub_sector: str = "") -> dict:
    """..."""
    q_upper = q.strip().upper()
    where = ["(%s = '' OR ticker LIKE %s OR company_name LIKE %s)",
             "(%s = '' OR Sector = %s)",
             "(%s = '' OR Primary_Sector = %s)",
             "(%s = '' OR Sub_Sector = %s)"]
    params = [q_upper, f"%{q_upper}%", f"%{q_upper}%",
              sector, sector, primary_sector, primary_sector,
              sub_sector, sub_sector]
    where_sql = " AND ".join(where)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(f"SELECT COUNT(*) as cnt FROM dim_stocks WHERE {where_sql}", params)
        total = cur.fetchone()["cnt"]
        df = _fetchdf(conn, f"""
            SELECT ticker, company_name, Sector, Primary_Sector, Sub_Sector, label_delisted
            FROM dim_stocks WHERE {where_sql}
            ORDER BY ticker LIMIT %s OFFSET %s
        """, params + [limit, offset])
    # ...pemetaan dict sama seperti sekarang
```

Tambah helper baru untuk pilihan dropdown (hanya level yang relevan):

```python
def get_sector_options(sector: str = "",
                       primary_sector: str = "") -> dict:
    """Pilihan berjenjang untuk dropdown filter.

    - sector kosong      → daftar semua Sector (DISTINCT).
    - sector terisi      → daftar Primary_Sector milik sector tsb.
    - primary terisi     → daftar Sub_Sector milik pasangan itu.
    """
```

Contoh SQL:

```sql
-- level 1: semua sektor
SELECT DISTINCT Sector FROM dim_stocks WHERE Sector IS NOT NULL AND Sector != '' ORDER BY Sector;

-- level 2: primary per sektor
SELECT DISTINCT Primary_Sector FROM dim_stocks
WHERE Sector = %s AND Primary_Sector IS NOT NULL AND Primary_Sector != ''
ORDER BY Primary_Sector;

-- level 3: sub per (sektor, primary)
SELECT DISTINCT Sub_Sector FROM dim_stocks
WHERE Sector = %s AND Primary_Sector = %s
  AND Sub_Sector IS NOT NULL AND Sub_Sector != ''
ORDER BY Sub_Sector;
```

Export lewat facade `core/stock/__init__.py` → `get_sector_options`.

### 4. Endpoint opsional: `GET /api/idx/sectors`

Tambah satu endpoint baru (di `api/idx.py`):

```python
@router.get("/sectors")
async def get_sectors(
    sector: Optional[str] = Query(None),
    primary_sector: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    return stock_service.get_sector_options(sector or "",
                                            primary_sector or "")
```

Client memanggil 3× saat filter berubah:

1. `GET /sectors` → isi dropdown Sektor
2. `GET /sectors?sector=Energi` → isi dropdown Sub Sektor Primer
3. `GET /sectors?sector=Energi&primary_sector=Minyak & Gas` → isi dropdown Sub Sektor

Dengan ini pilihan dropdown **selalu sinkron dengan data DB** (tak ada
hardcode, otomatis dapat sektor baru).

## Perubahan Flutter (Dart)

### 5. `lib/services/apis.dart` — `StockApi`

Perluas `stockList(...)`:

```dart
Future<StockListResponse> stockList({
  int limit = 100,
  int offset = 0,
  String q = '',
  String sector = '',
  String primarySector = '',
  String subSector = '',
}) async {
  final r = await _c.get('/idx/stocks', {
    'limit': '$limit',
    'offset': '$offset',
    if (q.isNotEmpty) 'q': q,
    if (sector.isNotEmpty) 'sector': sector,
    if (primarySector.isNotEmpty) 'primary_sector': primarySector,
    if (subSector.isNotEmpty) 'sub_sector': subSector,
  });
  return StockListResponse.fromJson(r as Map<String, dynamic>);
}
```

Tambah method baru:

```dart
/// [GET /idx/sectors] — pilihan filter sektor berjenjang.
Future<List<String>> sectorOptions({
  String sector = '',
  String primarySector = '',
}) async {
  final r = await _c.get('/idx/sectors', {
    if (sector.isNotEmpty) 'sector': sector,
    if (primarySector.isNotEmpty) 'primary_sector': primarySector,
  });
  return (r as List?)?.map((e) => '$e').toList() ?? [];
}
```

### 6. `lib/news_intel/screens/stock_list_screen.dart` — UI + state

State baru:

```dart
// ── Filter state (server-side) ──
Set<String> _sectors = {};
Set<String> _primarySectors = {};
Set<String> _subSectors = {};
String _selectedSector = '';
String _selectedPrimary = '';
String _selectedSub = '';
```

Logika cascade (pada `_onSectorChanged` dst.):

- Pilih Sektor → reset `_selectedPrimary`, `_selectedSub`, kosongkan
  `_primarySectors`, `_subSectors` → fetch `sectorOptions(sector:)` untuk isi
  level 2 → `_loadFirstPage()`.
- Pilih Sub Sektor Primer → reset `_selectedSub` → fetch
  `sectorOptions(sector:, primarySector:)` untuk level 3 → `_loadFirstPage()`.
- Pilih Sub Sektor → `_loadFirstPage()`.
- Tombol "×" pada badge / "Reset" → kosongkan semua level → `_loadFirstPage()`.

Kirim ke API:

```dart
final res = await _api.stockList(
  limit: _pageSize,
  offset: 0,
  q: _query,
  sector: _selectedSector,
  primarySector: _selectedPrimary,
  subSector: _selectedSub,
);
```

UI filter bar (ganti Row dropdown tunggal):

```
Row 1: [Search field]                    (tidak berubah)
Row 2: [Sektor ▾] [Sub Sektor Primer ▾]  (dropdown berjenjang)
Row 3: [Sub Sektor ▾]  (hanya muncul jika _selectedPrimary != '')
```

- Dropdown level 2 & 3 **disabled/placeholder "Pilih dulu…"** saat
  parent belum dipilih (tidak bisa pilih level bawah tanpa level atas).
- Status bar aktif-filter: tampilkan badge berantai, mis.
  `Energi · Minyak & Gas · Eksplorasi` + tombol reset semua.

### 7. `lib/news_intel/models/stock_models.dart` — tidak berubah

`StockListItem` sudah punya `sector`, `primarySector`, `subSector` + parser
JSON. Tidak perlu edit.

## Catatan

- **Consistency rule:** saat level atas berubah, level bawah harus di-reset —
  karena pilihan lama mungkin tidak valid di bawah parent baru. Ini mencegah
  hasil kosong yang membingungkan.
- **Total & pagination** otomatis benar karena filter di SQL, bukan
  client-side.
- Backend `get_all_stocks` menerima param baru — panggilan lama (dari tempat
  lain, mis. `search_stocks`) tidak terdampak karena param punya default `""`.

## Langkah Eksekusi

1. Backend: `core/stock/queries.py` — perluas `get_all_stocks` + tambah
   `get_sector_options`.
2. Backend: `core/stock/__init__.py` — teruskan param + export helper.
3. Backend: `api/idx.py` — perluas `/stocks` + tambah `/sectors`.
4. Uji backend manual (curl / docs).
5. Flutter: `lib/services/apis.dart` — perluas `stockList` + tambah
   `sectorOptions`.
6. Flutter: `lib/news_intel/screens/stock_list_screen.dart` — state + UI
   dropdown berjenjang + reset.
7. Test manual di emulator/device.
