#!/usr/bin/env node
// Đồng bộ Cloud Firestore (collection `products`) -> file database.json ở gốc dự án.
//
// App chạy trên Chrome / Android nên không ghi thẳng được vào file trong thư mục
// dự án. Script này đọc dữ liệu THẬT trên Firestore và ghi ra database.json
// (chỉ 4 trường name, price, soluong, image — không kèm ID), nên mỗi lần
// Thêm / Sửa / Xóa trong app thì database.json cũng được cập nhật theo.
//
// Lần đầu (đăng nhập bằng tài khoản ĐÃ XÁC THỰC EMAIL của app):
//   FB_EMAIL=ban@gmail.com FB_PASSWORD=matkhau node tools/sync_database.mjs --watch
// Các lần sau (đã lưu phiên trong tools/.sync_token):
//   node tools/sync_database.mjs --watch     # tự cập nhật liên tục
//   node tools/sync_database.mjs             # ghi 1 lần rồi thoát

import { readFile, writeFile, rename } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const API_KEY = 'AIzaSyA9uSrueiKaP487LoavPB4l0agJlG2kSUE';
const PROJECT_ID = 'vku-product-admin-23itb';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'database.json');
const TOKEN_FILE = path.join(ROOT, 'tools', '.sync_token');
const WATCH = process.argv.includes('--watch');
const INTERVAL_MS = 2000;

let idToken = null;
let idTokenExp = 0;

async function post(url, body, form = false) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': form ? 'application/x-www-form-urlencoded' : 'application/json' },
    body: form ? new URLSearchParams(body) : JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
  return data;
}

async function saveRefresh(token) {
  await writeFile(TOKEN_FILE, token, { mode: 0o600 });
}

async function login() {
  const { FB_EMAIL: email, FB_PASSWORD: password } = process.env;
  if (email && password) {
    const d = await post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
      { email, password, returnSecureToken: true },
    );
    idToken = d.idToken;
    idTokenExp = Date.now() + (Number(d.expiresIn) - 60) * 1000;
    await saveRefresh(d.refreshToken);
    return;
  }
  let refresh;
  try {
    refresh = (await readFile(TOKEN_FILE, 'utf8')).trim();
  } catch {
    throw new Error(
      'Chưa đăng nhập. Chạy lần đầu với: FB_EMAIL=... FB_PASSWORD=... node tools/sync_database.mjs',
    );
  }
  const d = await post(
    `https://securetoken.googleapis.com/v1/token?key=${API_KEY}`,
    { grant_type: 'refresh_token', refresh_token: refresh },
    true,
  );
  idToken = d.id_token;
  idTokenExp = Date.now() + (Number(d.expires_in) - 60) * 1000;
  if (d.refresh_token && d.refresh_token !== refresh) await saveRefresh(d.refresh_token);
}

async function token() {
  if (!idToken || Date.now() > idTokenExp) await login();
  return idToken;
}

function val(v) {
  if (!v) return null;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Math.round(v.doubleValue);
  if ('stringValue' in v) return v.stringValue;
  return null;
}

async function fetchProducts() {
  const docs = [];
  let pageToken = '';
  do {
    const url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/products` +
      `?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${await token()}` } });
    const data = await res.json();
    if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
    docs.push(...(data.documents || []));
    pageToken = data.nextPageToken || '';
  } while (pageToken);

  // Sản phẩm thêm trước đứng trước, thêm sau đứng sau
  docs.sort((a, b) => a.createTime.localeCompare(b.createTime));
  return docs.map(({ fields = {} }) => ({
    name: val(fields.name) ?? '',
    price: val(fields.price) ?? 0,
    soluong: val(fields.soluong) ?? 0,
    image: val(fields.image) ?? '',
  }));
}

let last = null;
async function syncOnce() {
  const products = await fetchProducts();
  const text = JSON.stringify(products, null, 2) + '\n';
  if (text === last) return;
  if (last === null) {
    try {
      if ((await readFile(OUT, 'utf8')) === text) {
        last = text;
        console.log(`[${time()}] database.json đã khớp Firestore (${products.length} sản phẩm)`);
        return;
      }
    } catch {}
  }
  const tmp = OUT + '.tmp';
  await writeFile(tmp, text);
  await rename(tmp, OUT);
  last = text;
  console.log(`[${time()}] Đã ghi database.json (${products.length} sản phẩm)`);
}

const time = () => new Date().toLocaleTimeString('vi-VN');

try {
  await syncOnce();
} catch (e) {
  console.error('Lỗi:', e.message);
  process.exit(1);
}

if (WATCH) {
  console.log('Đang theo dõi Firestore, Ctrl+C để dừng...');
  setInterval(() => syncOnce().catch((e) => console.error(`[${time()}] Lỗi:`, e.message)), INTERVAL_MS);
}
