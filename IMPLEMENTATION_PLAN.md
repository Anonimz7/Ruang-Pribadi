# Rencana Implementasi: Ratchet Mechanism (Paku & Suara)

## Tujuan
Menambahkan realisme pada fitur gacha keberuntungan dan rolling YES/NO dengan mensimulasikan mekanisme roda roulette fisik:
1.  **Visual Paku (Pegs):** Menambahkan objek visual di sekeliling roda.
2.  **Animasi Jarum (Flapper):** Jarum bergetar/memantul saat mengenai paku.
3.  **Efek Suara (SFX):** Suara "tik-tik" yang frekuensinya menyesuaikan kecepatan putaran roda.

## File Target
1.  `lib/gacha_luck/gacha_screen.dart`
2.  `lib/rolling/rolling_screen.dart` (atau lokasi file rolling_screen.dart yang sebenarnya)

---

## Daftar Tugas (Task List)

### Fase 1: Persiapan Aset & Konfigurasi
- [ ] **Task 1.1:** Menyiapkan file suara (`tick_sound.mp3` atau `.wav`).
    - *Catatan:* Jika aset belum ada, buat placeholder atau gunakan URL aset publik sementara.
- [ ] **Task 1.2:** Menambahkan dependency `audioplayers` atau menggunakan `AudioCache` dari Flutter jika sudah tersedia di project.
- [ ] **Task 1.3:** Membuat konstanta konfigurasi (jumlah paku, jarak antar paku, amplitudo getaran jarum).

### Fase 2: Logika Inti (Physics & Detection)
- [ ] **Task 2.1:** Menghitung posisi sudut setiap paku berdasarkan jumlah sektor.
    - Rumus: `pegAngle = (360 / totalPegs) * index`.
- [ ] **Task 2.2:** Membuat logika deteksi tabrakan (Collision Detection).
    - Mendeteksi ketika sudut roda saat ini melewati posisi sudut paku berikutnya relatif terhadap posisi jarum tetap (biasanya di atas/kanan).
- [ ] **Task 2.3:** Menghubungkan deteksi tabrakan dengan pemicu suara (Trigger Sound).
    - Mencegah suara berbunyi berulang kali untuk paku yang sama (debouncing).
- [ ] **Task 2.4:** Menghubungkan deteksi tabrakan dengan animasi getaran jarum.
    - Menggunakan `AnimationController` atau `Tween` untuk rotasi kecil pada jarum saat terjadi tabrakan.

### Fase 3: Implementasi pada `gacha_screen.dart`
- [ ] **Task 3.1:** Menambahkan widget visual untuk paku (misal: `Container` bulat kecil atau `CustomPainter`) di sekeliling canvas roda.
- [ ] **Task 3.2:** Memodifikasi widget jarum agar bisa menerima offset rotasi (untuk efek memantul).
- [ ] **Task 3.3:** Mengintegrasikan logika Fase 2 ke dalam loop animasi `_spin()`.
- [ ] **Task 3.4:** Testing: Memastikan suara dan getaran sinkron dengan kecepatan putaran (cepat = tik cepat, lambat = tik lambat).

### Fase 4: Implementasi pada `rolling_screen.dart`
- [ ] **Task 4.1:** Menerapkan visual paku pada roda YES/NO.
- [ ] **Task 4.2:** Menerapkan logika deteksi dan suara yang sama seperti di Gacha Screen.
- [ ] **Task 4.3:** Menyesuaikan parameter jika ukuran roda berbeda (jari-jari, jumlah paku).

### Fase 5: Verifikasi & Refinement
- [ ] **Task 5.1:** Uji coba di perangkat fisik/emulator dengan volume nyala.
- [ ] **Task 5.2:** Memastikan tidak ada lag saat banyak suara dipicu berturut-turut.
- [ ] **Task 5.3:** Memastikan hasil akhir (sektor yang terpilih) tetap akurat dan tidak terganggu oleh penambahan logika suara/animasi ini.

---

## Catatan Teknis
- **Posisi Jarum:** Biasanya statis di jam 12 (0 derajat) atau jam 3 (90 derajat). Logika deteksi harus menyesuaikan posisi tetap ini.
- **Arah Putaran:** Jika roda berputar searah jarum jam (CW), maka paku akan "menyapu" jarum. Deteksi harus menghitung kapan paku melewati titik referensi jarum.
- **Performa:** Hindari alokasi memori baru di dalam loop animasi (misal: jangan buat instance player suara baru tiap tick, gunakan satu instance dan reset/play).

## Status Saat Ini
- [x] Analisis masalah sebelumnya (Bug akurasi).
- [x] Perbaikan bug akurasi.
- [ ] Pembuatan rencana ini.
- [ ] Mulai implementasi Fase 1.
