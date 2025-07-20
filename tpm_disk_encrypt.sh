#!/bin/bash

set -e

echo ""
echo "TPM destekli disk şifreleme başlatılıyor..."
echo ""

# === Bağlı ve root olmayan diskleri listele ===
DISK_LIST=()
i=1

while read -r line; do
    DEV=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    echo "$i) $DEV ($SIZE)"
    DISK_LIST+=("$DEV")
    i=$((i+1))
done < <(lsblk -dpno NAME,SIZE,TYPE,MOUNTPOINT | grep "disk" | grep -v " /$")

if [ ${#DISK_LIST[@]} -eq 0 ]; then
    echo "Uygun disk bulunamadı. USB ya da ikinci disk bağlı mı kontrol et."
    exit 1
fi

# === Kullanıcıdan seçim al ===
echo ""
read -p "Kullanmak istediğiniz diskin numarasını girin: " CHOICE
CHOICE_INDEX=$((CHOICE-1))
CHOSEN_DISK="${DISK_LIST[$CHOICE_INDEX]}"

if [[ -z "$CHOSEN_DISK" || ! -b "$CHOSEN_DISK" ]]; then
    echo "HATA: Geçersiz seçim. Disk bulunamadı."
    exit 1
fi

echo ""
echo "Seçilen disk: $CHOSEN_DISK"
read -p "DİKKAT! $CHOSEN_DISK tamamen silinecek. Devam etmek istiyor musun? (evet/hayır): " confirm
[[ "$confirm" != "evet" ]] && echo "İşlem iptal edildi." && exit 1

# === Ayarlar ===
MAPPER_NAME="mydisk"
MOUNT_POINT="/mnt/mydisk"

# === LUKS FORMAT ===
echo "[+] $CHOSEN_DISK LUKS2 olarak formatlanıyor..."
sudo cryptsetup luksFormat "$CHOSEN_DISK"

# === Aç ve biçimlendir ===
echo "[+] Disk açılıyor ve ext4 olarak biçimlendiriliyor..."
sudo cryptsetup open "$CHOSEN_DISK" "$MAPPER_NAME"
sudo mkfs.ext4 /dev/mapper/"$MAPPER_NAME"
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"

# === TPM enroll ===
echo "[+] TPM2 anahtar diske kaydediliyor..."
sudo systemd-cryptenroll --tpm2-device=auto "$CHOSEN_DISK"

# === crypttab ayarı ===
echo "[+] /etc/crypttab yapılandırılıyor..."
echo "$MAPPER_NAME $CHOSEN_DISK - tpm2-device=auto" | sudo tee -a /etc/crypttab

# === fstab ayarı ===
UUID=$(sudo blkid -s UUID -o value /dev/mapper/"$MAPPER_NAME")
echo "[+] /etc/fstab yapılandırılıyor..."
echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab

echo ""
echo "✅ TAMAMLANDI: $CHOSEN_DISK TPM ile şifrelendi ve /mnt/mydisk olarak ayarlandı."
echo "🔁 Sistemi yeniden başlattığında otomatik açılıp mount edilecektir."
