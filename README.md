# ỨNG DỤNG QUẢN LÝ SẢN PHẨM - PHÂN HỆ ADMIN (FLUTTER)

**Học phần:** Phát triển Ứng dụng Di động Đa nền tảng (7) &bull; **Trường ĐH CNTT & TT Việt - Hàn (VKU)**  
**Sinh viên thực hiện:** Trần Thị Ngọc Hà  
**Mã số sinh viên:** `23IT.B046` &bull; **Lớp sinh hoạt:** `23JIT`  
**Đề thi:** Giữa kỳ - Xây dựng app nhập, hiển thị, sửa, xóa sản phẩm ở phân hệ Admin (Web & Mobile)

---

## 🌟 TỔNG QUAN TÍNH NĂNG

| Chức năng | Chi tiết | Điểm |
| :--- | :--- | :---: |
| **Thêm & hiển thị sản phẩm trên Web** | Bảng sản phẩm trên Web với 4 trường `name`, `price`, `soluong`, `image`, lưu trên **Cloud Firestore** (collection `products`), cập nhật theo thời gian thực | 8.0 |
| **Đăng nhập, Sửa, Xóa & nâng cao** | Đăng ký / Đăng nhập bằng **Firebase Authentication**, có **xác thực email** (Firebase gửi mail xác thực về hộp thư, chưa xác thực thì không vào được), Quên mật khẩu (gửi mail đặt lại). Thêm / Sửa / Xóa (có xác nhận), xem chi tiết, tìm kiếm không dấu, sắp xếp theo tên / giá / số lượng, lọc sắp hết hàng, thống kê tồn kho, **Dashboard phân tích** (biểu đồ tỷ trọng giá trị, tương quan giá – số lượng có hệ số r và đường xu hướng, tỷ trọng số lượng, tình trạng kho, phân loại ABC), Sáng/Tối, xuất `database.json` | 1.5 |
| **Nhập hình ảnh trên di động** | Giao diện thẻ cho điện thoại; chọn ảnh từ Thư viện hoặc Chụp ảnh, ảnh tải lên Cloudinary, link lưu vào trường `image` | 0.5 |

> **Quy định của đề:** CSDL chỉ có 4 trường `name`, `price`, `soluong`, `image`.
> ID document do Firestore tự sinh, không phải trường dữ liệu. Tài khoản đăng nhập nằm trong Firebase Authentication, không lưu trong Firestore.
> `firestore.rules` chặn mọi document có trường khác 4 trường trên và chỉ cho tài khoản **đã xác thực email** đọc/ghi.

---

## 🔐 LUỒNG ĐĂNG KÝ / XÁC THỰC EMAIL

1. Màn hình đăng nhập → **Chưa có tài khoản? Đăng ký ngay** → nhập email + mật khẩu.
2. App tạo tài khoản và Firebase **gửi email xác thực** về hộp thư (xem cả mục Spam). App hiện thông báo "Đã gửi email xác thực tới ...".
3. Bấm link trong email → quay lại app đăng nhập.
4. Nếu đăng nhập khi chưa xác thực: app báo lỗi và có nút **Gửi lại email xác thực**.

---

## 📁 CẤU TRÚC DỰ ÁN

```
flutter_user_admin/
├── database.json                  # File CSDL nộp bài (mảng sản phẩm, 4 trường)
├── firestore.rules                # Luật bảo mật Firestore
├── firebase.json, .firebaserc     # Cấu hình Firebase CLI (project vku-product-admin-23itb)
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart      # Cấu hình Firebase cho Web + Android
│   ├── models/product_model.dart  # Model 4 trường
│   ├── screens/dashboard_screen.dart # Dashboard biểu đồ & tỷ suất
│   ├── screens/                   # login (đăng nhập/đăng ký/quên MK), product_list, product_form, product_detail
│   ├── services/api_service.dart  # CRUD Cloud Firestore
│   ├── services/auth_service.dart # Firebase Auth + xác thực email
│   └── services/image_upload_service.dart # Upload ảnh lên Cloudinary
└── android/app/google-services.json
```

### Thư viện sử dụng
```bash
flutter pub add firebase_core firebase_auth cloud_firestore image_picker http google_fonts fl_chart
npm install -g firebase-tools        # Firebase CLI
firebase deploy --only firestore:rules
```

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY

### 1. Web
```bash
flutter run -d chrome
```
Đăng ký tài khoản → xác thực email → đăng nhập. Lần đầu bấm **↻ Khôi phục dữ liệu mẫu** để nạp 6 sản phẩm mẫu.

### 2. Android Emulator
```bash
flutter emulators --launch Pixel_14
flutter run -d emulator-5554
```

### 3. Kiểm thử
```bash
flutter test
```
