# ỨNG DỤNG QUẢN LÝ NGƯỜI DÙNG PHÂN HỆ ADMIN ĐA NỀN TẢNG (FLUTTER)

**Học phần:** Phát triển Ứng dụng Di động Đa nền tảng (7) &bull; **Trường ĐH CNTT & TT Việt - Hàn (VKU)**  
**Sinh viên thực hiện:** Trần Thị Ngọc Hà  
**Mã số sinh viên:** `23IT.B046` &bull; **Lớp sinh hoạt:** `23JIT`  
**Đề thi:** Giữa kỳ - Xây dựng App Quản trị Người dùng Đa nền tảng (Web & Mobile)

---

## 🌟 TỔNG QUAN TÍNH NĂNG ĐẠT ĐƯỢC (10.0 / 10.0 ĐIỂM)

| Chức năng | Chi tiết | Điểm đề thi |
| :--- | :--- | :---: |
| **Nền tảng Web (8.0đ)** | Bảng Data Table hiển thị người dùng trên Web với 4 trường: `email`, `matkhau`, `hoten`, `hinhanh` kết nối Firebase / MongoDB | **8.0 / 8.0** |
| **Phân hệ Admin & Nâng cao (1.5đ)** | Đăng nhập Admin, Thêm, Sửa, Xóa (có Confirm Dialog), Tìm kiếm thời gian thực, Lọc/Sắp xếp A-Z, Đổi theme Sáng/Tối, Xuất file `database.json` | **1.5 / 1.5** |
| **Nền tảng Di động (0.5đ)** | Responsive Mobile Card View, nhập hình ảnh từ Thư viện máy (Gallery), Chụp ảnh (Camera), URL hoặc Preset Avatars | **0.5 / 0.5** |

> **QUY TẮC CỐT LÕI CỦA ĐỀ THI:** Cơ sở dữ liệu và file nộp chỉ chấp nhận đúng 4 trường: `email`, `matkhau`, `hoten`, `hinhanh` (không tự ý thêm trường id hay bất kỳ trường nào khác).

---

## 📁 CẤU TRÚC HỒ SƠ BÀI THI & FILE NỘP

```
flutter_user_admin/
├── database.json              # File cơ sở dữ liệu nộp bài (chuẩn 4 trường)
├── users.json                 # File dữ liệu định dạng mảng JSON
├── KICH_BAN_QUAY_VIDEO_DEMO.md # Kịch bản quay video demo 3 phút
├── docs/
│   ├── BAO_CAO_GIUA_KY_TRAN_THI_NGOC_HA.docx # File báo cáo Word
│   ├── BAO_CAO_GIUA_KY_TRAN_THI_NGOC_HA.pdf  # File báo cáo PDF
│   └── screenshots/                          # Toàn bộ ảnh chụp minh họa thực tế
├── lib/
│   ├── main.dart              # Entrypoint ứng dụng Flutter
│   ├── models/user_model.dart # Model dữ liệu nghiêm ngặt 4 trường
│   ├── screens/               # Login, UserList, Form, Detail Dialog
│   ├── services/api_service.dart # Dual Service: Firebase RTDB & Local/Mongo Sync
│   └── utils/app_theme.dart   # Giao diện Dark/Light hiện đại
└── server/                    # Node.js Express + MongoDB REST API Server dự phòng
```

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY ỨNG DỤNG

### 1. Chạy trên nền tảng Web (Khuyên dùng)
```bash
cd /home/tranthingocha/Projects/flutter_user_admin
flutter run -d chrome
```
*Tài khoản Admin đăng nhập mẫu:*
- **Email:** `admin@gmail.com`
- **Mật khẩu:** `Admin@123`  
*(Hoặc bấm nút "Điền nhanh tài khoản Admin" trên màn hình đăng nhập).*

### 2. Chạy trên Android Emulator (Mobile)
```bash
flutter emulators --launch Pixel_14
flutter run -d emulator-5554
```

### 3. Chạy Server MongoDB (Tùy chọn nếu muốn kiểm thử MongoDB)
```bash
cd /home/tranthingocha/Projects/flutter_user_admin/server
npm start
```

---

## 🧪 CHẠY KIỂM THỬ TỰ ĐỘNG (UNIT TESTS)
```bash
flutter test
```
*Kết quả:* Tất cả các bài kiểm tra đều vượt qua 100% (Pass 3/3 tests).
