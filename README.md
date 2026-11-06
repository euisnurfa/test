# Inggris Santai — Website Kelas + Supabase

Panduan ini ditulis pelan-pelan, untuk yang belum pernah pakai Supabase atau Vercel.
Ikuti urut dari atas. Total waktu: sekitar 30–45 menit.

---

## 0. Gambaran besarnya dulu

Bayangkan website ini seperti **toko**:

| Bagian | Diibaratkan | Dipakai untuk |
|---|---|---|
| **File HTML** (folder ini) | Etalase toko | Tampilan yang dilihat pembeli |
| **Cloudflare Pages / Vercel** | Ruko tempat etalase dipajang | Supaya website bisa dibuka lewat internet |
| **Supabase** | Gudang + satpam | Menyimpan akun pembeli, pesanan, daftar kelas, link video. Satpamnya hanya memberi link video ke akun yang langganannya aktif |

Alurnya:

```
Pembeli buka website → daftar akun → pilih paket → bayar QRIS/transfer
      → klik "Konfirmasi via WhatsApp"  → pesan masuk ke WA kamu
Kamu cek mutasi → buka halaman Admin → klik "Setujui"
      → Supabase otomatis mengaktifkan akun pembeli
      → halaman pembeli berubah jadi "LUNAS" dan semua video terbuka
```

Kenapa video benar-benar terkunci? Link video **tidak ditulis di file HTML**. Link itu disimpan di
Supabase, dan Supabase hanya mau memberikannya kepada akun yang `member_until`-nya (masa aktif) belum lewat.
Orang yang membuka "View Source" tidak akan menemukan link videonya.

Isi folder:

```
index.html     ← halaman utama + pilih paket
bayar.html     ← halaman pembayaran (QRIS / rekening, status, batalkan)
masuk.html     ← masuk / daftar / lupa password
kelas.html     ← area member: daftar kelas + pemutar video
admin.html     ← khusus kamu: setujui pembayaran, kelola member & video
config.js      ← PENGATURAN (yang perlu kamu isi)
assets/        ← tampilan & fungsi bersama (tidak perlu diubah)
supabase/schema.sql ← "cetak biru" gudang, dijalankan sekali di Supabase
```

---

## 1. Buat "gudang": project Supabase

1. Buka **https://supabase.com** → klik **Start your project** → masuk pakai akun GitHub kamu.
2. Klik **New project**.
   - **Name**: `inggris-santai`
   - **Database Password**: klik *Generate*, lalu **simpan** di catatan (jarang dipakai, tapi penting).
   - **Region**: pilih yang paling dekat, misalnya **Southeast Asia (Singapore)**.
3. Klik **Create new project**, tunggu 1–2 menit sampai selesai.

## 2. Pasang "cetak biru" gudang (schema.sql)

1. Di menu kiri Supabase, klik **SQL Editor**.
2. Klik **New query**.
3. Buka file `supabase/schema.sql` dengan Notepad, **salin semua isinya**, tempel ke kotak SQL Editor.
4. Klik **Run** (atau Ctrl+Enter). Kalau muncul *Success*, berarti tabel, satpam, dan tempat file sudah jadi.

Cek: klik **Table Editor** di menu kiri — harus ada tabel `plans`, `courses`, `lessons`, `orders`, dan lainnya.
Tabel `plans` sudah berisi 3 paket contoh (1, 3, 12 bulan).

## 3. Atur pendaftaran akun

Di menu kiri: **Authentication** → **Sign In / Providers** → **Email**.

- Matikan **Confirm email** → **Save**.
  Kalau dibiarkan menyala, setiap pembeli baru harus klik link di email dulu sebelum bisa bayar.
  Pengiriman email bawaan Supabase juga dibatasi jumlahnya, jadi untuk awal lebih lancar dimatikan.
  (Website tetap bisa jalan kalau kamu memilih menyalakannya.)

## 4. Sambungkan website ke Supabase (config.js)

1. Di Supabase, klik tombol **Connect** di bagian atas (atau **Project Settings → API**).
2. Salin dua hal:
   - **Project URL** — bentuknya `https://xxxxxxxx.supabase.co`
   - **anon public key** atau **Publishable key** — teks panjang
3. Buka `config.js` dengan Notepad, tempel:
   ```js
   supabaseUrl: "https://xxxxxxxx.supabase.co",
   supabaseAnonKey: "teks-panjang-tadi",
   ```
4. Isi juga `whatsapp` (format `628xxxxxxxxxx`), nomor rekening, dan nama merchant QRIS. Simpan.
5. Siapkan gambar QRIS kamu, beri nama **`qris.png`**, taruh di folder yang sama dengan `index.html`.

> **Aman nggak kunci itu terlihat orang?** Kunci *anon / publishable* memang dirancang untuk ditaruh
> di website. Yang menjaga keamanan adalah "satpam" dari schema.sql. Yang **tidak boleh** kamu tempel
> di mana pun adalah **service_role / secret key**.

## 5. Simpan di GitHub

1. Buat repository baru di GitHub (boleh **Private**), misalnya `inggris-santai-web`.
2. Klik **uploading an existing file** → buka folder ini → blok semua isinya → tarik ke GitHub → **Commit changes**.

## 6. Online-kan website ("ruko")

Pilih **salah satu**.

### Pilihan A — Cloudflare Pages (gratis, boleh untuk jualan) ✅ disarankan

