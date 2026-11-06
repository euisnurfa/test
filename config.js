/* =============================================================================
   PENGATURAN WEBSITE — cukup ubah file ini
   =============================================================================

   1) supabaseUrl & supabaseAnonKey
      Ambil di Supabase Dashboard → Project Settings → API (atau "Connect").
      - "Project URL"             → tempel ke supabaseUrl
      - "anon public" / "publishable" key → tempel ke supabaseAnonKey
      Kunci "anon/publishable" ini MEMANG boleh terlihat publik — keamanannya dijaga
      oleh aturan di database (schema.sql). JANGAN PERNAH menempel "service_role"
      atau "secret" key di sini.

   2) whatsapp  : nomor WA kamu (628xxxxxxxxxx). Konfirmasi pembayaran masuk ke sini.
   3) qrisGambar: nama file gambar QRIS kamu (unggah ke folder yang sama dengan file ini).
   4) rekening  : rekening untuk transfer bank. Hapus yang tidak dipakai.

   Harga paket dan daftar kelas TIDAK diatur di sini, tetapi di Supabase
   (Table Editor → plans / courses / lessons), atau lewat halaman admin.html.
   ============================================================================= */
window.CONFIG = {
  supabaseUrl: "https://emnxwfmngtcbuebvfoye.supabase.co/",        // contoh: "https://abcdefghijkl.supabase.co"
  supabaseAnonKey: "sb_publishable_YV3X96VZLEPhXXn6EAqVfA_5ixWox4v",    // contoh: "eyJhbGciOi..." atau "sb_publishable_..."

  brand: "Inggris Santai",
  whatsapp: "081389731727",           // contoh: "6281234567890"
  email: "euisnurfatimah9a@gmail.com",

  qrisGambar: "qris.png",
  qrisNama: "Euis Nur Fatimah",           // nama merchant yang tertulis di QRIS kamu

  rekening: [
    { kode: "mandiri", nama: "Transfer Bank Mandiri", nomor: "", atasNama: "" },
    { kode: "bni",     nama: "Transfer Bank BNI",     nomor: "", atasNama: "" },
    // { kode: "bca",  nama: "Transfer Bank BCA",     nomor: "", atasNama: "" },
    // { kode: "bri",  nama: "Transfer Bank BRI",     nomor: "", atasNama: "" },
  ],
};
