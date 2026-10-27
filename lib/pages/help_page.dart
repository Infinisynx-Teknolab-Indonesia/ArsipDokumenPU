import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Panduan singkat pemakaian untuk staf & admin.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppState.instance.session?.isAdmin ?? false;
    final sections = <(IconData, String, List<String>, String?)>[
      (Icons.upload_file_rounded, 'Mengunggah dokumen', [
        'Buka menu Unggah Dokumen.',
        'Pilih proyek/paket, kategori (mis. Laporan Mingguan, Foto Progres, BA PHO), dan tanggal dokumen.',
        'Isi judul, nomor dokumen/surat, tag, dan keterangan seperlunya.',
        'Klik area "Klik untuk memilih file" untuk memilih satu atau banyak file (PDF, Word, Excel, TXT, foto, DWG, ZIP/RAR).',
        'Klik "Simpan ke Arsip". Proyek, kategori, dan tanggal tetap terisi supaya input berikutnya lebih cepat.',
      ], 'upload'),
      (Icons.wifi_off_rounded, 'Kalau internet / server mati', [
        'Tetap bisa login (untuk akun yang pernah tersinkron) dan tetap bisa menyimpan dokumen.',
        'Dokumen disimpan aman di PC ini dengan status "Menunggu upload".',
        'Aplikasi mengecek server setiap 10 detik dan mengunggah otomatis begitu tersambung. Tidak perlu input ulang.',
        'Jangan menghapus folder %APPDATA%\\ArsipDokumenPU selama masih ada dokumen yang belum terupload.',
      ], null),
      (Icons.assignment_ind_rounded, 'Melihat dokumen yang saya input', [
        'Menu Dokumen Saya berisi semua dokumen yang Anda input, termasuk yang belum terupload.',
        'Gunakan tab Hari ini / Menunggu upload / Gagal / Tersimpan di server untuk memeriksa status.',
        'Status Gagal artinya ditolak server (mis. file terlalu besar). Buka dokumennya untuk melihat alasan, lalu klik "Upload ulang".',
        'Dokumen bisa diekspor ke Excel (CSV) sebagai laporan kerja.',
      ], 'mydocs'),
      (Icons.search_rounded, 'Mencari arsip', [
        'Menu Arsip Dokumen berisi seluruh arsip (milik semua pengguna).',
        'Ketik kata kunci: judul, nomor dokumen, tag, keterangan, nama file, kode paket, atau nama pengunggah.',
        'Saring berdasarkan proyek, kategori, tahun, jenis file, dan status.',
        'Klik dokumen untuk pratinjau, buka dengan aplikasi, simpan salinan, atau lihat di folder.',
      ], 'docs'),
      (Icons.rate_review_rounded, 'Memperbaiki dokumen yang salah', [
        'Dokumen yang belum terupload bisa langsung diedit dari Dokumen Saya.',
        'Dokumen yang sudah diarsipkan tidak bisa diubah langsung oleh staf: buka dokumennya lalu klik "Ajukan Perubahan".',
        'Ubah data yang salah dan/atau pilih file pengganti, tulis alasannya, lalu kirim ke admin.',
        'Pantau statusnya di menu Permintaan Edit (Menunggu / Disetujui / Ditolak beserta catatan admin).',
        'Kalau file diganti, file lama tetap tersimpan di tab Riwayat Versi.',
      ], 'requests'),
      (Icons.manage_search_rounded, 'Pencarian pintar & dokumen terkait', [
        'Kata kunci dicari juga di ISI file PDF, Word (.docx), Excel (.xlsx), dan TXT, misalnya kode 544 yang tertulis di dalam PDF.',
        'Kamus Pencarian menghubungkan istilah dengan kode/kata lain, misalnya mencari "pengeluaran" juga menemukan dokumen berisi "544" atau "belanja".',
        'Kode bertitik cocok dengan atau tanpa titik: 5.2.2.01 = 52201.',
        'Di setiap hasil tertulis bagian yang cocok, misalnya "isi file memuat 544".',
        'Seri dokumen: isi "Seri / Kelompok Dokumen" yang sama (mis. "Dokumen 1") untuk Formula A 2000, Formula B 2002, dan Formula C. Judul yang sama dan hanya berbeda huruf/versi juga dikenali otomatis.',
        'Mencari "Formula C" akan menampilkan Formula C beserta seri sebelumnya (A 2000, B 2002) tepat di bawah hasilnya.',
        'Buka dokumen, lalu lihat tab "Terkait": dokumen lain (termasuk dari tahun-tahun lampau) yang memuat kode/nomor yang sama, satu proyek, atau tag yang sama, dikelompokkan per tahun.',
        'Pencarian isi file juga bekerja offline untuk dokumen yang sudah tersinkron.',
      ], 'terms'),
      (Icons.engineering_rounded, 'Proyek / paket pekerjaan', [
        'Menu Proyek berisi data paket: kode, lokasi, TA, nilai kontrak, kontraktor, konsultan, PPK, dan progres.',
        'Klik "Lihat dokumen" untuk semua dokumen satu proyek, atau "Unggah" untuk langsung menginput dokumen proyek tersebut.',
        if (isAdmin) 'Admin dapat menambah, mengubah, dan menghapus proyek (butuh koneksi server).',
      ], 'projects'),
      (Icons.lock_reset_rounded, 'Akun & password', [
        'Ganti password di menu Profil Saya (butuh koneksi server).',
        'Lupa password: minta admin untuk me-reset di menu Staf & Admin.',
        'Logout untuk berganti pengguna. Keluar Aplikasi untuk menutup aplikasi (tombol di sidebar bawah).',
      ], 'profile'),
      (Icons.keyboard_rounded, 'Tampilan', [
        'Aplikasi berjalan full screen. Tekan F11 untuk keluar/masuk full screen.',
        'Tombol Keluar Aplikasi ada di bagian bawah sidebar dan di Profil Saya.',
      ], null),
      if (isAdmin)
        (Icons.admin_panel_settings_rounded, 'Khusus admin', [
          'Server API: atur alamat server (FastAPI / C# .NET). Sebelum terhubung, hanya akun administrator/administrator yang bisa login.',
          'Staf & Admin: tambah akun, reset password, nonaktifkan staf yang sudah tidak bertugas (otomatis terblokir di semua PC).',
          'Log Aktivitas: riwayat login, unggah, unduh, ubah, dan hapus beserta alamat IP.',
          'Permintaan Edit: bandingkan data lama vs usulan, lihat file usulan, lalu Setujui & Terapkan atau Tolak dengan alasan.',
          'Kamus Pencarian: tambah istilah dan kode instansi, misalnya pengeluaran = 544. "Baca ulang isi file" dipakai bila hasil pencarian isi kurang lengkap.',
          'Penyimpanan & Info: bersihkan cache unduhan bila disk PC penuh.',
        ], 'users'),
    ];

    return PageBody(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in sections) ...[
                Panel(
                  title: s.$2,
                  icon: s.$1,
                  trailing: s.$4 == null
                      ? null
                      : TextButton.icon(
                          onPressed: () => Nav.go(s.$4!),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Buka menu'),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < s.$3.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: YmColors.accentPurple.withOpacity(0.12), shape: BoxShape.circle),
                                child: Text('${i + 1}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: YmColors.accentPurple)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.$3[i], style: YmTextStyles.chatText.copyWith(fontSize: 13, height: 1.4))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
