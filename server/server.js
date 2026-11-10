/**
 * BACKEND REST API SERVER CHO BÀI THI GIỮA KỲ LTDĐ (VKU)
 * Hỗ trợ Cơ sở dữ liệu: MongoDB (Mongoose) + Tự động Fallback database.json
 * Sinh viên thực hiện: Trần Thị Ngọc Hà - MSSV: 23IT.B046
 * 
 * QUY TẮC CỐT LÕI: Dữ liệu trả về chỉ gồm đúng 4 trường:
 * - email
 * - matkhau
 * - hoten
 * - hinhanh
 */

const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

const app = express();
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/vku_user_admin';
const DB_FILE = path.join(__dirname, 'database.json');

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// 1. Schema MongoDB tuân thủ nghiêm ngặt 4 trường
const UserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, trim: true },
  matkhau: { type: String, required: true },
  hoten: { type: String, required: true, trim: true },
  hinhanh: { type: String, required: true }
}, {
  timestamps: false,
  versionKey: false,
  toJSON: {
    transform: (doc, ret) => {
      delete ret._id;
      delete ret.__v;
      return ret;
    }
  }
});

const UserModel = mongoose.model('User', UserSchema);

let isMongoConnected = false;

// Đọc dữ liệu từ file JSON nội bộ
function readLocalDb() {
  if (!fs.existsSync(DB_FILE)) {
    const rootDb = path.join(__dirname, '..', 'database.json');
    if (fs.existsSync(rootDb)) {
      return JSON.parse(fs.readFileSync(rootDb, 'utf8'));
    }
    return [];
  }
  return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
}

// Ghi dữ liệu vào file JSON nội bộ
function writeLocalDb(data) {
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf8');
}

// Khởi tạo kết nối MongoDB
mongoose.connect(MONGO_URI, { serverSelectionTimeoutMS: 2000 })
  .then(async () => {
    isMongoConnected = true;
    console.log('✅ Đã kết nối MongoDB thành công!');
    // Nạp dữ liệu mẫu ban đầu nếu collection trống
    const count = await UserModel.countDocuments();
    if (count === 0) {
      const initial = readLocalDb();
      if (initial.length > 0) {
        await UserModel.insertMany(initial);
        console.log(`Đã khởi tạo ${initial.length} người dùng vào MongoDB.`);
      }
    }
  })
  .catch((err) => {
    isMongoConnected = false;
    console.log('⚠️ Không tìm thấy máy chủ MongoDB local, tự động chuyển sang chế độ File Database (JSON) linh hoạt!');
  });

// ==========================================
// ROUTES REST API
// ==========================================

// 1. Lấy danh sách tất cả người dùng (READ)
app.get('/api/users', async (req, res) => {
  try {
    if (isMongoConnected) {
      const users = await UserModel.find({}, { _id: 0, __v: 0 }).lean();
      return res.json(users);
    }
    const users = readLocalDb();
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. Thêm người dùng mới (CREATE)
app.post('/api/users', async (req, res) => {
  try {
    const { email, matkhau, hoten, hinhanh } = req.body;
    if (!email || !matkhau || !hoten || !hinhanh) {
      return res.status(400).json({ error: 'Cần điền đủ 4 trường: email, matkhau, hoten, hinhanh' });
    }

    const cleanUser = {
      email: email.trim().toLowerCase(),
      matkhau: String(matkhau),
      hoten: hoten.trim(),
      hinhanh: hinhanh.trim()
    };

    if (isMongoConnected) {
      const existing = await UserModel.findOne({ email: cleanUser.email });
      if (existing) {
        return res.status(409).json({ error: 'Email này đã tồn tại trong hệ thống!' });
      }
      const created = await UserModel.create(cleanUser);
      return res.status(201).json(created.toJSON());
    }

    const users = readLocalDb();
    if (users.some(u => u.email.toLowerCase() === cleanUser.email)) {
      return res.status(409).json({ error: 'Email này đã tồn tại trong hệ thống!' });
    }
    users.push(cleanUser);
    writeLocalDb(users);
    res.status(201).json(cleanUser);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 3. Sửa thông tin người dùng (UPDATE)
app.put('/api/users/:email', async (req, res) => {
  try {
    const targetEmail = decodeURIComponent(req.params.email).toLowerCase();
    const { email, matkhau, hoten, hinhanh } = req.body;

    const updatedUser = {
      email: (email || targetEmail).trim().toLowerCase(),
      matkhau: String(matkhau),
      hoten: hoten.trim(),
      hinhanh: hinhanh.trim()
    };

    if (isMongoConnected) {
      const user = await UserModel.findOneAndUpdate(
        { email: targetEmail },
        updatedUser,
        { new: true, projection: { _id: 0, __v: 0 } }
      );
      if (!user) {
        return res.status(404).json({ error: 'Không tìm thấy người dùng' });
      }
      return res.json(user);
    }

    const users = readLocalDb();
    const index = users.findIndex(u => u.email.toLowerCase() === targetEmail);
    if (index === -1) {
      return res.status(404).json({ error: 'Không tìm thấy người dùng' });
    }
    users[index] = updatedUser;
    writeLocalDb(users);
    res.json(updatedUser);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 4. Xóa người dùng (DELETE)
app.delete('/api/users/:email', async (req, res) => {
  try {
    const targetEmail = decodeURIComponent(req.params.email).toLowerCase();

    if (isMongoConnected) {
      const result = await UserModel.findOneAndDelete({ email: targetEmail });
      if (!result) {
        return res.status(404).json({ error: 'Không tìm thấy người dùng' });
      }
      return res.json({ message: 'Xóa thành công', email: targetEmail });
    }

    let users = readLocalDb();
    const prevLen = users.length;
    users = users.filter(u => u.email.toLowerCase() !== targetEmail);
    if (users.length === prevLen) {
      return res.status(404).json({ error: 'Không tìm thấy người dùng' });
    }
    writeLocalDb(users);
    res.json({ message: 'Xóa thành công', email: targetEmail });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 5. Đăng nhập Admin
app.post('/api/login', async (req, res) => {
  try {
    const { email, matkhau } = req.body;
    const cleanEmail = (email || '').trim().toLowerCase();

    let user;
    if (isMongoConnected) {
      user = await UserModel.findOne({ email: cleanEmail, matkhau }, { _id: 0, __v: 0 }).lean();
    } else {
      const users = readLocalDb();
      user = users.find(u => u.email.toLowerCase() === cleanEmail && u.matkhau === matkhau);
    }

    if (user) {
      return res.json({ success: true, user });
    }

    if (cleanEmail === 'admin@gmail.com' && matkhau === 'Admin@123') {
      return res.json({
        success: true,
        user: {
          email: 'admin@gmail.com',
          matkhau: 'Admin@123',
          hoten: 'Trần Thị Ngọc Hà (Admin)',
          hinhanh: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500'
        }
      });
    }

    res.status(401).json({ error: 'Sai tài khoản hoặc mật khẩu' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Khởi chạy Server
app.listen(PORT, () => {
  console.log(`🚀 API Server đang chạy tại http://localhost:${PORT}`);
});
