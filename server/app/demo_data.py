"""Data contoh untuk testing: 9 proyek, 2 akun staf, dan 50 dokumen ASLI (PDF, Word,
Excel, TXT, foto PNG) dari tahun 2000 sampai 2026, DUA BAHASA (Inggris & Indonesia),
10 dokumen untuk tiap kategori: Invoices & Receipts, Contracts & Agreements,
Tax & Financial Reports, Shipments & Trade Dossiers, Meeting Minutes.

Sebagian dokumen SALING BERHUBUNGAN supaya fitur pencarian pintar & dokumen terkait
bisa langsung dicoba, sebagian lagi BERDIRI SENDIRI (tidak ada relasinya):

  A. Seri "Dokumen 1": Formula A (2000) -> Formula B (2002) -> Formula C (2026)
  B. Kontrak 2100/KTR/PU/2000 Jalan Lingkar Sekupang -> SPMK, Addendum, BA PHO/FHO,
     kontrak Tahap II 2002 (semua menyebut nomor 2100)
  C. Kode rekening 544 (pengeluaran/belanja) di isi file 2010, 2015, 2019 (5.4.4), 2025, 2026
     -> cari "pengeluaran" ikut menemukan dokumen berisi 544 (lewat Kamus)
  D. Seri "AHSP Bidang Jalan" 2015 -> Revisi 1 2019 -> 2025
  E. Jembatan Sei Ladi lama (BM-0458, 2010) -> jembatan baru 2026 (menyebut BM-0458)
  F. Gedung Kantor Kecamatan Sekupang 2015 (kontrak 3307) -> rehabilitasi 2025
  G. Drainase Ahmad Yani 2019 (saluran DR-1120) -> normalisasi 2026
  H. Proyek berjalan Simpang Kara 2026: kontrak, invoice, notulen rapat mingguan (seri)
  I. Impor bantalan jembatan: Bill of Lading -> Packing List -> Form E -> PIB
  J. Beberapa dokumen TANPA relasi (nota ATK, notulen koordinasi, rapat tahunan, dll.)

Dijalankan otomatis saat server pertama kali start (SEED_DEMO=1 di .env) atau manual:
    D:\\python3.12\\python.exe seed_demo.py
"""
from __future__ import annotations

import hashlib
import io
import re
import struct
import zipfile
import zlib
from datetime import date, datetime, timedelta

from sqlalchemy import func, select

from . import config
from .db import Document, Project, SessionLocal, User
from .security import make_password_fields

HEADER = ["PEMERINTAH KOTA BATAM", "DINAS PEKERJAAN UMUM DAN PENATAAN RUANG", "Jl. Engku Putri No. 1, Batam Centre", ""]

# --------------------------------------------------------------------------- proyek & akun

PROJECTS = [
    dict(code="PU-JLN-2000-003", name="Pembangunan Jalan Lingkar Sekupang", type="Jalan", location="Kec. Sekupang (STA 0+000 – 4+500)",
         year=2000, funding_source="APBD Kabupaten/Kota", contract_value=3_250_000_000, contractor="PT Karya Lingkar Utama",
         supervisor="CV Mitra Teknik", ppk="Ir. Syamsul Bahri", contract_number="2100/KTR/PU/2000",
         start_date=date(2000, 4, 5), end_date=date(2000, 12, 15), status="FHO / Selesai", progress=100),
    dict(code="PU-JLN-2002-011", name="Pelebaran Jalan Lingkar Sekupang Tahap II", type="Jalan", location="Kec. Sekupang (STA 4+500 – 7+000)",
         year=2002, funding_source="APBD Kabupaten/Kota", contract_value=2_100_000_000, contractor="PT Karya Lingkar Utama",
         supervisor="CV Mitra Teknik", ppk="Ir. Syamsul Bahri", contract_number="2100-II/KTR/PU/2002",
         start_date=date(2002, 3, 10), end_date=date(2002, 11, 30), status="FHO / Selesai", progress=100),
    dict(code="PU-JBT-2010-004", name="Pembangunan Jembatan Sei Ladi (Lama)", type="Jembatan", location="Kel. Kibing, Batu Aji",
         year=2010, funding_source="APBN", contract_value=6_800_000_000, contractor="PT Beton Nusantara", supervisor="PT Rekayasa Mandiri",
         ppk="Drs. Hendra Gunawan", contract_number="0458/KTR/BM/2010", start_date=date(2010, 3, 1), end_date=date(2010, 12, 10),
         status="FHO / Selesai", progress=100),
    dict(code="PU-GDG-2015-002", name="Pembangunan Gedung Kantor Kecamatan Sekupang", type="Gedung / Bangunan", location="Kec. Sekupang",
         year=2015, funding_source="APBD Kabupaten/Kota", contract_value=4_400_000_000, contractor="CV Bangun Sejahtera",
         supervisor="CV Arsitek Muda", ppk="Ahmad Fauzi, S.T.", contract_number="3307/KTR/CK/2015",
         start_date=date(2015, 3, 2), end_date=date(2015, 11, 30), status="FHO / Selesai", progress=100),
    dict(code="PU-DRN-2019-006", name="Drainase Primer Jl. Ahmad Yani Tahap I", type="Drainase", location="Batam Kota",
         year=2019, funding_source="APBD Provinsi", contract_value=1_950_000_000, contractor="PT Tirta Utama", supervisor="CV Hidro Konsultan",
         ppk="Ir. Rahmat Hidayat", contract_number="1120/KTR/SDA/2019", start_date=date(2019, 3, 1), end_date=date(2019, 11, 20),
         status="FHO / Selesai", progress=100),
    dict(code="PU-JLN-2026-001", name="Peningkatan Jalan Simpang Kara – Batu Aji", type="Jalan", location="Kec. Batu Aji (STA 0+000 – 3+200)",
         year=2026, funding_source="APBD Kabupaten/Kota", contract_value=4_850_000_000, contractor="PT Karya Jalan Nusantara",
         supervisor="CV Cipta Konsultan", ppk="Ir. Rahmat Hidayat", contract_number="600/KTR/PUPR-BM/2026/014",
         start_date=date(2026, 3, 2), end_date=date(2026, 11, 28), status="Pelaksanaan", progress=62),
    dict(code="PU-JBT-2026-002", name="Pembangunan Jembatan Sei Ladi", type="Jembatan", location="Kel. Kibing, Batu Aji",
         year=2026, funding_source="DAK", contract_value=12_300_000_000, contractor="PT Beton Perkasa", supervisor="PT Rekayasa Mandiri",
         ppk="Dewi Lestari, S.T., M.T.", contract_number="600/KTR/PUPR-BM/2026/021", start_date=date(2026, 4, 15),
         end_date=date(2027, 2, 10), status="Pelaksanaan", progress=35),
    dict(code="PU-GDG-2025-007", name="Rehabilitasi Gedung Kantor Kecamatan Sekupang", type="Gedung / Bangunan", location="Kec. Sekupang",
         year=2025, funding_source="APBD Kabupaten/Kota", contract_value=1_975_000_000, contractor="CV Bangun Sejahtera",
         supervisor="CV Arsitek Muda", ppk="Ahmad Fauzi, S.T.", contract_number="600/KTR/PUPR-CK/2025/007",
         start_date=date(2025, 5, 5), end_date=date(2025, 10, 30), status="Masa Pemeliharaan", progress=100),
    dict(code="PU-DRN-2026-004", name="Normalisasi Drainase Primer Jl. Ahmad Yani", type="Drainase", location="Batam Kota",
         year=2026, funding_source="APBD Provinsi", contract_value=2_400_000_000, contractor="PT Tirta Utama", supervisor="CV Hidro Konsultan",
         ppk="Ir. Rahmat Hidayat", contract_number="", status="Lelang / Pengadaan", progress=0),
]

