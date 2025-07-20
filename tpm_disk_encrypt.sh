#!/bin/bash

set -e

echo ""
echo "TPM destekli disk şifreleme başlatılıyor..."
echo ""

# === Uygun diskleri listele (root diski ve bağlı olanları filtrele) ===
DISK_LIST=()

i=1
while IFS= read -r line; do
    DEV=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    echo "$i) $DEV ($SIZE)"
    DISK_LIST+=("$DEV")
    i=$((i+1))
done < <(lsblk -dpno NAME,SIZE,TYPE,MOUNTPOINT | grep "disk" | grep -v " /$")

if [ ${#DISK_LIST[@]} -eq 0 ]; then
    echo "Uygun ek disk bulunamadı. Lütfen USB veya ikinci disk bağlayın."
    exit 1
fi

echo ""
read -p "Kullanmak istediğiniz diskin numarasını girin: " CHOICE
CHOICE_INDEX=$((CHOICE-1))
CHOSEN_DISK="${DISK_LIST[$CHOICE_INDEX]}"

if [[ ! -b "$CHOSEN_DISK" ]]; then
    echo "Geçersiz seçim veya cihaz bulunamadı: $CHOSEN_DISK"
    exit 1
fi

echo ""
echo "Seçilen disk: $CHOSEN_DISK"
read -p "Tüm veriler silinecek. Devam etmek istiyor musunuz? (evet/hayır): " confirm
[[ "$confirm" != "evet" ]] && echo "İşlem iptal edildi." && exit 1

# === Değişkenler ===
MAPPER_NAME="mydisk"
MOUNT_POINT="/mnt/mydisk"

# === LUKS FORMAT ===
echo "LUKS2 format uygulanıyor..."
sudo cryptsetup luksFormat "$CHOSEN_DISK"

# === AÇ ve Biçimlendir ===
echo "Disk açılıyor ve ext4 olarak biçimlendiriliyor..."
sudo cryptsetup open "$CHOSEN_DISK" "$MAPPER_NAME"
sudo mkfs.ext4 /dev/mapper/"$MAPPER_NAME"
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"

# === TPM ENROLL ===
echo "TPM2 desteğiyle LUKS başlığına anahtar ekleniyor..."
sudo systemd-cryptenroll --tpm2-device=auto "$CHOSEN_DISK"

# === CRYPTTAB AYARI ===
echo "$MAPPER_NAME $CHOSEN_DISK - tpm2-device=auto" | sudo tee -a /etc/crypttab

# === FSTAB AYARI ===
UUID=$(sudo blkid -s UUID -o value /dev/mapper/"$MAPPER_NAME")
echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab

echo ""
echo "İşlem tamamlandı. $CHOSEN_DISK TPM üzerinden otomatik açılacak şekilde yapılandırıldı."
echo "Mount noktası: $MOUNT_POINT"
echo "Yeniden başlattıktan sonra otomatik mount aktif olacaktır."
