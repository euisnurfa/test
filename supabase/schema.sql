-- =============================================================================
--  INGGRIS SANTAI — SKEMA DATABASE SUPABASE
--  Cara pakai: Supabase Dashboard → SQL Editor → New query → tempel SEMUA isi file
--  ini → klik "Run". Cukup dijalankan sekali.
--
--  Isinya:
--    1. Tabel  : paket, profil member, pesanan, kelas, pelajaran, link video
--    2. "Satpam" (Row Level Security): siapa boleh melihat / mengubah apa
--    3. Fungsi : buat pesanan, konfirmasi, batalkan, setujui (admin)
--    4. Tempat file (Storage) "materi" untuk PDF/video, terkunci untuk member
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------------

-- Paket langganan (harga diambil dari sini, bukan dari browser pembeli)
create table if not exists public.plans (
  id          text primary key,
  nama        text not null,
  bulan       int  not null check (bulan > 0),
  harga       int  not null check (harga > 0),
  harga_coret int,
  catatan     text,
  unggulan    boolean not null default false,
  urutan      int not null default 0,
  aktif       boolean not null default true
);

-- Profil setiap akun (dibuat otomatis saat orang mendaftar)
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  nama         text,
  wa           text,
  email        text,
  member_until timestamptz,                 -- langganan aktif sampai kapan
  is_admin     boolean not null default false,
  created_at   timestamptz not null default now()
);

-- Pesanan / tagihan
create table if not exists public.orders (
  id         text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  plan_id    text not null references public.plans (id),
  bulan      int  not null,
  harga      int  not null,
  kode_unik  int  not null default 0,
  total      int  not null,
  metode     text not null,
  status     text not null default 'pending'
             check (status in ('pending', 'sent', 'paid', 'cancelled', 'expired')),
  batas      timestamptz not null,
  created_at timestamptz not null default now(),
  paid_at    timestamptz
);
create index if not exists orders_user_idx   on public.orders (user_id);
create index if not exists orders_status_idx on public.orders (status);

-- Kelas & pelajaran (judulnya boleh dilihat semua orang)
create table if not exists public.courses (
  id      bigint generated always as identity primary key,
  judul   text not null,
  level   text,
  ringkas text,
  warna   text not null default '#ff6b4a',
  urutan  int  not null default 0
);

create table if not exists public.lessons (
  id        bigint generated always as identity primary key,
  course_id bigint not null references public.courses (id) on delete cascade,
  judul     text not null,
  durasi    text,
  urutan    int  not null default 0,
  gratis    boolean not null default false
);
create index if not exists lessons_course_idx on public.lessons (course_id);

-- Link video & file PDF — INI yang dikunci, hanya member aktif yang bisa membaca
create table if not exists public.lesson_media (
  lesson_id bigint primary key references public.lessons (id) on delete cascade,
  video     text,   -- link YouTube/Vimeo, ATAU nama file di Storage "materi"
  pdf_path  text    -- nama file PDF di Storage "materi"
);

-- ---------------------------------------------------------------------------
-- 2. FUNGSI BANTU
-- ---------------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select member_until > now() from public.profiles where id = auth.uid()), false)
$$;

-- Buat profil otomatis saat ada akun baru
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nama, wa, email)
  values (new.id,
          left(coalesce(new.raw_user_meta_data ->> 'nama', ''), 100),
          left(regexp_replace(coalesce(new.raw_user_meta_data ->> 'wa', ''), '[^0-9]', '', 'g'), 20),
          new.email)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 3. "SATPAM" — ROW LEVEL SECURITY
--    Tanpa aturan di bawah, tidak ada yang boleh membaca/mengubah apa pun.
-- ---------------------------------------------------------------------------
alter table public.plans        enable row level security;
alter table public.profiles     enable row level security;
alter table public.orders       enable row level security;
alter table public.courses      enable row level security;
alter table public.lessons      enable row level security;
alter table public.lesson_media enable row level security;

-- Paket: semua orang boleh melihat paket aktif; admin boleh mengubah
drop policy if exists "plans dibaca semua" on public.plans;
create policy "plans dibaca semua" on public.plans for select using (aktif or public.is_admin());
drop policy if exists "plans diubah admin" on public.plans;
create policy "plans diubah admin" on public.plans for all using (public.is_admin()) with check (public.is_admin());

-- Profil: hanya pemiliknya sendiri (dan admin) yang boleh melihat.
-- Tidak ada yang boleh mengubah langsung — perubahan masa aktif hanya lewat fungsi admin.
drop policy if exists "profil sendiri" on public.profiles;
create policy "profil sendiri" on public.profiles for select using (id = auth.uid() or public.is_admin());

-- Pesanan: pembeli hanya melihat pesanannya sendiri; admin melihat semua.
-- Membuat/mengubah pesanan hanya lewat fungsi di bawah.
drop policy if exists "pesanan sendiri" on public.orders;
create policy "pesanan sendiri" on public.orders for select using (user_id = auth.uid() or public.is_admin());