USERS = [
    dict(username="budi", full_name="Budi Santoso", role="staff", nip="198705122010011003", jabatan="Pengawas Lapangan", password="budi12345"),
    dict(username="sari", full_name="Sari Wulandari", role="staff", nip="199102032015032001", jabatan="Staf Administrasi Teknik", password="sari12345"),
]

# --------------------------------------------------------------------------- 50 dokumen
# 5 kategori (sama dengan aplikasi): INVOICE, CONTRACT, TAX, SHIPMENT, MEETING — masing-masing 10.
# Dua bahasa: sebagian berbahasa Inggris, sebagian Indonesia.
# (judul, nomor, tanggal, kategori, kode proyek, tag, seri, jenis file, isi [baris])

D = date

DOCS: list[tuple] = [
    # ===================================================== INVOICE — Invoices & Receipts / Faktur & Kuitansi
    ("Invoice Asphalt AC-WC Supply — PT Aspal Prima", "INV-AP/2026/0412", D(2026, 4, 18), "INVOICE", "PU-JLN-2026-001", "invoice, asphalt, supplier", "", "pdf",
     ["COMMERCIAL INVOICE No. INV-AP/2026/0412",
      "Supplier: PT Aspal Prima — Buyer: PT Karya Jalan Nusantara",
      "Item: Asphalt Concrete Wearing Course (AC-WC) 1,180 tons x Rp 1,685,000",
      "Total: Rp 1,988,300,000 (incl. VAT 11%) — Project: Simpang Kara road improvement, contract 600/KTR/PUPR-BM/2026/014",
      "Payment terms: 30 days after delivery."]),
    ("Kuitansi Pembayaran Termin 2 Jembatan Sei Ladi", "KWT-0773/2026", D(2026, 7, 10), "INVOICE", "PU-JBT-2026-002", "kuitansi, termin, sp2d", "", "pdf",
     ["KUITANSI PEMBAYARAN TERMIN 2",
      "Telah terima dari Dinas PUPR uang sejumlah Rp 2.952.000.000,-",
      "Untuk pembayaran termin 2 (progres fisik 30%) Pembangunan Jembatan Sei Ladi.",
      "Dibebankan pada kode rekening 544 Belanja Modal Jembatan (SP2D 0773/2026)."]),
    ("Invoice Precast PCI Girder H-210", "INV-BP/2026/088", D(2026, 6, 2), "INVOICE", "PU-JBT-2026-002", "invoice, girder, precast", "", "xlsx",
     [["Item", "Description", "Qty", "Unit", "Amount (IDR)"],
      ["1", "PCI girder H-210 span 45 m (replaces old bridge BM-0458)", 5, "pcs", 3_450_000_000],
      ["2", "Delivery & erection", 1, "lot", 410_000_000],
      ["", "VAT 11%", "", "", 424_600_000]]),
    ("Kuitansi Uang Muka 20% Rehabilitasi Gedung Kecamatan", "KWT-UM-007/2025", D(2025, 6, 9), "INVOICE", "PU-GDG-2025-007", "kuitansi, uang muka", "", "txt",
     ["KUITANSI UANG MUKA",
      "Uang muka 20% x Rp 1.975.000.000 = Rp 395.000.000,-",
      "Rehabilitasi gedung hasil kontrak 3307/KTR/CK/2015, kode rekening 544.",
      "Jaminan uang muka Bank Riau Kepri No. JUM-2025-1187."]),
    ("Equipment Rental Invoice — Excavator & Vibro Roller", "INV-RNT/2026/031", D(2026, 5, 3), "INVOICE", "PU-JLN-2026-001", "invoice, rental, heavy equipment", "", "xlsx",
     [["Equipment", "Days", "Rate/day (IDR)", "Amount (IDR)"],
      ["Excavator Komatsu PC200", 22, 3_200_000, 70_400_000],
      ["Vibro Roller Sakai SV512", 18, 2_600_000, 46_800_000],
      ["Total", "", "", 117_200_000]]),
    ("Faktur Pembelian Besi Beton D16 dan D19", "FKT-BB/2015/119", D(2015, 5, 12), "INVOICE", "PU-GDG-2015-002", "faktur, besi beton", "", "pdf",
     ["FAKTUR PENJUALAN No. FKT-BB/2015/119",
      "Besi beton ulir D16 sebanyak 12.400 kg, D19 sebanyak 8.750 kg",
      "Untuk Pembangunan Gedung Kantor Kecamatan Sekupang (kontrak 3307/KTR/CK/2015).",
      "Total Rp 243.600.000,- termasuk PPN."]),
    ("Readymix Concrete Delivery Receipts fc' 30 MPa", "RCP-RMX/2026/07", D(2026, 7, 21), "INVOICE", "PU-JBT-2026-002", "receipt, concrete, readymix", "", "docx",
     ["DELIVERY RECEIPTS — READYMIX CONCRETE fc' 30 MPa",
      "Truck mixer receipts no. 7781 to 7799 (19 trips x 7 m3 = 133 m3).",
      "Pour location: abutment A1 Sei Ladi bridge. Slump test 12 ± 2 cm — accepted.",
      "Unit price Rp 1,950,000/m3 refers to AHSP 2025."]),
    ("Kuitansi Honor Konsultan Pengawas Bulan Juni", "KWT-KP/2019/06", D(2019, 7, 5), "INVOICE", "PU-DRN-2019-006", "kuitansi, konsultan, pengawasan", "", "txt",
     ["KUITANSI", "Pembayaran jasa konsultan pengawas CV Hidro Konsultan bulan Juni 2019",
      "Pekerjaan Drainase Primer Jl. Ahmad Yani (saluran DR-1120).", "Jumlah Rp 21.500.000,-"]),
    ("Fuel Purchase Receipts — Site Generators", "RCP-FUEL/2026/Q2", D(2026, 6, 30), "INVOICE", "PU-JLN-2026-001", "receipt, fuel, operational", "", "xlsx",
     [["Date", "Station", "Liters", "Amount (IDR)"],
      ["2026-04-14", "SPBU Batu Aji", 420, 2_856_000], ["2026-05-12", "SPBU Batu Aji", 515, 3_502_000],
      ["2026-06-09", "SPBU Sekupang", 480, 3_264_000]]),
    ("Nota Pembelian ATK dan Materai Bidang Bina Marga", "NOTA-ATK/2023/11", D(2023, 11, 8), "INVOICE", "", "nota, atk, materai", "", "png", []),

    # ===================================================== CONTRACT — Contracts & Agreements / Kontrak & Perjanjian
    ("Kontrak Pembangunan Jalan Lingkar Sekupang", "2100/KTR/PU/2000", D(2000, 4, 1), "CONTRACT", "PU-JLN-2000-003", "kontrak, aspal", "", "pdf",
     ["SURAT PERJANJIAN (KONTRAK) NOMOR 2100/KTR/PU/2000",
      "Pekerjaan: Pembangunan Jalan Lingkar Sekupang STA 0+000 - 4+500",
      "Nilai kontrak: Rp 3.250.000.000,- (termasuk PPN). Penyedia: PT Karya Lingkar Utama",
      "Jangka waktu pelaksanaan 240 hari kalender, masa pemeliharaan 180 hari."]),
    ("SPMK Jalan Lingkar Sekupang", "2101/SPMK/PU/2000", D(2000, 4, 5), "CONTRACT", "PU-JLN-2000-003", "spmk, surat perintah", "", "pdf",
     ["SURAT PERINTAH MULAI KERJA",
      "Berdasarkan kontrak nomor 2100/KTR/PU/2000 tanggal 1 April 2000, penyedia diperintahkan",
      "memulai pekerjaan Pembangunan Jalan Lingkar Sekupang terhitung sejak tanggal 5 April 2000."]),
    ("Addendum I Kontrak Jalan Lingkar Sekupang", "2100-A1/KTR/PU/2000", D(2000, 9, 12), "CONTRACT", "PU-JLN-2000-003", "addendum, kontrak", "", "docx",
     ["ADDENDUM I ATAS KONTRAK NOMOR 2100/KTR/PU/2000",
      "Perubahan volume lapis aspal AC-WC dari 4.500 m2 menjadi 4.950 m2.",
      "Nilai kontrak berubah menjadi Rp 3.410.000.000,-. Ketentuan lain dalam kontrak 2100 tetap berlaku."]),
    ("Contract — Sekupang Ring Road Widening Phase II", "2100-II/KTR/PU/2002", D(2002, 3, 1), "CONTRACT", "PU-JLN-2002-011", "contract, widening", "", "pdf",
     ["CONTRACT AGREEMENT No. 2100-II/KTR/PU/2002",
      "Continuation of contract 2100/KTR/PU/2000 (Sekupang Ring Road).",
      "Widening STA 4+500 - 7+000 to 2 x 7 meters. Contract value IDR 2,100,000,000."]),
    ("Contract — Construction of Sei Ladi Bridge", "600/KTR/PUPR-BM/2026/021", D(2026, 4, 10), "CONTRACT", "PU-JBT-2026-002", "contract, bridge", "", "pdf",
     ["CONTRACT AGREEMENT No. 600/KTR/PUPR-BM/2026/021",
      "Construction of Sei Ladi Bridge replacing the old bridge, asset number BM-0458 (built 2010).",
      "New span 45 m, PCI girders, deck width 11 m. Contract value IDR 12,300,000,000 (DAK funding)."]),
    ("Kontrak Pembangunan Gedung Kantor Kecamatan Sekupang", "3307/KTR/CK/2015", D(2015, 3, 1), "CONTRACT", "PU-GDG-2015-002", "kontrak, gedung", "", "pdf",
     ["SURAT PERJANJIAN NOMOR 3307/KTR/CK/2015",
      "Pembangunan Gedung Kantor Kecamatan Sekupang 2 lantai, luas 1.200 m2.", "Nilai kontrak Rp 4.400.000.000,-"]),
    ("Contract — Rehabilitation of Sekupang District Office", "600/KTR/PUPR-CK/2025/007", D(2025, 5, 2), "CONTRACT", "PU-GDG-2025-007", "contract, rehabilitation", "", "docx",
     ["CONTRACT AGREEMENT No. 600/KTR/PUPR-CK/2025/007",
      "Rehabilitation of the building from contract 3307/KTR/CK/2015: roof, ceiling and electrical works.",
      "Contract value IDR 1,975,000,000."]),
    ("Kontrak Peningkatan Jalan Simpang Kara", "600/KTR/PUPR-BM/2026/014", D(2026, 3, 2), "CONTRACT", "PU-JLN-2026-001", "kontrak, aspal", "", "pdf",
     ["SURAT PERJANJIAN NOMOR 600/KTR/PUPR-BM/2026/014",
      "Peningkatan Jalan Simpang Kara - Batu Aji STA 0+000 - 3+200",
      "Nilai kontrak Rp 4.850.000.000,- penyesuaian harga memakai Formula C."]),
    ("Master Supply Agreement — Asphalt & Aggregates", "MSA-AP/2026/02", D(2026, 2, 25), "CONTRACT", "PU-JLN-2026-001", "agreement, supply, asphalt", "", "docx",
     ["MASTER SUPPLY AGREEMENT", "Between PT Karya Jalan Nusantara (buyer) and PT Aspal Prima (supplier).",
      "Term: 2026–2027. Price adjustment follows the escalation Formula C.", "Governing law: Republic of Indonesia."]),
    ("Perjanjian Kerja Sama Konsultan Pengawas Drainase", "PKS-1120/2026", D(2026, 3, 20), "CONTRACT", "PU-DRN-2026-004", "perjanjian, konsultan", "", "txt",
     ["PERJANJIAN KERJA SAMA", "Jasa konsultansi pengawasan Normalisasi Drainase Primer Jl. Ahmad Yani",
      "lanjutan saluran DR-1120 tahap I (2019).", "Nilai Rp 168.000.000,- jangka waktu 8 bulan."]),

    # ===================================================== TAX — Tax & Financial Reports / Pajak & Laporan Keuangan
    ("Dokumen 1 Formula A", "2100/FRM/PU/2000", D(2000, 3, 15), "TAX", "PU-JLN-2000-003", "formula, eskalasi, harga", "Dokumen 1", "pdf",
     ["FORMULA PENYESUAIAN HARGA (ESKALASI) - FORMULA A",
      "P(n) = 0,15 + 0,40 Bt/Bo + 0,30 Mt/Mo + 0,15 Et/Eo",
      "Berlaku untuk kontrak nomor 2100/KTR/PU/2000 Jalan Lingkar Sekupang."]),
    ("Dokumen 1 Formula B", "2100/FRM/PU/2002", D(2002, 6, 10), "TAX", "PU-JLN-2002-011", "formula, eskalasi, harga", "Dokumen 1", "pdf",
     ["FORMULA PENYESUAIAN HARGA (ESKALASI) - FORMULA B (perubahan dari Formula A tahun 2000)",
      "P(n) = 0,15 + 0,35 Bt/Bo + 0,30 Mt/Mo + 0,10 Et/Eo + 0,10 Lt/Lo",
      "Berlaku untuk kontrak lanjutan 2100-II/KTR/PU/2002."]),
    ("Dokumen 1 Formula C", "600/FRM/PUPR/2026/003", D(2026, 2, 20), "TAX", "PU-JLN-2026-001", "formula, escalation, price", "Dokumen 1", "docx",
     ["PRICE ADJUSTMENT (ESCALATION) — FORMULA C (replaces Formula A 2000 and Formula B 2002)",
      "P(n) = 0.15 + 0.30 Bt/Bo + 0.25 Mt/Mo + 0.15 Et/Eo + 0.15 Lt/Lo",
      "Used for the Simpang Kara road improvement package 2026."]),
    ("SPJ Belanja Pemeliharaan Jalan Triwulan I", "900/SPJ/BM/2010/01", D(2010, 4, 10), "TAX", "", "spj, belanja", "", "xlsx",
     [["Kode Rekening", "Uraian", "Jumlah (Rp)"],
      ["544", "Belanja pemeliharaan jalan dan jembatan", 185_000_000],
      ["544.01", "Tambal sulam aspal", 64_500_000], ["544.02", "Pembersihan saluran tepi jalan", 21_300_000]]),
    ("Rekap Pengeluaran Kegiatan Gedung Kecamatan", "900/RKP/CK/2015/12", D(2015, 12, 15), "TAX", "PU-GDG-2015-002", "rekap, realisasi", "", "xlsx",
     [["Kode", "Uraian", "Pagu", "Realisasi"],
      ["544", "Belanja modal gedung kantor", 4_400_000_000, 4_312_750_000],
      ["522", "Belanja jasa konsultansi pengawasan", 132_000_000, 131_500_000]]),
    ("Laporan Realisasi Anggaran Bidang Bina Marga", "900/LRA/BM/2019", D(2019, 12, 30), "TAX", "", "lra, anggaran", "", "pdf",
     ["LAPORAN REALISASI ANGGARAN TAHUN 2019 - BIDANG BINA MARGA",
      "5.4.4  Belanja Modal Jalan, Irigasi dan Jaringan   Rp 18.450.000.000   realisasi 96,2%",
      "5.2.2  Belanja Barang dan Jasa                     Rp  2.115.000.000   realisasi 91,4%"]),
    ("VAT & Income Tax Withholding Report Q2", "PJK/PPN-PPH/2025/Q2", D(2025, 7, 15), "TAX", "PU-GDG-2025-007", "tax, vat, withholding", "", "xlsx",
     [["Tax", "Base (IDR)", "Rate", "Amount (IDR)"],
      ["VAT (PPN)", 395_000_000, "11%", 43_450_000], ["Income tax art. 4(2) construction", 395_000_000, "1.75%", 6_912_500],
      ["Total withheld", "", "", 50_362_500]]),
    ("Unit Price Analysis (AHSP) — Road Works", "050/AHSP/BM/2015", D(2015, 1, 20), "TAX", "", "ahsp, unit price", "AHSP Bidang Jalan", "xlsx",
     [["Code", "Work item", "Unit", "Unit price (IDR)"],
      ["7.1", "Asphalt wearing course (AC-WC)", "ton", 1_245_000], ["7.2", "Asphalt binder course (AC-BC)", "ton", 1_198_000],
      ["5.1", "Aggregate base class A", "m3", 498_000]]),
    ("Analisa Harga Satuan Pekerjaan (AHSP) Bidang Jalan Revisi 1", "050/AHSP/BM/2019", D(2019, 2, 11), "TAX", "", "ahsp, harga satuan", "AHSP Bidang Jalan", "xlsx",
     [["Kode", "Uraian Pekerjaan", "Satuan", "Harga Satuan (Rp)"],
      ["7.1", "Lapis Aus Aspal (AC-WC)", "ton", 1_410_000], ["7.2", "Lapis Antara (AC-BC)", "ton", 1_356_000],
      ["5.1", "Lapis Pondasi Agregat Kelas A", "m3", 562_000]]),
    ("Analisa Harga Satuan Pekerjaan (AHSP) Bidang Jalan", "050/AHSP/BM/2025", D(2025, 1, 15), "TAX", "PU-JLN-2026-001", "ahsp, harga satuan", "AHSP Bidang Jalan", "xlsx",
     [["Kode", "Uraian Pekerjaan", "Satuan", "Harga Satuan (Rp)"],
      ["7.1", "Lapis Aus Aspal (AC-WC)", "ton", 1_685_000], ["7.2", "Lapis Antara (AC-BC)", "ton", 1_602_000],
      ["5.1", "Lapis Pondasi Agregat Kelas A", "m3", 671_000], ["9.3", "Beton fc' 30 MPa", "m3", 1_950_000]]),

    # ===================================================== SHIPMENT — Shipments & Trade Dossiers / Pengiriman & Dokumen Dagang
    ("Bill of Lading — Elastomeric Bearing Pads (Shanghai → Batam)", "BL-MSCU7489201", D(2026, 5, 6), "SHIPMENT", "PU-JBT-2026-002", "bill of lading, import, bearing", "", "pdf",
     ["MASTER BILL OF LADING No. MSCU7489201", "Port of loading: Shanghai (CNSHA) — Port of discharge: Batu Ampar, Batam (IDBTH)",
      "Cargo: 24 elastomeric bearing pads 450x500x84 mm for Sei Ladi bridge (replacing BM-0458)",
      "Gross weight 6,240 kg — 1 x 20' container, seal MSC-90218."]),
    ("Packing List — Elastomeric Bearing Pads", "PL-SZ/2026/118", D(2026, 5, 6), "SHIPMENT", "PU-JBT-2026-002", "packing list, bearing", "", "xlsx",
     [["Case No.", "Description", "Qty", "Net (kg)", "Gross (kg)"],
      ["1/2", "Elastomeric bearing pad type A", 12, 2_880, 3_110], ["2/2", "Elastomeric bearing pad type B", 12, 2_880, 3_130]]),
    ("Certificate of Origin — Bearing Pads Form E", "COO-E-2026-55871", D(2026, 5, 4), "SHIPMENT", "PU-JBT-2026-002", "certificate of origin, form e", "", "pdf",
     ["CERTIFICATE OF ORIGIN — FORM E (ASEAN-China FTA)", "Exporter: Shanghai Rubber Engineering Co., Ltd.",
      "Consignee: PT Beton Perkasa, Batam. HS Code 4016.99 — preferential tariff 0%."]),
    ("Pemberitahuan Impor Barang (PIB) Bantalan Jembatan", "PIB-000417/2026", D(2026, 5, 15), "SHIPMENT", "PU-JBT-2026-002", "pib, bea cukai, impor", "", "docx",
     ["PEMBERITAHUAN IMPOR BARANG (PIB) NOMOR 000417",
      "Barang: bantalan elastomer jembatan 24 unit (B/L MSCU7489201).",
      "Bea masuk 0% (Form E), PPN impor 11%. Jalur hijau — barang dapat dikeluarkan."]),
    ("Surat Jalan Pengiriman Aspal Curah", "SJ-AP/2026/0318", D(2026, 4, 16), "SHIPMENT", "PU-JLN-2026-001", "surat jalan, aspal", "", "txt",
     ["SURAT JALAN No. SJ-AP/2026/0318", "Dari: AMP PT Aspal Prima, Tanjung Uncang",
      "Ke: Lokasi proyek Jalan Simpang Kara STA 1+200", "Muatan: AC-WC 24 ton, suhu saat muat 155 °C."]),
    ("Mill Test Certificate — Deformed Steel Bars D16/D19", "MTC-KS/2015/0442", D(2015, 5, 10), "SHIPMENT", "PU-GDG-2015-002", "mill test, steel", "", "pdf",
     ["MILL TEST CERTIFICATE", "Product: deformed steel bars BjTS 420, D16 and D19 (heat no. K-0442)",
      "Yield strength 455 MPa, tensile 610 MPa, elongation 18% — conforms to SNI 2052.",
      "Delivered for Sekupang district office building, contract 3307/KTR/CK/2015."]),
    ("Berita Acara Pemeriksaan Material Box Culvert", "BAPM-1120/2019", D(2019, 4, 2), "SHIPMENT", "PU-DRN-2019-006", "pemeriksaan material, box culvert", "", "docx",
     ["BERITA ACARA PEMERIKSAAN MATERIAL", "Box culvert precast 2,0 x 1,5 m sebanyak 85 segmen untuk saluran DR-1120.",
      "Kuat tekan sampel 37 MPa (rencana 35 MPa) - DITERIMA."]),
    ("Shipment Tracking — Precast Box Culvert Lot 2", "TRK-1120/2026/02", D(2026, 4, 8), "SHIPMENT", "PU-DRN-2026-004", "tracking, box culvert, delivery", "", "xlsx",
     [["Truck", "Segments", "Departed", "Arrived", "Status"],
      ["BP 8811 AB", 6, "08:10", "10:05", "Unloaded"], ["BP 8812 AB", 6, "08:40", "10:52", "Unloaded"],
      ["BP 8840 AB", 6, "09:15", "-", "In transit"]]),
    ("Uji Beton Jembatan Sei Ladi K-300", "LAB-0458/2010", D(2010, 8, 14), "SHIPMENT", "PU-JBT-2010-004", "uji beton, k-300", "", "pdf",
     ["HASIL UJI KUAT TEKAN BETON - JEMBATAN SEI LADI (BM-0458)",
      "Mutu rencana K-300. Benda uji kubus 15x15x15 cm umur 28 hari.", "Rata-rata kuat tekan 318 kg/cm2 - MEMENUHI SYARAT."]),
    ("Foto Penerimaan Girder di Lokasi Jembatan", "", D(2026, 6, 12), "SHIPMENT", "PU-JBT-2026-002", "foto, girder, penerimaan", "", "png", []),

    # ===================================================== MEETING — Meeting Minutes / Notulen Rapat
    ("Notulen Rapat Koordinasi Bulanan Kepala Bidang", "005/NOT/SEKR/2005", D(2005, 2, 21), "MEETING", "", "notulen, rapat koordinasi", "", "txt",
     ["NOTULEN RAPAT KOORDINASI BULANAN", "Hari Senin, 21 Februari 2005, ruang rapat lantai 2.",
      "1. Evaluasi progres paket jalan. 2. Rencana pengadaan triwulan II. 3. Lain-lain."]),
    ("Notulen Rapat Serah Terima Pertama (PHO) Jalan Lingkar Sekupang", "2150/NOT-PHO/PU/2000", D(2000, 12, 20), "MEETING", "PU-JLN-2000-003", "notulen, pho, serah terima", "", "pdf",
     ["NOTULEN RAPAT SERAH TERIMA PERTAMA PEKERJAAN (PHO)", "Kontrak nomor 2100/KTR/PU/2000 beserta Addendum I.",
      "Pekerjaan dinyatakan selesai 100% dengan catatan perbaikan minor marka jalan."]),
    ("Pre-Construction Meeting Minutes — Simpang Kara Road", "PCM-014/2026", D(2026, 3, 4), "MEETING", "PU-JLN-2026-001", "minutes, pre-construction meeting", "", "docx",
     ["PRE-CONSTRUCTION MEETING (PCM) MINUTES", "Contract 600/KTR/PUPR-BM/2026/014 — Simpang Kara road improvement.",
      "Agreed: mobilisation within 7 days, weekly site meeting every Monday 09:00, MC-0 on 5 March 2026.",
      "Attendees: PPK, contractor, supervision consultant, PUPR planning unit (11 persons)."]),
    ("Weekly Site Meeting Minutes — Week 1 Simpang Kara", "WSM-01/014/2026", D(2026, 3, 9), "MEETING", "PU-JLN-2026-001", "minutes, weekly meeting, week 1", "Weekly Site Meeting Simpang Kara", "pdf",
     ["WEEKLY SITE MEETING — WEEK 1", "Mobilisation of heavy equipment and re-survey (uitzet) completed.",
      "Planned progress 2.1% — actual 2.4%. Action: submit shop drawings for culverts."]),
    ("Notulen Rapat Lapangan Mingguan ke-2 Simpang Kara", "WSM-02/014/2026", D(2026, 3, 16), "MEETING", "PU-JLN-2026-001", "notulen, rapat mingguan, minggu 2", "Weekly Site Meeting Simpang Kara", "docx",
     ["NOTULEN RAPAT LAPANGAN MINGGUAN KE-2", "Galian badan jalan STA 0+000 - 0+400.",
      "Progres rencana 4,8% - realisasi 4,5%. Tindak lanjut: tambah 1 unit dump truck."]),
    ("Design Review Meeting — Sei Ladi Bridge", "DRM-021/2026", D(2026, 4, 28), "MEETING", "PU-JBT-2026-002", "minutes, design review, bridge", "", "pdf",
     ["DESIGN REVIEW MEETING MINUTES — SEI LADI BRIDGE", "New abutment shifted 7.5 m from the old abutment of bridge BM-0458.",
      "Old pile positions must be verified against the 2011 as-built drawings before driving new piles."]),
    ("Notulen Rapat Evaluasi Drainase Ahmad Yani", "NOT-1120/2019", D(2019, 12, 12), "MEETING", "PU-DRN-2019-006", "notulen, evaluasi, drainase", "", "txt",
     ["NOTULEN RAPAT EVALUASI", "Saluran DR-1120 selesai 850 m, sisa 620 m diusulkan untuk tahun anggaran berikutnya.",
      "Genangan di simpang Ahmad Yani turun dari 60 cm menjadi 10 cm."]),
    ("Handover Meeting Minutes — District Office Rehabilitation", "HMM-007/2025", D(2025, 10, 30), "MEETING", "PU-GDG-2025-007", "minutes, handover", "", "docx",
     ["HANDOVER MEETING MINUTES (PHO)", "Rehabilitation of the building built under contract 3307/KTR/CK/2015.",
      "Works accepted 100%. Maintenance period 180 days until 28 April 2026."]),
    ("Notulen Rapat Evaluasi Kinerja Bidang", "NOT-08/SEKR/2021", D(2021, 8, 30), "MEETING", "", "notulen, evaluasi kinerja", "", "pdf",
     ["NOTULEN RAPAT EVALUASI KINERJA", "Capaian indikator kinerja bidang semester I sebesar 87%.",
      "Tindak lanjut: percepatan pengadaan paket fisik."]),
    ("Annual Planning Meeting Minutes — Road Division 2024", "APM/BM/2024", D(2024, 2, 1), "MEETING", "", "minutes, annual planning, strategy", "", "pdf",
     ["ANNUAL PLANNING MEETING — ROAD DIVISION", "Target: 90% of city roads in stable condition by end of period.",
      "Strategy: routine preservation, reconstruction of critical sections, digitisation of technical archives."]),
]

