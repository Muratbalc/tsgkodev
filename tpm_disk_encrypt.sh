#!/bin/bash

# === AYARLAR ===
DISK="/dev/sdb"               # Dikkat! Tüm veri silinir
MAPPER_NAME="mydisk"
MOUNT_POINT="/mnt/mydisk"

# === BAŞLANGIÇ ===
echo "[+] Disk: $DISK"
echo "[!] Uyarı: Bu disk tamamen formatlanacak!"
read -p "Devam etmek istiyor musun? (evet/hayır): " confirm
[[ "$confirm" != "evet" ]] && echo "İptal edildi." && exit 1

# === LUKS FORMAT ===
echo "[+] LUKS2 format atılıyor..."
sudo cryptsetup luksFormat "$DISK" || exit 1

# === LUKS AÇ ===
echo "[+] LUKS disk açılıyor..."
sudo cryptsetup open "$DISK" "$MAPPER_NAME" || exit 1

# === Biçimlendir ve mount et ===
echo "[+] Disk biçimlendiriliyor (ext4)..."
sudo mkfs.ext4 /dev/mapper/"$MAPPER_NAME"
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"

# === TPM2 ENROLL ===
echo "[+] TPM2 ile LUKS başlığına anahtar ekleniyor..."
sudo systemd-cryptenroll --tpm2-device=auto "$DISK" || exit 1

# === CRYPTTAB AYARI ===
echo "[+] /etc/crypttab yapılandırılıyor..."
echo "$MAPPER_NAME $DISK - tpm2-device=auto" | sudo tee -a /etc/crypttab

# === FSTAB AYARI ===
UUID=$(sudo blkid -s UUID -o value /dev/mapper/"$MAPPER_NAME")
echo "[+] /etc/fstab yapılandırılıyor..."
echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab

# === SONUÇ ===
echo "==============================================="
echo "[✓] TPM destekli disk şifreleme tamamlandı!"
echo "[i] $DISK TPM ile otomatik açılacak"
echo "[i] Mount noktası: $MOUNT_POINT"
echo "[⚠] Değişiklikler etkili olsun diye sistemi yeniden başlat."
echo "==============================================="
