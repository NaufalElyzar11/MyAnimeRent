# MyAnimeRent 🌸👗

## Versi uji event offline

Aplikasi utama tetap memakai flavor default `standard` dan target `lib/main.dart`, beserta fitur yang sudah ada. Mode event memakai komponen UI yang sama, empat tab, katalog lokal dan favorit sementara. Paket uji memiliki ID Android `.event` sehingga dapat dipasang berdampingan dengan aplikasi utama:

```powershell
flutter run --flavor event -t lib/main_event.dart
flutter build apk --debug --flavor event -t lib/main_event.dart
```

Data bawaan bersifat ilustratif, harga simulasi dan kontak nonaktif. [Panduan event, format snapshot, validasi dan lembar uji](../dokumen-saas/11-panduan-menjalankan-demo-event.md). Target default `lib/main.dart` adalah aplikasi utama yang terhubung ke Supabase; gunakan target event secara eksplisit.

> *"Kostum Hari Ini, Cerita Seru Esok Nanti ✨"*  
> **Platform rental kostum anime di Indonesia yang lebih terorganisir, praktis, dan terpercaya.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Material Design 3](https://img.shields.io/badge/Design-Material%203-7B3FE4)](https://m3.material.io/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-FF4DA6)](#)

---

## 🎨 Identitas Brand & Filosofi Logo

Logo dan palet warna MyAnimeRent dirancang untuk merefleksikan semangat kreativitas fandom anime, kenyamanan layanan digital, dan komitmen profesional:

<p align="center">
  <img src="assets/images/logo.png" alt="MyAnimeRent Logo" width="280"/>
</p>

### Makna Logo:
* **Hanger (Gantungan Baju)**: Melambangkan layanan inti penyewaan kostum cosplay.
* **Siluet Anime**: Merepresentasikan dunia cosplay, karakter fandom, dan komunitas anime.
* **Bintang / Sparkle**: Simbol daya imajinasi, kreativitas, dan transformasi cosplay.
* **Bentuk Modern & Dinamis**: Menggambarkan kemudahan platform digital yang cepat dan ramah pengguna.

### Palet Warna Resmi:

| Warna | Kode Hex | Nilai Filosofis | Penerapan Utama |
| :--- | :--- | :--- | :--- |
| **Pink** | `#FF4DA6` | *Passion* (Gairah anime & fandom) | Warna Utama, Tombol Aksi, Indikator Aktif |
| **Ungu** | `#7B3FE4` | *Kreativitas* (Imajinasi cosplay) | Warna Sekunder, Header Ribbon, Focused Border |
| **Kuning** | `#FFC629` | *Optimisme* (Energi positif & keceriaan) | Bintang Rating, Badge Highlight, Aksen |
| **Abu Tua** | `#2E2E2E` | *Profesional* (Keandalan platform) | Tipografi Utama, Elemen Kontras |

---

## ✨ Fitur Utama

- 🔐 **Akun**: daftar, masuk, dan lupa kata sandi lewat Supabase Auth. Katalog bisa dilihat tanpa masuk.
- 👘 **Katalog kostum**: beranda per seri anime, pencarian di server (judul, karakter, seri, alias), detail dengan foto, ukuran, isi paket, harga, durasi, dan deposit.
- 📅 **Cek tanggal tanpa chat**: kalender per ukuran menandai tanggal yang **sudah dipesan**. Tanggal kosong berarti "belum ada jadwal", bukan "pasti tersedia". Toko yang belum memakai kalender ditandai "tanyakan ke toko".
- 📨 **Ajukan sewa dari app**: pilih ukuran dan tanggal, kirim permintaan, lalu ikuti statusnya (menunggu, dibalas, dikonfirmasi, ditolak, dibatalkan, kedaluwarsa). Ada pesan dua arah dengan toko; WA toko baru muncul setelah dikonfirmasi bila toko mengizinkan.
- 🔔 **Notifikasi**: kotak masuk dalam app (realtime) dan push FCM saat app tertutup.
- 🏪 **Direktori toko**: daftar toko terbit beserta katalognya.
- 🧾 **Tab Toko (owner/staf)**: muncul otomatis untuk akun yang terhubung ke toko.
  - Kotak permintaan: balas pesan, **konfirmasi** ke set tertentu (tanggal langsung terkunci) atau tolak dengan alasan.
  - Kalender per set: lihat jadwal sebulan, catat sewa dari WA/IG/datang langsung, blok laundry/perbaikan, batalkan sewa.
  - Katalog: buat/edit kostum (info, isi paket, ukuran, harga, deposit, hari laundry), maks. 3 foto dari galeri/kamera (diperkecil di HP, metadata lokasi dibuang server), terbitkan, tarik, arsipkan.
  - Profil toko (owner): nama, kota, aturan sewa, WhatsApp & apakah tampil publik, pengiriman, terbitkan/tarik toko.
  - Izin mengikuti peran: owner semua; staf sesuai izin `orders`/`calendar`.
- ❤️ **Favorit** tersimpan di akun.
- 🌓 **Tema terang/gelap** dengan Material 3.
- 💥 **Efek gerak ala anime (sakuga)**, dipakai seperlunya:
  - Tombol utama memampat dan memantul saat ditekan.
  - Ledakan kecil + tulisan ドン! saat permintaan terkirim, sewa dikonfirmasi toko, atau listing terbit; ヤッタ! saat penyewa membuka permintaan yang baru dikonfirmasi.
  - Kilau saat menyimpan favorit, toast yang meluncur, garis konsentrasi manga di halaman kosong.
  - Bisa dimatikan di **Pengaturan → Efek animasi anime**, dan otomatis mati bila HP memakai "kurangi animasi". Digambar dengan CustomPaint, terinspirasi [sakuga-vfx](https://github.com/finktheartist/sakuga-vfx), tanpa paket tambahan.

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.13.2`)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **Backend**: [supabase_flutter](https://pub.dev/packages/supabase_flutter) (Auth, database dengan RLS, Edge Functions, Storage, Realtime)
- **Push**: [firebase_core](https://pub.dev/packages/firebase_core) + [firebase_messaging](https://pub.dev/packages/firebase_messaging) (hanya FCM; data tidak lagi di Firebase)
- **Gambar**: [cached_network_image](https://pub.dev/packages/cached_network_image), [image_picker](https://pub.dev/packages/image_picker) (foto katalog toko)
- **Local Storage**: [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Typography & UI**:
  - [google_fonts](https://pub.dev/packages/google_fonts) (Poppins)
  - [cupertino_icons](https://pub.dev/packages/cupertino_icons)
  - [intl](https://pub.dev/packages/intl)

---

## 📁 Struktur Direktori

```text
lib/
├── main.dart               # Entrypoint: Supabase.initialize + Firebase (push saja)
├── main_event.dart         # Entrypoint mode event offline
├── app.dart                # MaterialApp, provider, sinkron saat login/logout
├── config/
│   ├── supabase_config.dart  # SUPABASE_URL & kunci publishable dari --dart-define
│   ├── event_safety.dart     # Mode event dilarang mengakses cloud
│   ├── routes.dart           # GoRouter; halaman pribadi minta login
│   └── theme.dart
├── models/                 # Costume, Store, AppUser, RentalRequest, AppNotification, Availability
├── providers/              # Auth, Costume, Rental, Wishlist, Notification, Settings
├── services/
│   ├── supabase_service.dart # Backend.call (Edge Function) / Backend.rpc + ApiException
│   ├── auth_service.dart
│   ├── database_service.dart # Katalog, cek tanggal, permintaan, pesan, notifikasi, favorit
│   └── push_service.dart     # Token FCM ↔ register_push_token
├── screens/                # Beranda, Cari, Detail, Permintaan Sewa, Detail Permintaan, Notifikasi, Profil, …
│   └── store/              # Tab Toko: kotak permintaan, detail untuk toko, kalender, jadwal per set
├── widgets/sakuga.dart     # Efek anime: SakugaPressable, Sakuga.burst/toast, PopIn, SpeedLines
├── event/                  # Katalog & layar mode event
└── widgets/
```

---

## 🚀 Panduan Memulai

### 1. Prasyarat
- Flutter SDK 3.x, Android Studio/emulator atau HP Android
- Backend lokal berjalan (lihat [`../supabase/README.md`](../supabase/README.md)): `npx supabase start`, `npx supabase db reset`, `npx supabase functions serve`, lalu `npm run gambar-demo` di `supabase/tests/functions` agar katalog bergambar

### 2. Konfigurasi (sekali)
```powershell
Copy-Item env\local.example.json env\local.json
```
Isi `SUPABASE_PUBLISHABLE_KEY` dengan **Publishable key** dari `npx supabase status`. Jangan pernah memasukkan kunci *secret*/`service_role` ke app. `env/local.json` tidak ikut git.

| Menjalankan di | `SUPABASE_URL` |
|---|---|
| Emulator Android | `http://10.0.2.2:54321` |
| HP fisik lewat kabel USB (disarankan) | `http://127.0.0.1:54321`, setelah `adb reverse tcp:54321 tcp:54321` |
| HP fisik lewat Wi-Fi yang sama | `http://<IP-komputer>:54321`, mis. `http://192.168.1.10:54321`; izinkan port 54321 di Windows Firewall |
| Produksi | `https://<project-ref>.supabase.co` (buat `env/prod.json`) |

### 3. Menjalankan
```powershell
flutter pub get
flutter run --flavor standard --dart-define-from-file=env/local.json
```

HP fisik lewat USB: `10.0.2.2` hanya berlaku di emulator, jadi di HP katalog akan gagal dimuat. Teruskan port komputer ke HP, lalu pakai file konfigurasi khusus HP:
```powershell
adb reverse tcp:54321 tcp:54321          # ulangi setiap kali kabel dicabut / HP tersambung ulang
Copy-Item env\hp-usb.example.json env\hp-usb.json   # sekali
flutter run --flavor standard --dart-define-from-file=env/hp-usb.json
```
Tanpa `--dart-define-from-file`, app menampilkan layar "konfigurasi belum diisi".

Akun demo lokal (kata sandi `demo12345`): `penyewa@demo.local` untuk mencoba booking; `owner-a@demo.local` (atau staf `admin-a@demo.local`) membuka tab **Toko** untuk menjawab dan mengonfirmasi. Toko B/C (`owner-b`, `owner-c`) memakai paket Direktori tanpa kalender, jadi hanya bisa membalas dan menolak.

### 4. Pemeriksaan
```powershell
flutter analyze
flutter test
```

---

## 📄 Lisensi

Proyek ini dikembangkan untuk keperluan platform rental kostum anime **MyAnimeRent**. Seluruh hak cipta desain brand dan aset grafis dilindungi.