assert len(DOCS) == 50, len(DOCS)

# --------------------------------------------------------------------------- pembuat file


def _ascii(s: str) -> str:
    return (s.replace("–", "-").replace("—", "-").replace("’", "'").replace("“", '"').replace("”", '"')
            .encode("latin-1", "replace").decode("latin-1"))


def make_pdf(lines: list[str]) -> bytes:
    """PDF sederhana (Helvetica) — teksnya bisa dibaca pypdf untuk pencarian isi file."""
    def esc(t: str) -> str:
        return _ascii(t).replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    body = ["BT", "/F1 11 Tf", "15 TL", "50 790 Td"]
    for i, line in enumerate(lines):
        if i == 3:
            body.append("/F1 12 Tf")
        body.append(f"({esc(line)}) Tj T*")
    body.append("ET")
    stream = "\n".join(body).encode("latin-1")
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    out = io.BytesIO()
    out.write(b"%PDF-1.4\n")
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(out.tell())
        out.write(f"{i} 0 obj\n".encode() + o + b"\nendobj\n")
    xref = out.tell()
    out.write(f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode())
    for off in offsets:
        out.write(f"{off:010d} 00000 n \n".encode())
    out.write(f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
    return out.getvalue()


def make_docx(lines: list[str]) -> bytes:
    """Dokumen Word (.docx) minimal yang bisa dibuka Microsoft Word."""
    from xml.sax.saxutils import escape
    paras = "".join(
        f'<w:p><w:r>{"<w:rPr><w:b/></w:rPr>" if i in (0, 1, 4) else ""}<w:t xml:space="preserve">{escape(t)}</w:t></w:r></w:p>'
        for i, t in enumerate(lines)
    )
    document = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
                f'{paras}<w:sectPr/></w:body></w:document>')
    content_types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                     '<Default Extension="xml" ContentType="application/xml"/>'
                     '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
                     '</Types>')
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            '</Relationships>')
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types)
        z.writestr("_rels/.rels", rels)
        z.writestr("word/document.xml", document)
    return buf.getvalue()