1. Buka **https://dash.cloudflare.com** → daftar/masuk.
2. Menu **Workers & Pages** → **Create** → pilih tab **Pages** → **Connect to Git**.
3. Sambungkan akun GitHub, pilih repo `inggris-santai-web`.
4. Pengaturan build:
   - Framework preset: **None**
   - Build command: **(kosongkan)**
   - Build output directory: **/** (atau kosongkan)
5. Klik **Save and Deploy**. Setelah selesai, kamu dapat alamat seperti `inggris-santai-web.pages.dev`.

Setiap kali kamu mengubah file di GitHub, Cloudflare otomatis memperbarui website.
(Alternatif tanpa GitHub: di langkah 2 pilih **Upload assets**, lalu tarik folder ini langsung.)

### Pilihan B — Vercel

1. Buka **https://vercel.com** → masuk pakai GitHub.
2. **Add New… → Project** → pilih repo `inggris-santai-web` → **Import**.
3. Framework Preset: **Other** → klik **Deploy**.
4. Kamu dapat alamat seperti `inggris-santai-web.vercel.app`.

> ⚠️ Paket gratis Vercel (**Hobby**) hanya untuk penggunaan pribadi non-komersial.
> Karena website ini untuk berjualan, di Vercel kamu perlu paket **Pro** (berbayar).
> Kodenya sama persis di Cloudflare Pages, jadi kalau mau gratis pakai Pilihan A.

### Setelah online — beri tahu Supabase alamat website kamu

Supabase → **Authentication → URL Configuration**:
- **Site URL**: isi alamat website kamu (misal `https://inggris-santai-web.pages.dev`)
- **Redirect URLs**: tambahkan `https://inggris-santai-web.pages.dev/**`

Ini dipakai untuk link "lupa password" di email.

## 7. Jadikan akunmu admin

1. Buka website kamu → **Masuk** → **Daftar gratis** → buat akun dengan email kamu sendiri.
2. Di Supabase → **SQL Editor** → **New query**, jalankan (ganti emailnya):
   ```sql
   update public.profiles set is_admin = true where email = 'emailkamu@gmail.com';
   ```
3. Muat ulang website — di menu atas sekarang muncul **Admin**.

## 8. Masukkan video & atur kelas

Buka **Admin → Materi & Video**.

- **Tambah / edit pelajaran**: isi judul, pilih kelas, durasi, lalu masukkan video.
- **Video** — dua cara:
  1. **Link** YouTube, Vimeo, atau Google Drive (disarankan untuk video panjang).
     - YouTube: unggah video dengan visibilitas **Unlisted** (bukan Public), lalu salin link-nya.
     - Vimeo: lebih aman — di pengaturan video Vimeo bisa dibatasi agar hanya bisa diputar di domain website kamu.
     - Link hanya diberikan ke member aktif, tapi member yang nakal tetap bisa menyalin link YouTube/Drive dan membagikannya. Itu risiko semua cara berbasis link.
  2. **Unggah file** langsung ke Supabase — paling aman (link-nya sementara dan khusus member),
     tapi kuota Supabase gratis kecil, jadi cocok untuk video pendek dan PDF.
- **Modul PDF**: unggah file PDF — tersimpan aman di Supabase, hanya member yang bisa mengunduh.
- Centang **Gratis** untuk video contoh yang boleh ditonton siapa saja (tetap harus punya akun).
- **Harga paket** diubah di Supabase → **Table Editor → plans** (kolom `harga`, `harga_coret`, `catatan`).

## 9. Kegiatan harian: menyetujui pembayaran

1. Pembeli mengirim konfirmasi ke WhatsApp kamu (berisi nomor pesanan dan nominal unik, misal **Rp 950.359**).
2. Cek mutasi rekening / riwayat QRIS kamu — cari nominal yang **persis sama**.
3. Buka **Admin → Pesanan** (filter *Perlu dicek*) → klik **✓ Setujui** dua kali (konfirmasi).
4. Selesai. Akun pembeli aktif otomatis. Klik **Kabari via WA** untuk mengirim pesan "pembayaran diterima".

Tab **Member** dipakai untuk menambah 30 hari secara manual (misal bonus) atau mencabut akses.

---

## Batasan yang perlu kamu tahu

- **Supabase gratis "tertidur" kalau tidak ada aktivitas selama 7 hari.** Selama ada pengunjung, tidak masalah.
  Kalau tertidur, buka dashboard Supabase dan klik *Restore*. Kalau sudah ramai, pertimbangkan paket Pro Supabase.
- **Penyimpanan file Supabase gratis kecil** (sekitar 1 GB, dengan batas kuota unduhan bulanan). Untuk banyak video, pakai link YouTube/Vimeo.
- **Pembayaran masih dicek manual.** Kalau nanti mau otomatis (QRIS/VA dinamis yang langsung lunas), butuh payment gateway
  seperti Midtrans/Xendit plus satu fungsi server kecil (bisa memakai Supabase Edge Functions). Struktur database ini sudah siap untuk itu.
- Cantumkan kebijakan privasi singkat di website, karena kamu menyimpan nama, email, dan nomor WA pembeli.

## Kalau ada masalah

| Gejala | Penyebab paling sering |
|---|---|
| Muncul tulisan kuning "Website belum tersambung ke database" | `supabaseUrl` / `supabaseAnonKey` di `config.js` belum diisi atau salah salin |
| Paket & kelas tidak muncul | `schema.sql` belum dijalankan, atau ada error saat dijalankan |
| Menu Admin tidak muncul | Langkah 7 belum dijalankan, atau email-nya salah ketik |
| Pembeli diminta cek email terus | "Confirm email" masih menyala (langkah 3) |
| Gambar QRIS tidak muncul | File `qris.png` belum diunggah / namanya beda dengan di `config.js` |