-- Kelas & pelajaran: judul boleh dilihat semua orang; admin boleh mengelola
drop policy if exists "kelas dibaca semua" on public.courses;
create policy "kelas dibaca semua" on public.courses for select using (true);
drop policy if exists "kelas dikelola admin" on public.courses;
create policy "kelas dikelola admin" on public.courses for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "pelajaran dibaca semua" on public.lessons;
create policy "pelajaran dibaca semua" on public.lessons for select using (true);
drop policy if exists "pelajaran dikelola admin" on public.lessons;
create policy "pelajaran dikelola admin" on public.lessons for all using (public.is_admin()) with check (public.is_admin());

-- Link video/PDF: hanya member aktif, admin, atau pelajaran yang ditandai gratis
drop policy if exists "materi untuk member" on public.lesson_media;
create policy "materi untuk member" on public.lesson_media for select using (
  public.is_member() or public.is_admin()
  or exists (select 1 from public.lessons l where l.id = lesson_id and l.gratis)
);
drop policy if exists "materi dikelola admin" on public.lesson_media;
create policy "materi dikelola admin" on public.lesson_media for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 4. FUNGSI PESANAN
-- ---------------------------------------------------------------------------

-- Pembeli membuat pesanan. Harga diambil dari tabel plans (tidak bisa dicurangi).
create or replace function public.create_order(p_plan text, p_metode text)
returns public.orders
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_plan public.plans;
  v_old  public.orders;
  v_new  public.orders;
  v_kode int;
begin
  if v_uid is null then raise exception 'Silakan masuk dulu.'; end if;
  if p_metode !~ '^[a-z]{2,15}$' then raise exception 'Metode pembayaran tidak valid.'; end if;
  select * into v_plan from public.plans where id = p_plan and aktif;
  if not found then raise exception 'Paket tidak ditemukan.'; end if;

  -- pakai lagi tagihan yang masih berlaku untuk paket & metode yang sama
  select * into v_old from public.orders
   where user_id = v_uid and plan_id = p_plan and metode = p_metode
     and status = 'pending' and batas > now()
   order by created_at desc limit 1;
  if found then return v_old; end if;

  -- batasi spam: maksimal 5 tagihan aktif per akun
  if (select count(*) from public.orders where user_id = v_uid and status in ('pending','sent') and batas > now()) >= 5 then
    raise exception 'Terlalu banyak tagihan aktif. Selesaikan atau batalkan tagihan sebelumnya.';
  end if;

  v_kode := 101 + floor(random() * 399)::int;   -- 3 digit unik: 101–499
  insert into public.orders (id, user_id, plan_id, bulan, harga, kode_unik, total, metode, batas)
  values ('IS-' || to_char(now() at time zone 'Asia/Jakarta', 'YYMMDD') || '-' || upper(substr(md5(random()::text), 1, 6)),
          v_uid, v_plan.id, v_plan.bulan, v_plan.harga, v_kode, v_plan.harga + v_kode, p_metode,
          now() + interval '24 hours')
  returning * into v_new;
  return v_new;
end $$;

-- Pembeli menandai "sudah konfirmasi via WhatsApp"
create or replace function public.mark_sent(p_id text) returns public.orders
language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  update public.orders set status = 'sent'
   where id = p_id and user_id = auth.uid() and status = 'pending' and batas > now()
  returning * into v;
  if not found then select * into v from public.orders where id = p_id and user_id = auth.uid(); end if;
  return v;
end $$;

-- Pembeli membatalkan pesanannya sendiri
create or replace function public.cancel_order(p_id text) returns public.orders
language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  update public.orders set status = 'cancelled'
   where id = p_id and user_id = auth.uid() and status in ('pending', 'sent')
  returning * into v;
  if not found then select * into v from public.orders where id = p_id and user_id = auth.uid(); end if;
  return v;
end $$;

-- ADMIN: setujui pembayaran → masa aktif bertambah otomatis
create or replace function public.approve_order(p_id text) returns public.orders
language plpgsql security definer set search_path = public as $$
declare
  v public.orders;
  v_tambah interval;
begin
  if not public.is_admin() then raise exception 'Khusus admin.'; end if;
  select * into v from public.orders where id = p_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan.'; end if;
  if v.status = 'paid' then return v; end if;   -- aman diklik dua kali

  v_tambah := case when v.bulan % 12 = 0 then make_interval(years => v.bulan / 12)
                   else make_interval(days => 30 * v.bulan) end;
  update public.profiles
     set member_until = greatest(coalesce(member_until, now()), now()) + v_tambah
   where id = v.user_id;
  update public.orders set status = 'paid', paid_at = now() where id = p_id returning * into v;
  return v;
end $$;

-- ADMIN: tolak pembayaran
create or replace function public.reject_order(p_id text) returns public.orders
language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  if not public.is_admin() then raise exception 'Khusus admin.'; end if;
  update public.orders set status = 'cancelled' where id = p_id and status <> 'paid' returning * into v;
  if not found then select * into v from public.orders where id = p_id; end if;
  return v;
