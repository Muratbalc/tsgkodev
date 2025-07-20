#!/bin/bash

set -e

echo "🔒 TPM destekli disk şifreleme başlatılıyor..."

# === Disk seçimi için mount edilmemiş diskleri listele ===
echo ""
echo "🔎 Bağlı diskler listeleniyor (root diski hariç):"
AVAILABLE_DISKS=()
while IFS= read -r line; do
    DISK_PATH=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    AVAILABLE_DISKS+=("$DISK_PATH" "$SIZE")
done < <(lsblk -dpno NAME,SIZE,TYPE,MOUNTPOINT | grep disk | grep -v '/$')

if [ ${#AVAILABLE_DISKS[@]} -eq 0 ]; then
    echo "❌ Şu anda kullanılabilir ek disk yok."
    exit 1
fi

# === Kullanıcıdan seçim al ===
echo ""
echo "⚠️  Hangi diski şifrelemek istiyorsun? DİKKAT: Diskteki TÜM veriler silinir!"
select CHOSEN_DISK in "${AVAILABLE_DISKS[@]}"; do
    if [[ -n "$CHOSEN_DISK" ]]; then
        break
    else
        echo "Geçersiz seçim, tekrar dene."
    fi
done

echo ""
echo "✅ Seçilen disk: $CHOSEN_DISK"

# === Uyarı ve onay al ===
read -p "Tüm veriler silinecek. Devam etmek istiyor musun? (evet/hayır): " confirm
[[ "$confirm" != "evet" ]] && echo "❌ İşlem iptal edildi." && exit 1

# === Sabit değişkenler ===
MAPPER_NAME="mydisk"
MOUNT_POINT="/mnt/mydisk"

# === LUKS FORMAT ===
echo "🧨 $CHOSEN_DISK diski LUKS2 olarak formatlanıyor..."
sudo cryptsetup luksFormat "$CHOSEN_DISK"

# === Aç ve dosya sistemi oluştur ===
echo "🔓 Disk açılıyor ve dosya sistemi oluşturuluyor..."
sudo cryptsetup open "$CHOSEN_DISK" "$MAPPER_NAME"
sudo mkfs.ext4 /dev/mapper/"$MAPPER_NAME"
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"

# === TPM Enroll ===
echo "🔐 TPM2 ile anahtar ekleniyor..."
sudo systemd-cryptenroll --tpm2-device=auto "$CHOSEN_DISK"

# === crypttab ayarı ===
echo "📌 /etc/crypttab yapılandırılıyor..."
echo "$MAPPER_NAME $CHOSEN_DISK - tpm2-device=auto" | sudo tee -a /etc/crypttab

# === fstab ayarı ===
UUID=$(sudo blkid -s UUID -o value /dev/mapper/"$MAPPER_NAME")
echo "📌 /etc/fstab yapılandırılıyor..."
echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab

# === Tamamlandı ===
echo ""
echo "🎉 TAMAMLANDI!"
echo "💡 $CHOSEN_DISK diski TPM ile şifrelendi ve /mnt/mydisk olarak ayarlandı."
echo "🔁 Şimdi sistemi yeniden başlatarak test edebilirsin."

