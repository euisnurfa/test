/* Fungsi bersama untuk semua halaman. Tidak perlu diubah. */
(function () {
  const C = window.CONFIG || {};
  const ready = !!(C.supabaseUrl && C.supabaseAnonKey && window.supabase && window.supabase.createClient);
  const sb = ready ? window.supabase.createClient(C.supabaseUrl, C.supabaseAnonKey) : null;

  const BULAN = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
  const LOGO = {
    qris: '<span class="lg-qris">QRIS</span>', mandiri: '<span class="lg-mandiri">mandiri</span>',
    bni: '<span class="lg-bni">BNI</span>', bri: '<span class="lg-bri">BRI</span>', bca: '<span class="lg-bca">BCA</span>',
  };

  const U = {
    C, sb, ready, LOGO,
    $: (id) => document.getElementById(id),
    rp: (n) => "Rp " + Number(n || 0).toLocaleString("id-ID"),
    esc: (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])),
    tgl(d, jam) {
      if (!d) return "-";
      d = new Date(d);
      let s = `${d.getDate()} ${BULAN[d.getMonth()]} ${d.getFullYear()}`;
      if (jam) s += `, ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
      return s;
    },
    toast(t) {
      let el = document.getElementById("toast");
      if (!el) { el = document.createElement("div"); el.id = "toast"; el.className = "toast"; document.body.appendChild(el); }
      el.textContent = t; el.classList.add("on");
      clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove("on"), 2000);
    },
    base() { return location.origin + location.pathname.replace(/[^/]*$/, ""); },
    go(page) { location.href = page; },

    /** pesan error yang ramah */
    err(e) {
      const m = (e && (e.message || e.error_description || e.msg)) || String(e || "");
      const map = [
        [/Invalid login credentials/i, "Email atau password salah."],
        [/Email not confirmed/i, "Email belum dikonfirmasi. Buka email dari kami dan klik link konfirmasinya."],
        [/User already registered/i, "Email ini sudah terdaftar. Silakan masuk."],
        [/Password should be at least/i, "Password terlalu pendek (minimal 8 karakter)."],
        [/rate limit|too many/i, "Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi."],
        [/Failed to fetch|NetworkError|Load failed/i, "Tidak bisa terhubung ke server. Periksa koneksi internet kamu."],
        [/JWT expired/i, "Sesi kamu habis. Silakan masuk lagi."],
      ];
      for (const [re, txt] of map) if (re.test(m)) return txt;
      return m || "Terjadi kesalahan. Coba lagi.";
    },

    async session() {
      if (!sb) return null;
      const { data } = await sb.auth.getSession();
      return data.session;
    },
    async profile() {
      const s = await U.session();
      if (!s) return null;
      const { data } = await sb.from("profiles").select("*").eq("id", s.user.id).maybeSingle();
      return data;
    },
    isMember: (p) => !!(p && p.member_until && new Date(p.member_until) > new Date()),

    /** wajib login; kalau belum, diarahkan ke halaman masuk */
    async requireLogin() {
      const s = await U.session();
      if (!s) { location.href = "masuk.html?next=" + encodeURIComponent(location.pathname.split("/").pop() + location.search); return null; }
      return s;
    },

    methods() {
      return [{ kode: "qris", nama: "QRIS", ket: "GoPay, OVO, DANA, ShopeePay, m-banking" }]
        .concat((C.rekening || []).map((r) => ({ ...r, ket: r.atasNama ? "a.n. " + r.atasNama : "Transfer dari bank mana pun" })));
    },

    async nav() {
      document.querySelectorAll("[data-brand]").forEach((e) => (e.textContent = C.brand || ""));
      const box = document.getElementById("navlinks");
      if (!ready) {
        const b = document.createElement("div");
        b.className = "setup";
        b.innerHTML = "Website belum tersambung ke database. Pemilik situs: isi <code>supabaseUrl</code> dan <code>supabaseAnonKey</code> di <code>config.js</code>.";
        document.body.prepend(b);
      }
      if (!box) return;
      const s = await U.session();
      let html = '<a class="hide-m" href="index.html#kelas">Kelas</a><a class="hide-m" href="index.html#harga">Harga</a>';
      if (s) {
        const p = await U.profile();
        html += '<a href="kelas.html">Kelas Saya</a>';
        if (p && p.is_admin) html += '<a href="admin.html">Admin</a>';
        html += '<a class="hide-m" href="#" id="logoutLink">Keluar</a>';
      } else {
        html += '<a href="masuk.html">Masuk</a><a class="btn btn-primary" href="index.html#harga">Langganan</a>';
      }
      box.innerHTML = html;
      const lo = document.getElementById("logoutLink");
      if (lo) lo.onclick = async (e) => { e.preventDefault(); await sb.auth.signOut(); location.href = "index.html"; };
      const ft = document.getElementById("contact");
      if (ft) ft.innerHTML = [C.whatsapp ? `WhatsApp: <a href="https://wa.me/${U.esc(C.whatsapp)}" target="_blank" rel="noopener">+${U.esc(C.whatsapp)}</a>` : "", C.email ? U.esc(C.email) : ""].filter(Boolean).join(" · ");
    },

    /** ubah link YouTube/Vimeo/Google Drive biasa menjadi link pemutar */
    toEmbed(url) {
      let m;
      if ((m = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([\w-]{6,})/))) return `https://www.youtube-nocookie.com/embed/${m[1]}?rel=0&modestbranding=1`;
      if ((m = url.match(/player\.vimeo\.com\/video\/\d+/))) return url;
      if ((m = url.match(/vimeo\.com\/(\d+)(?:\/([\da-f]+))?/))) return `https://player.vimeo.com/video/${m[1]}${m[2] ? "?h=" + m[2] : ""}`;
      if ((m = url.match(/drive\.google\.com\/file\/d\/([\w-]+)/))) return `https://drive.google.com/file/d/${m[1]}/preview`;
      return url;
    },
  };
  window.U = U;
})();
