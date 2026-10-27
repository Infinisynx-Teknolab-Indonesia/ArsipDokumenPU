-- Jalankan sekali sebagai root MySQL, contoh:
--   mysql -u root -p < setup_mysql.sql
-- Tabel dibuat otomatis oleh server saat pertama kali dijalankan.

CREATE DATABASE IF NOT EXISTS arsip_pu CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'arsip'@'localhost' IDENTIFIED BY 'arsip_pu_2026';
GRANT ALL PRIVILEGES ON arsip_pu.* TO 'arsip'@'localhost';
FLUSH PRIVILEGES;