end $$;

-- ADMIN: ubah masa aktif member secara manual (tambah hari, atau cabut akses)
create or replace function public.set_member_until(p_user uuid, p_until timestamptz) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare v public.profiles;
begin
  if not public.is_admin() then raise exception 'Khusus admin.'; end if;
  update public.profiles set member_until = p_until where id = p_user returning * into v;
  return v;
end $$;

-- Hanya akun yang sudah masuk yang boleh memanggil fungsi-fungsi ini
revoke execute on function public.create_order(text, text)        from public, anon;
revoke execute on function public.mark_sent(text)                 from public, anon;
revoke execute on function public.cancel_order(text)              from public, anon;
revoke execute on function public.approve_order(text)             from public, anon;
revoke execute on function public.reject_order(text)              from public, anon;
revoke execute on function public.set_member_until(uuid, timestamptz) from public, anon;
grant  execute on function public.create_order(text, text)        to authenticated;
grant  execute on function public.mark_sent(text)                 to authenticated;
grant  execute on function public.cancel_order(text)              to authenticated;
grant  execute on function public.approve_order(text)             to authenticated;
grant  execute on function public.reject_order(text)              to authenticated;
grant  execute on function public.set_member_until(uuid, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. STORAGE "materi" (file PDF / video kecil) — terkunci
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('materi', 'materi', false)
on conflict (id) do nothing;

drop policy if exists "materi dibaca member" on storage.objects;
create policy "materi dibaca member" on storage.objects for select using (
  bucket_id = 'materi' and (
    public.is_member() or public.is_admin()
    or exists (select 1 from public.lesson_media m join public.lessons l on l.id = m.lesson_id
               where l.gratis and (m.pdf_path = storage.objects.name or m.video = storage.objects.name))
  )
);
drop policy if exists "materi diunggah admin" on storage.objects;
create policy "materi diunggah admin" on storage.objects for insert with check (bucket_id = 'materi' and public.is_admin());
drop policy if exists "materi diubah admin" on storage.objects;
create policy "materi diubah admin" on storage.objects for update using (bucket_id = 'materi' and public.is_admin());
drop policy if exists "materi dihapus admin" on storage.objects;
create policy "materi dihapus admin" on storage.objects for delete using (bucket_id = 'materi' and public.is_admin());

-- ---------------------------------------------------------------------------
-- 6. DATA AWAL (contoh — silakan ubah lewat Table Editor)
-- ---------------------------------------------------------------------------
insert into public.plans (id, nama, bulan, harga, harga_coret, catatan, unggulan, urutan) values
  ('1bln',  '1 bulan',  1,  129000, null,    'Cocok untuk coba-coba', false, 1),
  ('3bln',  '3 bulan',  3,  329000, 387000,  'Hemat 15%',             false, 2),
  ('12bln', '12 bulan', 12, 950000, 1600000, 'Paling hemat',          true,  3)
on conflict (id) do nothing;

do $$
declare c1 bigint; c2 bigint; c3 bigint;
begin
  if not exists (select 1 from public.courses) then
    insert into public.courses (judul, level, ringkas, warna, urutan) values
      ('Speaking Dasar: Berani Ngomong dalam 30 Hari', 'Pemula', 'Dari nol sampai bisa ngobrol santai: perkenalan, small talk, tanya arah, pesan makanan.', '#ff6b4a', 1)
      returning id into c1;
    insert into public.courses (judul, level, ringkas, warna, urutan) values
      ('Grammar Tanpa Pusing', 'Menengah', 'Tenses dan struktur kalimat dijelaskan dengan bahasa sehari-hari, plus latihan soal.', '#1e2a5a', 2)
      returning id into c2;
    insert into public.courses (judul, level, ringkas, warna, urutan) values
      ('English for Work', 'Lanjut', 'Email profesional, meeting, presentasi singkat, dan wawancara kerja.', '#2f9e6c', 3)
      returning id into c3;
    insert into public.lessons (course_id, judul, durasi, urutan, gratis) values
      (c1, 'Memperkenalkan diri', '8 menit', 1, true),
      (c1, 'Angka, hari, dan waktu', '10 menit', 2, false),
      (c1, 'Small talk sehari-hari', '9 menit', 3, false),
      (c2, 'To be & kalimat dasar', '9 menit', 1, false),
      (c2, 'Simple present vs present continuous', '11 menit', 2, false),
      (c3, 'Menulis email profesional', '12 menit', 1, false);
  end if;
end $$;

-- =============================================================================
-- LANGKAH TERAKHIR (jalankan terpisah, SETELAH kamu mendaftar di website):
-- jadikan akunmu admin. Ganti emailnya dengan email kamu sendiri:
--
--   update public.profiles set is_admin = true where email = 'emailkamu@gmail.com';
-- =============================================================================
