
-- CREATE DATABASE IF NOT EXISTS yuliantong DEFAULT CHARSET utf8mb4;
-- USE yuliantong;

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('supplier','buyer','admin') NOT NULL,
  `company_name` varchar(100) DEFAULT NULL,
  `contact_name` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `avatar` varchar(255) DEFAULT NULL,
  `status` enum('active','pending','banned') DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `categories`;
CREATE TABLE `categories` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `parent_id` int DEFAULT '0',
  `sort_order` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `products`;
CREATE TABLE `products` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `category_id` int NOT NULL,
  `name` varchar(100) NOT NULL,
  `origin` varchar(100) DEFAULT NULL COMMENT '产地',
  `spec_desc` text COMMENT '规格描述',
  `price` decimal(10,2) NOT NULL,
  `stock` int NOT NULL DEFAULT '0',
  `unit` varchar(20) DEFAULT '斤' COMMENT '计量单位',
  `min_order` int DEFAULT '1' COMMENT '最小起订量',
  `status` enum('pending','approved','rejected','offline') DEFAULT 'pending',
  `view_count` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `supplier_id` (`supplier_id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `products_ibfk_1` FOREIGN KEY (`supplier_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `products_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `product_images`;
CREATE TABLE `product_images` (
  `id` int NOT NULL AUTO_INCREMENT,
  `product_id` int NOT NULL,
  `image_path` varchar(255) NOT NULL,
  `is_primary` tinyint(1) DEFAULT '0',
  `sort_order` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `product_id` (`product_id`),
  CONSTRAINT `product_images_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `product_templates`;
CREATE TABLE `product_templates` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `name` varchar(100) NOT NULL COMMENT '模板名称',
  `category_id` int DEFAULT NULL,
  `origin` varchar(100) DEFAULT NULL,
  `spec_desc` text,
  `price` decimal(10,2) DEFAULT NULL,
  `stock` int DEFAULT '0',
  `traceability_data` json DEFAULT NULL COMMENT '溯源信息JSON',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `supplier_id` (`supplier_id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `product_templates_ibfk_1` FOREIGN KEY (`supplier_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `product_templates_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `order_no` varchar(32) NOT NULL,
  `buyer_id` int NOT NULL,
  `supplier_id` int NOT NULL,
  `total_amount` decimal(12,2) NOT NULL,
  `status` enum('pending','confirmed','shipped','completed','cancelled') DEFAULT 'pending',
  `receiver_name` varchar(50) DEFAULT NULL,
  `receiver_phone` varchar(20) DEFAULT NULL COMMENT '脱敏存储',
  `receiver_phone_full` varchar(20) DEFAULT NULL COMMENT '完整手机号（加密）',
  `receiver_address` varchar(255) DEFAULT NULL,
  `remark` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_no` (`order_no`),
  KEY `buyer_id` (`buyer_id`),
  KEY `supplier_id` (`supplier_id`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`supplier_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `order_items`;
CREATE TABLE `order_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `order_id` int NOT NULL,
  `product_id` int NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`),
  KEY `product_id` (`product_id`),
  CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `traceability`;
CREATE TABLE `traceability` (
  `id` int NOT NULL AUTO_INCREMENT,
  `product_id` int NOT NULL,
  `breeding_base` varchar(255) DEFAULT NULL COMMENT '养殖基地',
  `geo_location` varchar(255) DEFAULT NULL COMMENT '地理位置',
  `breeding_method` varchar(100) DEFAULT NULL COMMENT '养殖方式（深水网箱/生态围塘/循环水等）',
  `harvest_time` date DEFAULT NULL COMMENT '出塘/捕捞日期',
  `preservation` varchar(50) DEFAULT NULL COMMENT '保鲜方式（冷藏/冷冻/活体运输）',
  `delivery_range` varchar(255) DEFAULT NULL COMMENT '配送范围',
  `geo_certification` varchar(255) DEFAULT NULL COMMENT '地理标志认证',
  `inspection_report_path` varchar(255) DEFAULT NULL COMMENT '检验报告文件路径',
  `video_url` varchar(500) DEFAULT NULL COMMENT '溯源视频URL',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `product_id` (`product_id`),
  CONSTRAINT `traceability_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `operation_logs`;
CREATE TABLE `operation_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `action` varchar(50) NOT NULL,
  `target_type` varchar(50) DEFAULT NULL,
  `target_id` int DEFAULT NULL,
  `detail` text,
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `operation_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP TABLE IF EXISTS `price_index`;
CREATE TABLE `price_index` (
  `id` int NOT NULL AUTO_INCREMENT,
  `category_id` int NOT NULL,
  `origin` varchar(100) DEFAULT NULL COMMENT '产地',
  `period_date` date NOT NULL COMMENT '统计周期日期',
  `avg_price` decimal(10,2) DEFAULT NULL COMMENT '均价',
  `min_price` decimal(10,2) DEFAULT NULL COMMENT '最低价',
  `max_price` decimal(10,2) DEFAULT NULL COMMENT '最高价',
  `sample_count` int DEFAULT '0' COMMENT '样本数量',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `price_index_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- users 数据
INSERT INTO `users` (id,username,password_hash,role,company_name,contact_name,phone,email,address,avatar,status,created_at,updated_at) VALUES (1,'admin','$2y$10$S4OyOr0L6CnT4w.o77w1PuM7ENpWQt7J/yJpS/iira0TXKL/hZmn2','admin','渔链通平台','系统管理员',NULL,NULL,NULL,NULL,'active','2026-06-26 22:25:32','2026-06-26 23:01:28');
INSERT INTO `users` (id,username,password_hash,role,company_name,contact_name,phone,email,address,avatar,status,created_at,updated_at) VALUES (2,'supplier1','$2y$10$S4OyOr0L6CnT4w.o77w1PuM7ENpWQt7J/yJpS/iira0TXKL/hZmn2','supplier','浙江深蓝纪海洋牧业(测试供应商)','赵女士','138****5678','zhao@example.com','浙江省舟山市普陀区',NULL,'active','2026-06-26 22:25:32','2026-06-27 19:38:45');
INSERT INTO `users` (id,username,password_hash,role,company_name,contact_name,phone,email,address,avatar,status,created_at,updated_at) VALUES (3,'supplier2','$2y$10$S4OyOr0L6CnT4w.o77w1PuM7ENpWQt7J/yJpS/iira0TXKL/hZmn2','supplier','崇明璞叶生态养殖基地(测试供应商)','陈先生','139****7890','chen@example.com','上海市崇明区',NULL,'active','2026-06-26 22:25:32','2026-06-27 18:56:14');
INSERT INTO `users` (id,username,password_hash,role,company_name,contact_name,phone,email,address,avatar,status,created_at,updated_at) VALUES (4,'buyer1','$2y$10$S4OyOr0L6CnT4w.o77w1PuM7ENpWQt7J/yJpS/iira0TXKL/hZmn2','buyer','上海海鲜酒楼(测试采购商)','王经理','137****1234','wang@example.com','上海市浦东新区',NULL,'active','2026-06-26 22:25:32','2026-06-27 18:56:14');
INSERT INTO `users` (id,username,password_hash,role,company_name,contact_name,phone,email,address,avatar,status,created_at,updated_at) VALUES (5,'buyer2','$2b$12$YLDRGQU3bNkSJReHvmlZmuUre./bXM5dlE6902gzLPi7GzdHpRZLS','buyer','爱鱼','朱奕慧','18750821849','2805251482@qq.com','上海海洋大学',NULL,'pending','2026-08-10 20:40:00','2026-08-10 20:40:00');

-- categories 数据
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (1,'鱼类',0,1,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (2,'虾蟹类',0,2,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (4,'藻类',0,4,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (5,'其他水产',0,5,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (6,'大黄鱼',1,1,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (7,'带鱼',1,2,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (8,'鲈鱼',1,3,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (9,'石斑鱼',1,4,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (10,'对虾',2,1,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (11,'大闸蟹',2,2,'2026-06-26 22:25:32');
INSERT INTO `categories` (id,name,parent_id,sort_order,created_at) VALUES (12,'梭子蟹',2,3,'2026-06-26 22:25:32');

-- products 数据
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (1,2,6,'舟山深海网箱大黄鱼（特级）','浙江舟山','500-750g/条，色泽金黄，体型修长','68.00',2000,'斤',10,'approved',871,'2026-06-27 18:28:38','2026-07-03 23:17:52');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (2,2,6,'舟山深海网箱大黄鱼（一级）','浙江舟山','350-500g/条，肉质紧实鲜嫩','45.00',3500,'斤',20,'offline',624,'2026-06-27 18:28:38','2026-06-27 19:50:24');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (3,2,7,'东海野生带鱼','浙江舟山','200-300g/条，东海直捕冰鲜','28.00',1500,'斤',15,'offline',412,'2026-06-27 18:28:38','2026-06-27 19:04:25');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (4,2,12,'舟山鲜活梭子蟹','浙江舟山','150-250g/只，当日捕捞鲜活','55.00',800,'斤',5,'offline',733,'2026-06-27 18:28:38','2026-06-27 19:04:25');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (5,2,12,'舟山特级梭子蟹（礼盒）','浙江舟山','250g+/只，精送礼盒装，每盒6只','188.00',300,'盒',1,'offline',389,'2026-06-27 18:28:38','2026-06-27 19:04:25');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (6,3,11,'崇明清水大闸蟹（特级）','上海崇明','200-250g/只，青背白肚金爪黄毛','88.00',1190,'斤',5,'approved',574,'2026-06-27 18:28:38','2026-08-10 20:40:24');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (7,3,11,'崇明清水大闸蟹（一级）','上海崇明','150-200g/只，生态围塘养殖','58.00',2000,'斤',10,'offline',445,'2026-06-27 18:28:38','2026-06-27 19:04:25');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (8,3,10,'崇明南美白对虾','上海崇明','30-40尾/斤，循环水生态养殖','35.00',3000,'斤',20,'approved',526,'2026-06-27 18:28:38','2026-07-03 23:16:53');
INSERT INTO `products` (id,supplier_id,category_id,name,origin,spec_desc,price,stock,unit,min_order,status,view_count,created_at,updated_at) VALUES (9,3,8,'崇明生态鲈鱼','上海崇明','500-800g/条，清水养殖无土腥味','25.00',1800,'斤',10,'offline',298,'2026-06-27 18:28:38','2026-06-27 19:04:25');

-- product_images 数据
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (10,1,'static/images/大黄鱼.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (11,2,'static/images/大黄鱼.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (12,3,'static/images/带鱼.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (13,4,'static/images/梭子蟹.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (14,5,'static/images/梭子蟹.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (15,6,'static/images/大闸蟹.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (16,7,'static/images/大闸蟹.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (17,8,'static/images/南美白对虾.jpg',1,0,'2026-06-27 19:49:48');
INSERT INTO `product_images` (id,product_id,image_path,is_primary,sort_order,created_at) VALUES (18,9,'static/images/舟山黄鱼.jpg',1,0,'2026-06-27 19:49:48');

-- orders 数据
INSERT INTO `orders` (id,order_no,buyer_id,supplier_id,total_amount,status,receiver_name,receiver_phone,receiver_phone_full,receiver_address,remark,created_at,updated_at) VALUES (1,'YLT20260601001',4,2,'3400.00','completed','王经理(测试虚拟数据)','137****1234','13700001234','上海市浦东新区陆家嘴金融中心','【演示数据】','2026-06-29 14:13:54','2026-07-02 14:13:54');
INSERT INTO `orders` (id,order_no,buyer_id,supplier_id,total_amount,status,receiver_name,receiver_phone,receiver_phone_full,receiver_address,remark,created_at,updated_at) VALUES (4,'YLT20260612004',4,2,'1360.00','shipped','王经理(测试虚拟数据)','137****1234','13700001234','上海市浦东新区陆家嘴金融中心','【演示数据】','2026-06-12 08:45:00','2026-06-27 18:56:14');
INSERT INTO `orders` (id,order_no,buyer_id,supplier_id,total_amount,status,receiver_name,receiver_phone,receiver_phone_full,receiver_address,remark,created_at,updated_at) VALUES (6,'YLT20260620006',4,2,'2720.00','confirmed','赵先生(测试虚拟数据)','136****5678','13600005678','浙江省杭州市西湖区文三路188号','【演示数据】','2026-06-20 10:15:00','2026-06-27 18:56:14');
INSERT INTO `orders` (id,order_no,buyer_id,supplier_id,total_amount,status,receiver_name,receiver_phone,receiver_phone_full,receiver_address,remark,created_at,updated_at) VALUES (9,'YLT20260704002456360',4,3,'880.00','completed','张三','187****1849','18750821849','上海海洋大学','测试数据','2026-07-04 00:24:56','2026-07-04 00:26:00');

-- order_items 数据
INSERT INTO `order_items` (id,order_id,product_id,quantity,unit_price,subtotal) VALUES (1,1,1,50,'68.00','3400.00');
INSERT INTO `order_items` (id,order_id,product_id,quantity,unit_price,subtotal) VALUES (8,6,1,40,'68.00','2720.00');
INSERT INTO `order_items` (id,order_id,product_id,quantity,unit_price,subtotal) VALUES (12,9,6,10,'88.00','880.00');

-- traceability 数据
INSERT INTO `traceability` (id,product_id,breeding_base,geo_location,breeding_method,harvest_time,preservation,delivery_range,geo_certification,inspection_report_path,video_url,created_at,updated_at) VALUES (1,1,'舟山普陀桃花岛深水网箱基地','29.93N, 122.30E','深水网箱','2026-06-15','活体运输/冰鲜','长三角地区12小时达','舟山地理标志认证',NULL,'','2026-06-27 18:28:38','2026-06-27 18:28:38');
INSERT INTO `traceability` (id,product_id,breeding_base,geo_location,breeding_method,harvest_time,preservation,delivery_range,geo_certification,inspection_report_path,video_url,created_at,updated_at) VALUES (5,6,'崇明陈家镇璞叶小镇养殖基地','31.50N, 121.73E','生态围塘','2026-06-10','活体运输','上海市及周边','崇明清水蟹地理标志',NULL,'','2026-06-27 18:28:38','2026-06-27 18:28:38');
INSERT INTO `traceability` (id,product_id,breeding_base,geo_location,breeding_method,harvest_time,preservation,delivery_range,geo_certification,inspection_report_path,video_url,created_at,updated_at) VALUES (7,8,'崇明青浦生态养殖场','31.15N, 121.10E','池塘养殖','2026-06-15','活体运输','上海市及周边','',NULL,'','2026-06-27 18:28:38','2026-06-27 18:28:38');

-- operation_logs 数据
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (1,1,'login','user',1,'用户登录','::1','2026-06-26 23:09:55');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (2,1,'logout','user',1,'用户退出','::1','2026-06-26 23:20:59');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (3,2,'login','user',2,'用户登录','::1','2026-06-26 23:21:15');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (4,2,'logout','user',2,'用户退出','::1','2026-06-26 23:21:40');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (5,4,'login','user',4,'用户登录','::1','2026-06-27 18:15:23');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (6,2,'add_product','product',1,'新增商品：舟山深海网箱大黄鱼（特级）',NULL,'2026-06-01 08:00:00');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (7,3,'add_product','product',6,'新增商品：崇明清水大闸蟹（特级）',NULL,'2026-06-02 09:00:00');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (8,4,'place_order','order',1,'下单采购大黄鱼50斤',NULL,'2026-06-01 09:30:00');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (9,4,'place_order','order',6,'下单采购大闸蟹30斤',NULL,'2026-06-08 11:00:00');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (10,1,'login','user',1,'管理员登录系统',NULL,'2026-06-27 10:00:00');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (11,4,'logout','user',4,'用户退出','::1','2026-06-27 18:41:48');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (12,4,'login','user',4,'用户登录','::1','2026-06-27 18:48:13');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (13,4,'logout','user',4,'用户退出','::1','2026-06-27 18:58:42');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (14,4,'login','user',4,'用户登录','::1','2026-06-27 18:58:55');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (15,4,'logout','user',4,'用户退出','::1','2026-06-27 19:06:33');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (16,4,'login','user',4,'用户登录','::1','2026-06-27 19:06:51');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (17,4,'logout','user',4,'用户退出','::1','2026-06-27 19:12:02');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (18,2,'login','user',2,'用户登录','::1','2026-06-27 19:12:13');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (19,2,'logout','user',2,'用户退出','::1','2026-06-27 19:16:08');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (20,4,'login','user',4,'用户登录','::1','2026-06-27 19:16:23');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (21,4,'logout','user',4,'用户退出','::1','2026-06-27 19:19:25');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (22,1,'login','user',1,'用户登录','::1','2026-06-27 19:37:18');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (23,1,'logout','user',1,'用户退出','::1','2026-06-27 19:38:01');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (24,1,'login','user',1,'用户登录','::1','2026-06-27 19:38:38');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (25,1,'ban_user','user',2,'','::1','2026-06-27 19:38:44');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (26,1,'unban_user','user',2,'','::1','2026-06-27 19:38:45');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (27,1,'rereview_product','product',2,'','::1','2026-06-27 19:47:57');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (28,1,'approve_product','product',2,'','::1','2026-06-27 19:48:05');
INSERT INTO `operation_logs` (id,user_id,action,target_type,target_id,detail,ip_address,created_at) VALUES (29,1,'offline_product','product',2,'','::1','2026-06-27 19:50:24');

-- price_index 数据
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (1,6,'浙江舟山','2026-06-01','65.50','55.00','78.00',45,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (2,6,'浙江舟山','2026-06-08','66.20','56.00','80.00',52,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (3,6,'浙江舟山','2026-06-15','68.00','58.00','82.00',48,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (4,6,'浙江舟山','2026-06-22','67.80','57.00','81.00',50,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (5,6,'福建宁德','2026-06-22','22.50','18.00','28.00',38,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (6,11,'上海崇明','2026-06-01','85.00','68.00','98.00',32,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (7,11,'上海崇明','2026-06-15','88.00','72.00','100.00',28,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (8,10,'上海崇明','2026-06-22','35.00','28.00','42.00',35,'2026-06-27 18:28:59');
INSERT INTO `price_index` (id,category_id,origin,period_date,avg_price,min_price,max_price,sample_count,created_at) VALUES (9,7,'浙江舟山','2026-06-22','28.00','22.00','35.00',40,'2026-06-27 18:28:59');