def make_xlsx(title: str, header: list[str], rows: list[list]) -> bytes:
    from openpyxl import Workbook
    from openpyxl.styles import Font

    wb = Workbook()
    ws = wb.active
    ws.title = "Data"
    for line in HEADER[:2]:
        ws.append([line])
    ws.append([title])
    ws.append([])
    ws.append(header)
    for c in ws[ws.max_row]:
        c.font = Font(bold=True)
    for r in rows:
        ws.append(r)
    for col, width in zip("ABCDE", (14, 48, 18, 18, 12)):
        ws.column_dimensions[col].width = width
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def make_png(seed: int, w: int = 640, h: int = 400) -> bytes:
    """'Foto' contoh: langit, tanah, dan jalan (gambar sederhana tanpa library tambahan)."""
    raw = bytearray()
    sky = (110 + seed * 7 % 60, 160 + seed * 3 % 50, 220)
    for y in range(h):
        raw.append(0)
        for x in range(w):
            if y < h * 0.45:
                c = (sky[0] + y // 8, sky[1] + y // 10, min(255, sky[2]))
            elif abs((x - w / 2) - (y - h * 0.45) * 0.0) < (y - h * 0.45) * 1.4 + 20:
                stripe = (y // 18) % 2 == 0 and abs(x - w / 2) < 4
                c = (250, 250, 250) if stripe else (70, 72, 78)
            else:
                c = (90 + seed * 5 % 40, 140, 70)
            raw.extend(bytes(c))

    def chunk(t: bytes, d: bytes) -> bytes:
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def _safe_name(title: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", title).strip("_")[:80]


def build_file(i: int, title: str, number: str, d: date, project: Project | None, kind: str, content: list) -> tuple[str, bytes]:
    name = f"{_safe_name(title)}.{kind}"
    meta = [f"Nomor : {number or '-'}", f"Tanggal : {d.strftime('%d-%m-%Y')}"]
    if project:
        meta.append(f"Paket : {project.code} - {project.name}")
    if kind == "pdf":
        return name, make_pdf(HEADER + meta + [""] + content)
    if kind == "docx":
        return name, make_docx(HEADER + meta + [""] + content)
    if kind == "txt":
        return name, ("\r\n".join(HEADER + meta + [""] + content)).encode("utf-8")
    if kind == "xlsx":
        return name, make_xlsx(title, content[0], content[1:])
    if kind == "png":
        return name, make_png(i)
    raise ValueError(kind)


# --------------------------------------------------------------------------- seeding


def seed(with_documents: bool = True, verbose: bool = True) -> dict:
    """Isi proyek, akun staf, dan 50 dokumen contoh. Aman diulang (yang sudah ada dilewati)."""
    from .main import index_document  # import di sini supaya tidak melingkar

    added = {"projects": 0, "users": 0, "documents": 0}
    with SessionLocal() as db:
        for p in PROJECTS:
            if not db.scalar(select(Project).where(Project.code == p["code"])):
                db.add(Project(**p))
                added["projects"] += 1
        for u in USERS:
            if not db.scalar(select(User).where(User.username == u["username"])):
                data = dict(u)
                pw = data.pop("password")
                db.add(User(active=True, **data, **make_password_fields(pw)))
                added["users"] += 1
        db.commit()

        if not with_documents:
            return added

        projects = {p.code: p for p in db.scalars(select(Project)).all()}
        admin = db.scalar(select(User.username).where(User.role == "admin").order_by(User.id)) or "admin"
        uploaders = [admin, "budi", "sari"]
        new_ids = []
        for i, (title, number, d, cat, pcode, tags, series, kind, content) in enumerate(DOCS, 1):
            cid = f"demo-{i:02d}"
            if db.scalar(select(Document.id).where(Document.client_id == cid)):
                continue
            proj = projects.get(pcode) if pcode else None
            fname, data = build_file(i, title, number, d, proj, kind, content)
            created = datetime(d.year, d.month, d.day, 9, 0) + timedelta(minutes=i * 7)
            folder = config.STORAGE_DIR / f"{created:%Y}" / f"{created:%m}"
            folder.mkdir(parents=True, exist_ok=True)
            target = folder / f"{cid}_{fname}"
            target.write_bytes(data)
            doc = Document(
                client_id=cid, title=title, doc_number=number, doc_date=d, category=cat,
                project_id=proj.id if proj else None,
                description=(content[0] if content and isinstance(content[0], str) else f"Data contoh {title}")[:500],
                tags=tags, series=series, file_name=fname,
                stored_path=str(target.relative_to(config.STORAGE_DIR)), file_size=len(data),
                mime={"pdf": "application/pdf", "txt": "text/plain", "png": "image/png",
                      "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                      "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}[kind],
                sha256=hashlib.sha256(data).hexdigest(), uploaded_by=uploaders[i % 3],
                created_at=created, uploaded_at=created + timedelta(minutes=3), content_status="pending",
            )
            db.add(doc)
            db.flush()
            new_ids.append(doc.id)
            added["documents"] += 1
        db.commit()

    for doc_id in new_ids:  # baca isi file sekarang supaya pencarian isi langsung jalan
        try:
            index_document(doc_id)
        except Exception as e:  # pragma: no cover
            print(f"[demo] gagal index #{doc_id}: {e}")
    if verbose:
        print(f"[demo] data contoh ditambahkan: {added['projects']} proyek, {added['users']} akun staf, {added['documents']} dokumen")
    return added


def documents_empty() -> bool:
    with SessionLocal() as db:
        return (db.scalar(select(func.count()).select_from(Document)) or 0) == 0
