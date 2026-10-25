# Asoka Blue - Versi iOS (Native Swift & SwiftUI)

Aplikasi klien resmi Asoka Blue untuk perangkat iPhone (iOS), dibangun murni menggunakan **Swift & SwiftUI** modern dan terhubung langsung ke server database Firebase & VPS Asoka Blue.

---

## 📱 Arsitektur Aplikasi
- **Bahasa:** Swift 5.9+ / SwiftUI (iOS 16.0+)
- **Desain:** Human Interface Guidelines Apple dengan nuansa tema biru khas Asoka Blue
- **Backend:** Terhubung langsung ke Firebase Realtime Database (`asoka-5afdf-default-rtdb`) dan REST API VPS Asoka Blue
- **Build System:** XcodeGen (`project.yml`) & GitHub Actions Mac Runner (100% Gratis)

---

## 🚀 Panduan Menguji Coba di Browser (Appetize.io)

### Langkah 1: Unggah ke Repositori GitHub
1. Buat repositori baru di akun GitHub Anda (misal: `AsokaBlue-iOS`).
2. Masukkan semua isi folder ini ke repositori tersebut:
   ```bash
   git init
   git add .
   git commit -m "Inisialisasi Asoka Blue iOS Native"
   git branch -M main
   git remote add origin https://github.com/USERNAME_ANDA/AsokaBlue-iOS.git
   git push -u origin main
   ```

### Langkah 2: Tunggu Kompilasi Otomatis di GitHub
1. Masuk ke tab **Actions** di repositori GitHub Anda.
2. Workflow **"Build Asoka Blue iOS"** akan otomatis berjalan di komputer Mac milik GitHub.
3. Setelah selesai (sekitar 2–3 menit), unduh file bernama **`AsokaBlue-Simulator.zip`** pada bagian **Artifacts**.

### Langkah 3: Jalankan di Appetize.io
1. Buka akun Anda di [Appetize.io](https://appetize.io).
2. Klik tombol **Upload** lalu seret file `AsokaBlue-Simulator.zip`.
3. Pilih perangkat: **iPhone 15 Pro** atau **iPhone 14**.
4. Layar iPhone interaktif akan menyala di browser Anda, dan Anda bisa langsung mencoba aplikasi Asoka Blue secara langsung!
