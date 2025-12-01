#!/bin/bash
# ==============================================================================
# Skrip Deployment Otomatis CodeIgniter 4 untuk Alur Kerja Git Pull
# ==============================================================================
#
# Petunjuk Penggunaan:
# 1. Pastikan Anda sudah clone repositori ke server (misal: /home/tensitras/tensitracker).
# 2. **PENTING (Hanya sekali):** Setelah clone, edit file .env di server Anda.
#    cp .env.example .env
#    nano .env # atau editor lainnya
#    Isi semua detail sensitif (database, dll.) dan set CI_ENVIRONMENT = production.
# 3. Pastikan document root web server (Apache/Nginx) menunjuk ke public_html
#    (misal: /home/tensitras/public_html).
# 4. Untuk deployment awal atau update:
#    cd /path/ke/proyek/Anda (misal: /home/tensitras/tensitracker)
#    git pull
#    chmod +x deploy.sh
#    ./deploy.sh
#
# ==============================================================================

set -e # Hentikan skrip jika ada perintah yang gagal

# --- KONFIGURASI (Silakan sesuaikan jika struktur server Anda berbeda) ---
# Nama folder proyek di server (ini harus sesuai dengan nama folder tempat Anda clone repo)
PROJECT_NAME="tensitracker"
# URL domain aplikasi Anda
APP_BASE_URL='https://tensitracker.my.id'

# --- VARIABEL INTERNAL ---
PROJECT_ROOT=$(pwd) # Direktori tempat skrip ini dijalankan (harus root proyek CI4)
# Asumsi public_html berada satu level di atas direktori proyek, sesuai standar shared hosting
PUBLIC_HTML_PATH="/home/tensitras/public_html" # Sesuaikan jika path ini berbeda
INDEX_PHP_PATH="${PUBLIC_HTML_PATH}/index.php"
ENV_PATH="${PROJECT_ROOT}/.env"

echo "Memulai proses deployment CodeIgniter 4..."
echo "----------------------------------------------------"
echo "Project Root (Server): ${PROJECT_ROOT}"
echo "Public HTML Path (Server): ${PUBLIC_HTML_PATH}"
echo "Base URL Aplikasi: ${APP_BASE_URL}"
echo "----------------------------------------------------"

# 1. Sinkronkan isi folder /public ke /public_html
# ----------------------------------------------------
echo "[1/7] Menyinkronkan isi 'public/' ke 'public_html/'..."
# Buat public_html jika belum ada
mkdir -p "$PUBLIC_HTML_PATH"
# Sinkronkan file, hapus file di tujuan yang tidak ada di sumber
rsync -av --delete "${PROJECT_ROOT}/public/" "${PUBLIC_HTML_PATH}/"
echo "  > Isi 'public/' telah disinkronkan ke 'public_html/'."


# 2. Perbaiki path di public_html/index.php
# ----------------------------------------------------
echo "[2/7] Memperbaiki path di '${INDEX_PHP_PATH}'..."
# Baris ini sangat penting. Ini mengubah path relatif default ke path absolut
# agar index.php bisa menemukan file framework dari lokasi public_html.
sed -i "s|'../app/Config/Paths.php'|'${PROJECT_ROOT}/app/Config/Paths.php'|" "$INDEX_PHP_PATH"
echo "  > Path di public_html/index.php telah disesuaikan."


# 3. Konfigurasi file .env untuk produksi (jika belum ada)
# ----------------------------------------------------
echo "[3/7] Mengkonfigurasi file .env (jika belum ada)..."
if [ ! -f "$ENV_PATH" ]; then
    echo "  > File .env belum ada. Membuat dari .env.example."
    cp "${PROJECT_ROOT}/.env.example" "$ENV_PATH"

    # Set environment ke production
    sed -i "s/^# *CI_ENVIRONMENT = development/CI_ENVIRONMENT = production/" "$ENV_PATH"
    sed -i "s/^CI_ENVIRONMENT = .*/CI_ENVIRONMENT = production/" "$ENV_PATH"

    # Set base URL
    sed -i "s|^# *app.baseURL = ''|app.baseURL = '${APP_BASE_URL}'|" "$ENV_PATH"
    sed -i "s|^app.baseURL = ''|app.baseURL = '${APP_BASE_URL}'|" "$ENV_PATH"

    echo "  > .env dasar telah dibuat dan dikonfigurasi. **HARAP EDIT .env INI SECARA MANUAL DI SERVER UNTUK DETAIL SENSITIF (DB, dll).**"
