# MyAnimeRent 🌸👗

> *"Kostum Hari Ini, Cerita Seru Esok Nanti ✨"*  
> **Platform rental kostum anime di Indonesia yang lebih terorganisir, praktis, dan terpercaya.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Database-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
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

- 🔐 **Autentikasi Pengguna**: Registrasi akun dan login dengan Firebase Authentication, dilengkapi validasi interaktif dan visibilitas password.
- 👘 **Eksplorasi Kostum**:
  - Banner dinamis beranda dengan navigasi carousel.
  - Pengelompokan katalog berdasarkan judul anime.
  - Pencarian interaktif dengan pencocokan nama kostum dan karakter.
  - Halaman detail kostum lengkap dengan galeri foto, spesifikasi ukuran, informasi toko penyedia, dan ulasan.
- 🏪 **Direktori & Profil Toko (Cosrent)**:
  - Daftar Top Cosrent terpercaya dengan lokasi kota dan rating rata-rata.
  - Halaman profil toko lengkap dengan katalog kostum yang tersedia.
- 📅 **Kalender Sewa & Booking**:
  - Pilihan rentang tanggal sewa fleksibel (minimal 3 hari).
  - Tampilan visual tanggal terisi (booked) dan tanggal yang tersedia.
  - Riwayat penyewaan kostum yang telah dipesan.
- ⭐ **Ulasan & Rating**:
  - Ulasan pelanggan dengan penilaian bintang dan komentar.
  - Dialog interaktif untuk menambahkan ulasan baru.
- ❤️ **Wishlist**: Simpan kostum impian ke daftar favorit dan akses kapan saja.
- 👤 **Profil Pengguna**:
  - Pengelolaan profil dan unggah foto avatar langsung ke cloud (Imgur integration).
- 🌓 **Tema Fleksibel**:
  - Dukungan **Light Mode** dan **Dark Mode** modern dengan Material 3 ColorScheme yang nyaman di mata.

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.13.2`)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **Backend**:
  - [firebase_core](https://pub.dev/packages/firebase_core)
  - [firebase_auth](https://pub.dev/packages/firebase_auth)
  - [firebase_database](https://pub.dev/packages/firebase_database)
- **Image & Networking**:
  - [cached_network_image](https://pub.dev/packages/cached_network_image)
  - [http](https://pub.dev/packages/http)
  - [image_picker](https://pub.dev/packages/image_picker)
- **Local Storage**: [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Typography & UI**:
  - [google_fonts](https://pub.dev/packages/google_fonts) (Poppins)
  - [cupertino_icons](https://pub.dev/packages/cupertino_icons)
  - [intl](https://pub.dev/packages/intl)

---

## 📁 Struktur Direktori

```text
lib/
├── app.dart            # Inisialisasi MaterialApp & Router
├── main.dart           # Entrypoint aplikasi & Firebase Init
├── firebase_options.dart
├── config/
│   ├── routes.dart     # Definisi GoRouter & proteksi auth
│   └── theme.dart      # AppColors, Light Theme, & Dark Theme
├── models/             # Costume, Store, Review, Rental models
├── providers/          # Auth, Costume, Rental, Review, Wishlist, Settings
├── services/           # AuthService, DatabaseService, ImgurService, Prefs
├── screens/
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── product_detail_screen.dart
│   ├── search_screen.dart
│   ├── wishlist_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   ├── store_screen.dart
│   ├── store_detail_screen.dart
│   └── rental_history_screen.dart
└── widgets/
    ├── app_shell.dart
    ├── costume_card.dart
    ├── store_card.dart
    ├── review_section.dart
    ├── review_dialog.dart
    └── expandable_calendar_view.dart
```

---

## 🚀 Panduan Memulai

### 1. Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.13 atau yang lebih baru)
- Perangkat Android, iOS Simulator, Chrome Browser, atau Windows desktop

### 2. Instalasi Dependensi
```bash
flutter pub get
```

### 3. Menjalankan Aplikasi
Jalankan di emulator atau perangkat yang terhubung:
```bash
flutter run
```

Atau pilih target spesifik:
```bash
# Menjalankan di Chrome Web
flutter run -d chrome

# Menjalankan di Windows Desktop
flutter run -d windows
```

### 4. Menjalankan Analisis Kode
Pastikan tidak ada linting error:
```bash
flutter analyze
```

---

## 📄 Lisensi

Proyek ini dikembangkan untuk keperluan platform rental kostum anime **MyAnimeRent**. Seluruh hak cipta desain brand dan aset grafis dilindungi.
