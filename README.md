# 🚗 Circle Traffic 3D (Flutter)

Một tựa game giải đố giao thông 3D nhịp độ nhanh (Traffic Flow Puzzle / Arcade) được xây dựng hoàn toàn bằng **Flutter** kết hợp cùng engine đồ họa **Flutter Scene** (`flutter_scene`). 

Người chơi sẽ hóa thân thành người điều phối giao thông, căn thời điểm chuẩn xác để chạm và thả các phương tiện từ đường nhánh hòa nhập vào các vòng xuyến 3D đa dạng mà không để xảy ra bất kỳ vụ va chạm nào.

---

## 🌟 Tính Năng Nổi Bật

- **100 Màn Chơi Độc Bản (Campaign Mode)**: Trải dài qua 10 khu đô thị với chủ đề riêng biệt (City Center, Neon Cyber, Sunset Coast, Alpine Valley, Industrial Zone, v.v.).
- **6 Chế Độ Chơi Phong Phú**:
  1. **Campaign**: Vượt qua 100 thử thách theo cấp độ tăng dần.
  2. **Endless**: Vòng lặp bất tận với đường đua biến hình linh hoạt theo điểm số và tốc độ tăng dần.
  3. **Time Attack (60s)**: Đua cùng thời gian; mỗi lần nhập làn thành công hoặc xe thoát ra sẽ cộng thêm giây.
  4. **Rush Hour**: Giờ cao điểm với mật độ phương tiện dày đặc, kèm các đợt sóng thay đổi tốc độ đột ngột.
  5. **Boss Rush**: Thử thách liên hoàn 10 màn chơi Boss đỉnh cao (màn 10, 20, ..., 100).
  6. **Police Patrol**: Sử dụng xe cảnh sát đặc nhiệm để chuyển đổi và giải cứu các luồng xe đang bị kẹt cứng.
- **5 Loại Phương Tiện & Hitbox Đa Dạng**: `Mini`, `Car`, `Van`, `Truck`, `Bus` với chiều dài và kích thước bán kính va chạm khác nhau.
- **Vai Trò Phương Tiện Đặc Biệt**:
  - 🟢 **Green Exit Car**: Phương tiện đặc biệt tìm đường thoát ra khỏi vòng xuyến qua lối ra xanh neon.
  - 🚔 **Police Converter Car**: Xe cảnh sát có khả năng "chuyển hóa" phương tiện ùn tắc phía trước thành Green Car để giải phóng mặt đường.
- **7 Cấu Trúc Đường Đua 3D**: Vòng tròn (`Circle`), Bo góc (`Rounded Square`), Bầu dục (`Oval`), `Compact Loop`, `Wide Loop`, Số 8 mặt phẳng và **Số 8 có cầu vượt nâng tầng 3D 2 tầng** (`Figure-8 Overpass Bridge`).
- **Tối Ưu Hóa Hiệu Năng Cao Cho Thiết Bị Thật**:
  - Tách biệt luồng render 3D và UI Flutter HUD thông qua `ValueNotifier` giúp không bị giật lag khi HUD cập nhật.
  - Quỹ đạo đường cong sử dụng bảng tra cứu trước $O(1)$ (**Arc-Length Lookup Table**).
  - Tự động gộp mesh (**Batching**) giảm thiểu tối đa Draw Calls trên GPU.
  - Bộ âm thanh low-latency tích hợp sẵn, phản hồi tức thì khi thao tác chạm.

---

## 🛠️ Yêu Cầu Môi Trường

- **Flutter SDK**: `>= 3.24.0` (khuyến nghị phiên bản mới nhất hỗ trợ `flutter_scene`).
- **Dart SDK**: `^3.13.7` hoặc mới hơn.
- Thiết bị thử nghiệm: Hỗ trợ Android (Vulkan / OpenGL ES), iOS (Metal), macOS, Web.

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Game

### 1. Clone repository về máy

```bash
git clone https://github.com/truonglam101191-creator/circle_traffic_3d.git
cd circle_traffic_3d
```

### 2. Cài đặt các thư viện phụ thuộc

```bash
flutter pub get
```

### 3. Khởi chạy game

- **Chạy trên thiết bị giả lập hoặc máy thật (Debug Mode)**:
  ```bash
  flutter run
  ```

- **Chạy tối ưu hiệu năng tốt nhất trên máy thật (Khuyến nghị Release Mode)**:
  ```bash
  flutter run --release
  ```

### 4. Chạy kiểm thử tự động (Unit / Integration Tests)

```bash
flutter test
```

---

## 📁 Cấu Trúc Thư Mục Chính

```text
circle_traffic_3d/
├── assets/                 # Hình ảnh nền, icon bổ trợ, logo, hiệu ứng
├── lib/
│   ├── game/
│   │   ├── audio/          # Bộ phát âm thanh low-latency
│   │   ├── data/           # Định nghĩa 100 màn chơi, theme khu vực, ngôn ngữ
│   │   ├── math/           # Thuật toán quỹ đạo toán học, spline, va chạm SAT
│   │   ├── model/          # State máy trạng thái game, cấu hình xe, quỹ đạo
│   │   ├── render/         # Render 3D Scene, bộ sinh mesh hoạt hình (CartoonMeshBuilder)
│   │   └── ui/             # Giao diện HUD, hiệu ứng văn bản, bảng chọn màn
│   └── main.dart           # Entry point của ứng dụng
├── test/                   # Toàn bộ test suite kiểm tra logic & 100 màn chơi
└── pubspec.yaml            # Cấu hình dự án & dependencies
```

---

## ⚠️ Lưu Ý Về Việc Sử Dụng Mã Nguồn (License & Usage Notice)

> **Thông báo quan trọng**:
> - **Không cấm việc tham khảo, học tập hoặc copy mã nguồn**: Bạn hoàn toàn có thể tự do clone, sao chép code để học hỏi kỹ thuật render 3D bằng `flutter_scene`, thuật toán toán học quỹ đạo giao thông, hoặc phát triển dự án cá nhân.
> - **YÊU CẦU BẮT BUỘC VỀ GIAO DIỆN**: Nếu bạn sử dụng mã nguồn này để phát hành game hoặc xuất bản sản phẩm thương mại / phi thương mại, **bắt buộc phải thiết kế lại giao diện khác biệt (thay đổi UI, Theme màu sắc, Model 3D/Sprites, Assets và Tên gọi)**. Tuyệt đối **không sao chép nguyên trạng giao diện** để tránh gây hiểu nhầm và không làm ảnh hưởng đến game gốc.
