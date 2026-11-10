# KỊCH BẢN QUAY VIDEO DEMO BÀI THI GIỮA KỲ (3 - 5 PHÚT)
**Học phần:** Phát triển Ứng dụng Đa nền tảng (Flutter)  
**Sinh viên:** Trần Thị Ngọc Hà &bull; **MSSV:** 23IT.B046 &bull; **Lớp:** 23JIT  

---

## 🕒 Phân Bổ Thời Gian Chi Tiết (Tổng cộng ~ 3 phút)

### 1. [0:00 - 0:30] Giới thiệu sinh viên & Tổng quan đề thi
- **Hành động:** Mở trình duyệt Web (hoặc mở màn hình Login).
- **Lời thoại gợi ý:**  
  *"Em xin chào Thầy/Cô! Em tên là Trần Thị Ngọc Hà, mã số sinh viên 23IT.B046, lớp sinh hoạt 23JIT. Hôm nay em xin phép demo bài thi giữa kỳ môn Lập trình đa nền tảng. Đề bài yêu cầu xây dựng ứng dụng quản trị người dùng phân hệ admin chạy trên Web và Di động, kết nối cơ sở dữ liệu Firebase/MongoDB với đúng 4 trường: email, matkhau, hoten, hinhanh."*

### 2. [0:30 - 1:00] Đăng nhập Admin & Hiển thị trên nền tảng Web (8.0 Điểm)
- **Hành động:** 
  1. Bấm nút "Điền nhanh tài khoản Admin" (`admin@gmail.com` / `Admin@123`).
  2. Bấm nút mắt xem ẩn/hiện mật khẩu.
  3. Bấm **"Đăng Nhập Quản Trị"**.
  4. Màn hình chuyển vào Bảng quản trị người dùng (Data Table).
- **Lời thoại gợi ý:**  
  *"Đầu tiên là phân hệ Đăng nhập Admin với validation hợp lệ. Sau khi đăng nhập thành công, hệ thống hiển thị danh sách người dùng trên nền tảng Web dạng Data Table với đầy đủ 4 trường bắt buộc: hinhanh (Avatar), hoten, email, và matkhau có nút che/hiện mật khẩu bảo mật. Phía trên có 3 thẻ KPI thống kê số lượng và trạng thái CSDL."*

### 3. [1:00 - 1:45] Thực hiện Thêm, Sửa, Xóa và Tìm kiếm (1.5 Điểm)
- **Hành động:**
  1. **Thêm mới:** Bấm nút **"+ Thêm Người Dùng"**. Nhập họ tên, email, mật khẩu. Chọn nhanh 1 Avatar có sẵn hoặc bấm nút "Thư viện ảnh". Bấm **"Thêm Mới"** &rarr; Danh sách cập nhật ngay lập tức và tăng số lượng.
  2. **Tìm kiếm (Search):** Gõ tên người dùng vừa tạo vào ô tìm kiếm &rarr; Bảng lọc theo thời gian thực (Live Search).
  3. **Xem chi tiết:** Bấm icon con mắt (👁️) &rarr; Hiện modal thông tin chi tiết.
  4. **Chỉnh sửa (Edit):** Bấm icon cây bút (✏️), sửa họ tên hoặc mật khẩu, bấm **"Lưu Thay Đổi"**.
  5. **Xóa (Delete):** Bấm icon thùng rác (🗑️) &rarr; Xuất hiện hộp thoại xác nhận (Confirm Dialog), bấm **"Xóa Người Dùng"** &rarr; Bản ghi bị xóa ngay tức thì.
- **Lời thoại gợi ý:**  
  *"Tiếp theo em demo các chức năng CRUD: Thêm người dùng với xem trước ảnh avatar trực tiếp, tìm kiếm realtime theo tên hoặc email, mở modal xem chi tiết, chỉnh sửa thông tin và xóa có hộp thoại xác nhận an toàn."*

### 4. [1:45 - 2:20] Thể hiện tính năng Di động & Nhập ảnh trên Mobile (0.5 Điểm)
- **Hành động:**
  1. Thu nhỏ kích thước trình duyệt hoặc mở chế độ F12 Responsive (kích thước Mobile 390x844) hoặc mở Android Emulator.
  2. Giao diện tự động chuyển thành Card List tối ưu cảm ứng.
  3. Thử mở form Thêm người dùng trên mobile và bấm chọn ảnh.
- **Lời thoại gợi ý:**  
  *"Ứng dụng của em được xây dựng hoàn toàn responsive cho đa nền tảng. Khi mở trên di động hoặc màn hình nhỏ, giao diện tự động chuyển sang Card View mượt mà. Người dùng có thể chạm để chọn ảnh từ thư viện hoặc chụp ảnh từ camera thiết bị."*

### 5. [2:20 - 3:00] Cơ sở dữ liệu Firebase & File JSON nộp kèm
- **Hành động:**
  1. Bấm nút **"Xuất Database (JSON)"** trên thanh công cụ để mở xem dữ liệu thô.
  2. Chỉ rõ: Dữ liệu hoàn toàn chỉ gồm 4 trường `email`, `matkhau`, `hoten`, `hinhanh`.
  3. Mở tab Firebase Console Realtime Database hoặc file `database.json`.
- **Lời thoại gợi ý:**  
  *"Cuối cùng là cơ sở dữ liệu: Hệ thống kết nối đồng bộ trực tiếp với Firebase Realtime Database và em cũng chuẩn bị sẵn Backend Node.js MongoDB. Tất cả các bản ghi đều tuân thủ nghiêm ngặt chỉ gồm đúng 4 trường: email, matkhau, hoten, hinhanh không thêm bất kỳ trường nào khác. Em đã xuất kèm file database.json trong hồ sơ nộp bài. Em xin chân thành cảm ơn Thầy/Cô!"*
