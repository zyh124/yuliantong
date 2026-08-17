# 渔链通 - Flask 版

上海海洋大学大创项目 · B2B 水产品数字化营销平台

## 线上地址

- 主域名：https://yuliantong.online
- 备用：https://yuliantong.onrender.com

## 本地开发

### 1. 环境准备

- Python 3.x
- MySQL（WAMP/XAMPP/Laragon 任选一个，装好就行）
- Git

### 2. 克隆项目

```bash
git clone https://github.com/zyh124/yuliantong.git
cd yuliantong
```

### 3. 安装依赖

```bash
pip install flask pymysql bcrypt
```

### 4. 导入数据库

打开 MySQL，运行 `schema.sql`：

```bash
# 命令行方式
mysql -u root -p < schema.sql

# 或直接在 phpMyAdmin / Navicat 中导入 schema.sql
```

### 5. 运行

```bash
python app.py
```

浏览器打开 `http://localhost:5000`

## 测试账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 管理员 | admin | admin123 |
| 供应商 | supplier1 | admin123 |
| 采购商 | buyer1 | admin123 |

## 项目结构

```
app.py          ← 主程序，45条路由
auth.py         ← 登录验证、角色权限
utils.py        ← 工具函数
schema.sql      ← 数据库（表结构+测试数据）
static/         ← CSS、JS、图片
templates/      ← 25个Jinja2模板
```

## 协作开发

1. 每人 clone 仓库，本地开发
2. 改完 git commit + git push
3. 线上 Render 自动部署
4. 有冲突先 git pull 再合并

## 测试数据说明

schema.sql 中包含 9 条测试商品、4 条订单、3 条溯源记录、29 条操作日志、9 条价格指数，均标注为"测试虚拟数据"。