else
    echo "  > File .env sudah ada. Lewati pembuatan dan konfigurasi otomatis. Pastikan sudah dikonfigurasi dengan benar untuk server."
fi


# 4. Konfigurasi Database SQLite di .env (jika .env baru dibuat)
# ----------------------------------------------------
echo "[4/7] Mengkonfigurasi database SQLite di .env (jika diperlukan)..."
if [ ! -f "$ENV_PATH" ]; then # Hanya jika .env baru dibuat oleh skrip
    # Menonaktifkan konfigurasi database default (biasanya MySQL) jika ada
    sed -i "/^database.default.hostname/s/^/# /" "$ENV_PATH"
    sed -i "/^database.default.database *= *[^'].*[^']/s/^/# /" "$ENV_PATH"
    sed -i "/^database.default.username/s/^/# /" "$ENV_PATH"
    sed -i "/^database.default.password/s/^/# /" "$ENV_PATH"
    sed -i "/^database.default.DBDriver *= *MySQLi/s/^/# /" "$ENV_PATH"
    sed -i "/^database.default.DBDriver *= *Postgre/s/^/# /" "$ENV_PATH"

    # Menambahkan konfigurasi SQLite3
    echo "" >> "$ENV_PATH"
    echo "# --- Konfigurasi SQLite3 (Ditambahkan Otomatis) ---" >> "$ENV_PATH"
    echo "database.default.DBDriver = SQLite3" >> "$ENV_PATH"
    echo "database.default.database = '${PROJECT_ROOT}/writable/database.db'" >> "$ENV_PATH"
    echo "database.default.foreignKeys = true" >> "$ENV_PATH"
    echo "  > Konfigurasi SQLite3 dasar telah ditambahkan ke .env."
else
    echo "  > File .env sudah ada, Lewati konfigurasi SQLite otomatis."
fi


# 5. Memindahkan database.db dari root ke writable/ (jika ada dan belum dipindahkan)
# ----------------------------------------------------
echo "[5/7] Memeriksa dan memindahkan database.db (jika ada)..."
if [ -f "${PROJECT_ROOT}/database.db" ] && [ ! -f "${PROJECT_ROOT}/writable/database.db" ]; then
    echo "  > Memindahkan database.db dari root ke writable/database.db..."
    mv "${PROJECT_ROOT}/database.db" "${PROJECT_ROOT}/writable/database.db"
    echo "  > Database.db berhasil dipindahkan."
elif [ ! -f "${PROJECT_ROOT}/writable/database.db" ]; then
    echo "  > Catatan: File database.db tidak ditemukan di root proyek maupun di writable/. Pastikan database Anda siap."
else
    echo "  > File database.db sudah berada di writable/database.db."
fi


# 6. Jalankan Composer Install
# ----------------------------------------------------
echo "[6/7] Menjalankan composer install untuk produksi..."
if command -v composer &> /dev/null
then
    composer install --no-dev --optimize-autoloader
    echo "  > Dependensi Composer telah diinstall/diperbarui."
else
    echo "  > Peringatan: Composer tidak ditemukan. Lewati langkah ini."
    echo "  > Anda perlu menginstal dependensi secara manual."
fi


# 7. Atur Izin Folder dan Jalankan Migrasi
# ----------------------------------------------------
echo "[7/7] Mengatur izin folder dan menjalankan migrasi database..."
chmod -R 775 "${PROJECT_ROOT}/writable"
echo "  > Izin folder 'writable' telah diatur (775)."

# Jalankan migrasi database
if [ -f "${PROJECT_ROOT}/spark" ]; then
    php "${PROJECT_ROOT}/spark" migrate
    echo "  > Migrasi database telah dijalankan."
else
    echo "  > Peringatan: File 'spark' tidak ditemukan. Migrasi tidak dapat dijalankan."
fi


echo "----------------------------------------------------"
echo "PROSES DEPLOYMENT SELESAI!"
echo "Untuk deployment pertama, pastikan Anda telah mengedit file .env secara manual di server."
echo "===================================================="