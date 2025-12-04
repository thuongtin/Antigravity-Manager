#!/bin/bash

# Thoát ngay khi có lỗi
set -e

echo "🚀 Bắt đầu build Trình quản lý Antigravity (macOS)..."

# 1. Đồng bộ tệp tài nguyên
echo "📦 Đồng bộ tệp tài nguyên..."
# Đảm bảo thư mục gui/assets tồn tại
mkdir -p gui/assets
# Đồng bộ nội dung thư mục assets vào gui/assets
cp -R assets/* gui/assets/
# Đồng bộ requirements.txt
cp requirements.txt gui/requirements.txt

# 2. Dọn dẹp kết quả build cũ
echo "🧹 Đang dọn dẹp các tệp build cũ..."
rm -rf gui/build/macos

# 3. Thực hiện build
echo "🔨 Bắt đầu biên dịch..."
# Tạo và kích hoạt môi trường ảo nếu chưa tồn tại
if [ ! -d ".venv" ]; then
    echo "🛠️ Tạo môi trường ảo..."
    python3 -m venv .venv
fi
echo "⚡ Kích hoạt môi trường ảo..."
source .venv/bin/activate

# Cài đặt các thư viện cần thiết
echo "📦 Cài đặt thư viện..."
pip install -r requirements.txt
cd gui

# Tạm thời tắt set -e vì flet build có thể ném traceback SystemExit: 0 nhưng thực tế build vẫn thành công
set +e

# Đảm bảo không vào chế độ tương tác
unset PYTHONINSPECT

# Sử dụng python -c để gọi trực tiếp flet_cli, tránh các vấn đề về entrypoint và chuyển hướng input
python -c "import sys; from flet.cli import main; main()" build macos \
    --product "Antigravity Manager" \
    --org "com.ctrler.antigravity" \
    --copyright "Copyright (c) 2025 Ctrler" \
    --build-version "1.0.0" \
    --desc "Công cụ quản lý tài khoản Antigravity" < /dev/null
EXIT_CODE=$?
set -e

# Quay lại thư mục gốc
cd ..

# 4. Kiểm tra kết quả build và đóng gói DMG
APP_NAME="Antigravity Manager"
APP_PATH="gui/build/macos/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
OUTPUT_DMG="gui/build/macos/$DMG_NAME"

if [ -d "$APP_PATH" ]; then
    echo "✅ Đã phát hiện gói ứng dụng, build thành công (bỏ qua mã thoát của Flet CLI)"
else
    echo "❌ Build thất bại, không tìm thấy gói ứng dụng"
    exit $EXIT_CODE
fi

echo "📦 Đang tạo gói cài đặt DMG..."

# Tạo thư mục tạm để tạo DMG
DMG_SOURCE="gui/build/macos/dmg_source"
rm -rf "$DMG_SOURCE"
mkdir -p "$DMG_SOURCE"

# Sao chép ứng dụng vào thư mục tạm
echo "📋 Đang sao chép ứng dụng vào thư mục tạm..."
cp -R "$APP_PATH" "$DMG_SOURCE/"

# Tạo liên kết mềm tới Applications
ln -s /Applications "$DMG_SOURCE/Applications"

# Tạo DMG bằng hdiutil
echo "💿 Đang tạo tệp DMG..."
rm -f "$OUTPUT_DMG"
TEMP_DMG="gui/build/macos/temp.dmg"
rm -f "$TEMP_DMG"

# Bước 1: Tạo DMG có thể đọc/ghi
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_SOURCE" -ov -format UDRW "$TEMP_DMG"

# Bước 2: Chuyển sang DMG nén chỉ đọc
hdiutil convert "$TEMP_DMG" -format UDZO -o "$OUTPUT_DMG"

# Dọn dẹp
rm -f "$TEMP_DMG"
rm -rf "$DMG_SOURCE"

echo "🎉 Đóng gói hoàn tất!"
echo "📂 Vị trí ứng dụng: $APP_PATH"
echo "💿 Tệp DMG: $OUTPUT_DMG"
