#!/bin/bash

set -e

echo ""
echo "TPM Disk Şifreleme Gereksinim Yükleyici Başlatıldı"
echo ""

# === Paket listesi ===
REQUIRED_PACKAGES=(
  cryptsetup
  systemd
  tpm2-tools
  libtpm2-pkcs11-1
  util-linux
  parted
  lsb-release
)

echo "[+] Gerekli paketler kuruluyor..."

sudo apt update

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        echo "[✓] $pkg zaten kurulu."
    else
        echo "[>] $pkg kuruluyor..."
        sudo apt install -y "$pkg"
    fi
done

# === TPM modülü kontrolü ===
echo ""
echo "[+] TPM modülü kontrol ediliyor..."

if ls /dev/tpm* 2>/dev/null | grep -q tpm; then
    echo "[✓] TPM modülü sistemde mevcut: $(ls /dev/tpm* | tr '\n' ' ')"
else
    echo "[!] Uyarı: TPM donanımı bulunamadı. Yazılım TPM (swtpm) kullanacaksan ayrıca kurman gerek."
fi

# === systemd-cryptenroll kontrolü ===
if ! command -v systemd-cryptenroll &> /dev/null; then
    echo "[!] systemd-cryptenroll komutu bulunamadı. systemd sürümün eski olabilir."
    echo "    systemd 245+ ve üzeri gerekir. Dağıtım yükseltmeyi düşün."
else
    echo "[✓] systemd-cryptenroll mevcut."
fi

echo ""
echo "Ortam hazır. Artık TPM disk şifreleme scriptini çalıştırabilirsin."
