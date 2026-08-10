# -*- coding: utf-8 -*-
"""渔链通 Flask 完整版"""
from flask import Flask, render_template, request, redirect, url_for, session, jsonify
import pymysql, bcrypt, os
from datetime import datetime
from auth import login_required, role_required
from utils import mask_phone, mask_name, format_price, time_ago

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'ylt-secret-2024-shou')

def get_db():
    db_host = os.environ.get('DB_HOST', 'localhost')
    if db_host == 'localhost':
        return pymysql.connect(host='localhost', user='root', password='',
            database='yuliantong', charset='utf8mb4', cursorclass=pymysql.cursors.DictCursor)
    ssl_args = {'ssl': {}} if os.environ.get('DB_SSL') == 'true' else {}
    return pymysql.connect(
        host=db_host,
        user=os.environ.get('DB_USER', ''),
        password=os.environ.get('DB_PASSWORD', ''),
        database=os.environ.get('DB_NAME', 'yuliantong'),
        port=int(os.environ.get('DB_PORT', '3306')),
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor,
        **ssl_args)

@app.context_processor
def inject_globals():
    return dict(session=session, format_price=format_price, mask_phone=mask_phone,
                mask_name=mask_name, time_ago=time_ago)

# ==================== 首页 ====================
@app.route('/')
def index():
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT p.*, u.company_name, (SELECT image_path FROM product_images WHERE product_id=p.id AND is_primary=1 LIMIT 1) AS img FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.status='approved' ORDER BY p.view_count DESC LIMIT 8")
        products = c.fetchall()
    db.close()
    return render_template('index.html', products=products)

# ==================== 登录 / 注册 / 退出 ====================
@app.route('/login', methods=['GET','POST'])
def login():
    error = ''
    if request.method == 'POST':
        u = request.form.get('username','')
        p = request.form.get('password','')
        db = get_db()
        with db.cursor() as c:
            c.execute("SELECT * FROM users WHERE username=%s",(u,))
            user = c.fetchone()
        db.close()
        if not user: error = '用户名不存在'
        elif user['status']=='banned': error = '账号已被禁用'
        elif user['status']=='pending': error = '账号尚未审核，请等待管理员通过'
        elif not bcrypt.checkpw(p.encode('utf-8'), user['password_hash'].encode('utf-8')): error = '密码错误'
        else:
            session['user_id']=user['id']; session['role']=user['role']; session['username']=user['username']
            session['company_name']=user.get('company_name',''); session['contact_name']=user.get('contact_name','')
            m={'supplier':'/supplier','buyer':'/buyer','admin':'/admin'}
            return redirect(m.get(user['role'],'/'))
    return render_template('login.html', error=error)

@app.route('/register', methods=['GET','POST'])
def register():
    error = success = ''
    if request.method == 'POST':
        data = {k: request.form.get(k,'').strip() for k in ['username','password','role','company_name','contact_name','phone','email','address']}
        if len(data['username'])<3: error = '用户名至少3个字符'
        elif not data['username'].replace('_','').isalnum(): error = '用户名只能包含字母数字下划线'
        elif len(data['password'])<6: error = '密码至少6位'
        elif data['role'] not in ('supplier','buyer'): error = '请选择注册角色'
        elif not data['company_name']: error = '企业名称不能为空'
        elif not data['contact_name']: error = '联系人不能为空'
        elif not data['phone'] or len(data['phone'])!=11: error = '请输入正确的11位手机号'
        elif not data.get('email') or '@' not in data['email']: error = '请输入正确的邮箱'
        elif not data['address']: error = '地址不能为空'
        else:
            db = get_db()
            with db.cursor() as c:
                c.execute("SELECT id FROM users WHERE username=%s",(data['username'],))
                if c.fetchone(): error = '用户名已被注册'
            if not error:
                h = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                with db.cursor() as c:
                    c.execute("INSERT INTO users (username,password_hash,role,company_name,contact_name,phone,email,address,status) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'pending')",
                        (data['username'],h.decode(),data['role'],data['company_name'],data['contact_name'],data['phone'],data['email'],data['address']))
                db.commit()
                success = '注册成功，请等待管理员审核'
            db.close()
    return render_template('register.html', error=error, success=success)

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')

# ==================== 公开浏览 ====================
@app.route('/catalog')
def catalog():
    kw = request.args.get('keyword',''); cat = request.args.get('category','')
    db = get_db()
    sql = "SELECT p.*, u.company_name, (SELECT image_path FROM product_images WHERE product_id=p.id AND is_primary=1 LIMIT 1) AS img FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.status='approved'"
    params = []
    if kw:
        sql += " AND (p.name LIKE %s OR p.origin LIKE %s)"
        params.extend([f'%{kw}%',f'%{kw}%'])
    if cat:
        sql += " AND p.category_id=%s"; params.append(cat)
    sql += " ORDER BY p.created_at DESC LIMIT 20"
    with db.cursor() as c: c.execute(sql,params); products=c.fetchall()
    db.close()
    return render_template('catalog.html', products=products, keyword=kw)

# ==================== 采购商端 ====================
@app.route('/buyer')
@login_required
@role_required('buyer')
def buyer_dash():
    db = get_db()
    uid = session['user_id']
    with db.cursor() as c:
        c.execute("SELECT COUNT(*) as cnt FROM orders WHERE buyer_id=%s",(uid,))
        my_orders = c.fetchone()['cnt']
        c.execute("SELECT p.*, u.company_name, (SELECT image_path FROM product_images WHERE product_id=p.id AND is_primary=1 LIMIT 1) AS img FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.status='approved' ORDER BY p.view_count DESC LIMIT 8")
        hot = c.fetchall()
        c.execute("SELECT p.*, u.company_name, (SELECT image_path FROM product_images WHERE product_id=p.id AND is_primary=1 LIMIT 1) AS img FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.status='approved' ORDER BY p.created_at DESC LIMIT 8")
        new_p = c.fetchall()
    db.close()
    return render_template('buyer/dashboard.html', my_orders=my_orders, hot=hot, new_p=new_p)

@app.route('/buyer/search')
@login_required
@role_required('buyer')
def buyer_search():
    kw = request.args.get('keyword',''); cat = request.args.get('category','')
    db = get_db()
    sql = "SELECT p.*, u.company_name, (SELECT image_path FROM product_images WHERE product_id=p.id AND is_primary=1 LIMIT 1) AS img FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.status='approved'"
    params = []
    if kw:
        sql += " AND (p.name LIKE %s OR p.origin LIKE %s)"
        params.extend([f'%{kw}%',f'%{kw}%'])
    if cat:
        sql += " AND p.category_id=%s"; params.append(cat)
    sql += " ORDER BY p.created_at DESC LIMIT 30"
    with db.cursor() as c: c.execute(sql,params); products=c.fetchall()
    db.close()
    return render_template('buyer/search.html', products=products, keyword=kw)

@app.route('/buyer/product/<int:pid>', methods=['GET','POST'])
@login_required
def buyer_product_detail(pid):
    db = get_db()
    msg = ''
    with db.cursor() as c:
        c.execute("SELECT p.*, u.company_name FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.id=%s AND p.status='approved'",(pid,))
        p = c.fetchone()
        if not p: db.close(); return redirect('/buyer/search')
        c.execute("UPDATE products SET view_count=view_count+1 WHERE id=%s",(pid,))
        c.execute("SELECT * FROM product_images WHERE product_id=%s ORDER BY is_primary DESC",(pid,))
        imgs = c.fetchall()
        c.execute("SELECT * FROM traceability WHERE product_id=%s",(pid,))
        trace = c.fetchone()
    db.commit()

    if request.method == 'POST':
        qty = int(request.form.get('quantity',1))
        if qty > p['stock']: msg = '库存不足'
        else:
            import random
            order_no = 'YLT'+datetime.now().strftime('%Y%m%d%H%M%S')+str(random.randint(1000,9999))
            total = qty * p['price']
            with db.cursor() as c:
                c.execute("INSERT INTO orders (order_no,buyer_id,supplier_id,total_amount,status,receiver_name,receiver_phone,receiver_phone_full,receiver_address,remark) VALUES (%s,%s,%s,%s,'pending',%s,%s,%s,%s,%s)",
                    (order_no,session['user_id'],p['supplier_id'],total,request.form.get('receiver_name',''),mask_phone(request.form.get('receiver_phone','')),request.form.get('receiver_phone',''),request.form.get('receiver_address',''),request.form.get('remark','')))
                oid = c.lastrowid
                c.execute("INSERT INTO order_items (order_id,product_id,quantity,unit_price,subtotal) VALUES (%s,%s,%s,%s,%s)",(oid,pid,qty,p['price'],total))
                c.execute("UPDATE products SET stock=stock-%s WHERE id=%s",(qty,pid))
            db.commit()
            db.close()
            return redirect('/buyer/orders')
    db.close()
    return render_template('buyer/product_detail.html', product=p, images=imgs, trace=trace, msg=msg)

@app.route('/buyer/orders')
@login_required
@role_required('buyer')
def buyer_orders():
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT o.*, u.company_name AS supplier_name FROM orders o JOIN users u ON o.supplier_id=u.id WHERE o.buyer_id=%s ORDER BY o.created_at DESC",(session['user_id'],))
        orders = c.fetchall()
    db.close()
    return render_template('buyer/orders.html', orders=orders)

@app.route('/buyer/order/<int:oid>')
@login_required
@role_required('buyer')
def buyer_order_detail(oid):
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT o.*, u.company_name AS supplier_name FROM orders o JOIN users u ON o.supplier_id=u.id WHERE o.id=%s AND o.buyer_id=%s",(oid,session['user_id']))
        o = c.fetchone()
        if not o: db.close(); return redirect('/buyer/orders')
        c.execute("SELECT oi.*, p.name AS product_name, p.origin FROM order_items oi JOIN products p ON oi.product_id=p.id WHERE oi.order_id=%s",(oid,))
        items = c.fetchall()
    db.close()
    return render_template('buyer/order_detail.html', order=o, items=items)

@app.route('/buyer/order/<int:oid>/cancel')
@login_required
@role_required('buyer')
def buyer_cancel_order(oid):
    db = get_db()
    with db.cursor() as c:
        c.execute("UPDATE orders SET status='cancelled' WHERE id=%s AND buyer_id=%s AND status='pending'",(oid,session['user_id']))
    db.commit(); db.close()
    return redirect('/buyer/orders')

@app.route('/buyer/profile', methods=['GET','POST'])
@login_required
@role_required('buyer')
def buyer_profile():
    db = get_db()
    msg = ''
    if request.method == 'POST':
        with db.cursor() as c:
            c.execute("UPDATE users SET company_name=%s, contact_name=%s, phone=%s, email=%s, address=%s WHERE id=%s",
                (request.form.get('company_name',''),request.form.get('contact_name',''),request.form.get('phone',''),request.form.get('email',''),request.form.get('address',''),session['user_id']))
        db.commit()
        msg = '信息已更新'
    with db.cursor() as c:
        c.execute("SELECT * FROM users WHERE id=%s",(session['user_id'],))
        user = c.fetchone()
    db.close()
    return render_template('buyer/profile.html', user=user, msg=msg)

# ==================== 供应商端 ====================
@app.route('/supplier')
@login_required
@role_required('supplier')
def supplier_dash():
    sid = session['user_id']; db = get_db()
    with db.cursor() as c:
        c.execute("SELECT COUNT(*) as cnt FROM products WHERE supplier_id=%s AND status='approved'",(sid,))
        pc = c.fetchone()['cnt']
        c.execute("SELECT COUNT(*) as cnt FROM orders WHERE supplier_id=%s",(sid,))
        oc = c.fetchone()['cnt']
        c.execute("SELECT COALESCE(SUM(total_amount),0) as s FROM orders WHERE supplier_id=%s AND status IN ('confirmed','shipped','completed')",(sid,))
        ts = c.fetchone()['s']
        c.execute("SELECT COUNT(*) as cnt FROM orders WHERE supplier_id=%s AND status='pending'",(sid,))
        pend = c.fetchone()['cnt']
        c.execute("SELECT status, COUNT(*) as cnt FROM orders WHERE supplier_id=%s GROUP BY status",(sid,))
        status_data = c.fetchall()
        c.execute("SELECT p.name, COALESCE(SUM(oi.quantity),0) as qty FROM products p LEFT JOIN order_items oi ON p.id=oi.product_id WHERE p.supplier_id=%s AND p.status='approved' GROUP BY p.id ORDER BY qty DESC",(sid,))
        pie_data = c.fetchall()
        c.execute("SELECT o.*, u.company_name AS buyer_name FROM orders o JOIN users u ON o.buyer_id=u.id WHERE o.supplier_id=%s ORDER BY o.created_at DESC LIMIT 5",(sid,))
        recent = c.fetchall()
        c.execute("SELECT p.name,p.price,COUNT(oi.id) as oc,COALESCE(SUM(oi.quantity),0) as tq FROM products p LEFT JOIN order_items oi ON p.id=oi.product_id WHERE p.supplier_id=%s GROUP BY p.id ORDER BY tq DESC LIMIT 5",(sid,))
        top = c.fetchall()
    db.close()
    return render_template('supplier/dashboard.html', pc=pc, oc=oc, ts=ts, pend=pend, status_data=status_data, pie_data=pie_data, recent=recent, top=top)

@app.route('/supplier/products')
@login_required
@role_required('supplier')
def supplier_products():
    sid = session['user_id']; db = get_db()
    st = request.args.get('status',''); q = request.args.get('search','')
    sql = "SELECT p.*, c.name AS cat_name FROM products p LEFT JOIN categories c ON p.category_id=c.id WHERE p.supplier_id=%s"
    params = [sid]
    if st: sql += " AND p.status=%s"; params.append(st)
    if q: sql += " AND p.name LIKE %s"; params.append(f'%{q}%')
    sql += " ORDER BY p.created_at DESC"
    with db.cursor() as c: c.execute(sql,params); products=c.fetchall()
    db.close()
    return render_template('supplier/products.html', products=products, status=st, search=q)

@app.route('/supplier/product/offline/<int:pid>')
@login_required
@role_required('supplier')
def supplier_offline(pid):
    db = get_db()
    with db.cursor() as c:
        c.execute("UPDATE products SET status='offline' WHERE id=%s AND supplier_id=%s",(pid,session['user_id']))
    db.commit(); db.close()
    return redirect('/supplier/products')

@app.route('/supplier/product/online/<int:pid>')
@login_required
@role_required('supplier')
def supplier_online(pid):
    db = get_db()
    with db.cursor() as c:
        c.execute("UPDATE products SET status='approved' WHERE id=%s AND supplier_id=%s",(pid,session['user_id']))
    db.commit(); db.close()
    return redirect('/supplier/products')

@app.route('/supplier/product/add', methods=['GET','POST'])
@app.route('/supplier/product/edit/<int:pid>', methods=['GET','POST'])
@login_required
@role_required('supplier')
def supplier_product_add(pid=None):
    db = get_db(); msg = ''; err = ''; product = None; trace = None; images = []
    with db.cursor() as c:
        c.execute("SELECT id,name,parent_id FROM categories ORDER BY parent_id, sort_order")
        cats = c.fetchall()
    if pid:
        with db.cursor() as c:
            c.execute("SELECT * FROM products WHERE id=%s AND supplier_id=%s",(pid,session['user_id']))
            product = c.fetchone()
            if not product: db.close(); return redirect('/supplier/products')
            c.execute("SELECT * FROM traceability WHERE product_id=%s",(pid,))
            trace = c.fetchone()
            c.execute("SELECT * FROM product_images WHERE product_id=%s",(pid,))
            images = c.fetchall()
    if request.method == 'POST':
        name = request.form.get('name','')
        price = float(request.form.get('price',0))
        if not name or price <= 0: err = '商品名称和价格必填'
        else:
            params = (name,int(request.form.get('category_id',0)),request.form.get('origin',''),request.form.get('spec_desc',''),price,int(request.form.get('stock',0)),request.form.get('unit','斤'),int(request.form.get('min_order',1)))
            with db.cursor() as c:
                if pid:
                    c.execute("UPDATE products SET name=%s,category_id=%s,origin=%s,spec_desc=%s,price=%s,stock=%s,unit=%s,min_order=%s,status='pending',updated_at=NOW() WHERE id=%s AND supplier_id=%s",params+(pid,session['user_id']))
                else:
                    c.execute("INSERT INTO products (supplier_id,name,category_id,origin,spec_desc,price,stock,unit,min_order,status) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'pending')",(session['user_id'],)+params)
                    pid = c.lastrowid
                tvals = (request.form.get('breeding_base',''),request.form.get('geo_location',''),request.form.get('breeding_method',''),request.form.get('harvest_time') or None,request.form.get('preservation',''),request.form.get('delivery_range',''),request.form.get('geo_certification',''))
                c.execute("SELECT id FROM traceability WHERE product_id=%s",(pid,))
                if c.fetchone():
                    c.execute("UPDATE traceability SET breeding_base=%s,geo_location=%s,breeding_method=%s,harvest_time=%s,preservation=%s,delivery_range=%s,geo_certification=%s WHERE product_id=%s",tvals+(pid,))
                else:
                    c.execute("INSERT INTO traceability (product_id,breeding_base,geo_location,breeding_method,harvest_time,preservation,delivery_range,geo_certification) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",(pid,)+tvals)
                # Image upload
                file = request.files.get('product_image')
                if file and file.filename:
                    import os, time
                    ext = file.filename.rsplit('.',1)[-1].lower()
                    if ext in ('jpg','jpeg','png','gif','webp'):
                        fname = f'{int(time.time())}_{os.urandom(4).hex()}.{ext}'
                        filepath = os.path.join('static','images',fname)
                        file.save(filepath)
                        c.execute("INSERT INTO product_images (product_id,image_path,is_primary,sort_order) VALUES (%s,%s,%s,%s)",(pid,f'static/images/{fname}',1 if not images else 0,0))
            db.commit()
            msg = '商品已更新，等待审核' if product else '商品已添加，等待审核'
            if pid: return redirect(f'/supplier/product/edit/{pid}')
    db.close()
    return render_template('supplier/product_add.html', cats=cats, product=product, trace=trace, images=images, msg=msg, err=err)

@app.route('/supplier/product/<int:pid>/delimg/<int:iid>')
@login_required
@role_required('supplier')
def supplier_del_image(pid, iid):
    import os
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT pi.image_path FROM product_images pi JOIN products p ON pi.product_id=p.id WHERE pi.id=%s AND p.supplier_id=%s",(iid,session['user_id']))
        img = c.fetchone()
        if img:
            fpath = img['image_path']
            if os.path.exists(fpath): os.remove(fpath)
            c.execute("DELETE FROM product_images WHERE id=%s",(iid,))
    db.commit(); db.close()
    return redirect(f'/supplier/product/edit/{pid}')

@app.route('/supplier/orders')
@login_required
@role_required('supplier')
def supplier_orders():
    sid = session['user_id']; db = get_db()
    st = request.args.get('status','')
    sql = "SELECT o.*, u.company_name AS buyer_name FROM orders o JOIN users u ON o.buyer_id=u.id WHERE o.supplier_id=%s"
    params = [sid]
    if st: sql += " AND o.status=%s"; params.append(st)
    sql += " ORDER BY o.created_at DESC"
    with db.cursor() as c: c.execute(sql,params); orders=c.fetchall()
    db.close()
    return render_template('supplier/orders.html', orders=orders, status=st)

@app.route('/supplier/order/<int:oid>')
@login_required
@role_required('supplier')
def supplier_order_detail(oid):
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT o.*, u.company_name AS buyer_name FROM orders o JOIN users u ON o.buyer_id=u.id WHERE o.id=%s AND o.supplier_id=%s",(oid,session['user_id']))
        o = c.fetchone()
        if not o: db.close(); return redirect('/supplier/orders')
        c.execute("SELECT oi.*, p.name AS product_name, p.origin FROM order_items oi JOIN products p ON oi.product_id=p.id WHERE oi.order_id=%s",(oid,))
        items = c.fetchall()
    db.close()
    return render_template('supplier/order_detail.html', order=o, items=items)

@app.route('/supplier/order/<int:oid>/<action>')
@login_required
@role_required('supplier')
def supplier_order_action(oid, action):
    transitions = {'confirm':('pending','confirmed'),'ship':('confirmed','shipped'),'complete':('shipped','completed')}
    if action not in transitions: return redirect('/supplier/orders')
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT status FROM orders WHERE id=%s AND supplier_id=%s",(oid,session['user_id']))
        o = c.fetchone()
        if o and o['status']==transitions[action][0]:
            c.execute("UPDATE orders SET status=%s WHERE id=%s",(transitions[action][1],oid))
    db.commit(); db.close()
    return redirect('/supplier/orders')

@app.route('/supplier/traceability', methods=['GET','POST'])
@login_required
@role_required('supplier')
def supplier_trace():
    sid = session['user_id']; db = get_db()
    if request.method == 'POST':
        pid = int(request.form.get('product_id',0))
        with db.cursor() as c:
            c.execute("SELECT id FROM products WHERE id=%s AND supplier_id=%s",(pid,sid))
            if c.fetchone():
                c.execute("SELECT id FROM traceability WHERE product_id=%s",(pid,))
                if c.fetchone():
                    c.execute("UPDATE traceability SET breeding_base=%s,geo_location=%s,breeding_method=%s,harvest_time=%s,preservation=%s,delivery_range=%s,geo_certification=%s WHERE product_id=%s",
                        (request.form.get('breeding_base',''),request.form.get('geo_location',''),request.form.get('breeding_method',''),request.form.get('harvest_time') or None,request.form.get('preservation',''),request.form.get('delivery_range',''),request.form.get('geo_certification',''),pid))
                else:
                    c.execute("INSERT INTO traceability (product_id,breeding_base,geo_location,breeding_method,harvest_time,preservation,delivery_range,geo_certification) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                        (pid,request.form.get('breeding_base',''),request.form.get('geo_location',''),request.form.get('breeding_method',''),request.form.get('harvest_time') or None,request.form.get('preservation',''),request.form.get('delivery_range',''),request.form.get('geo_certification','')))
        db.commit()
        return redirect('/supplier/traceability')
    with db.cursor() as c:
        c.execute("SELECT p.id,p.name,p.origin,t.* FROM products p LEFT JOIN traceability t ON p.id=t.product_id WHERE p.supplier_id=%s AND p.status='approved'",(sid,))
        products = c.fetchall()
    db.close()
    return render_template('supplier/traceability.html', products=products)

@app.route('/supplier/profile', methods=['GET','POST'])
@login_required
@role_required('supplier')
def supplier_profile():
    db = get_db(); msg = ''
    if request.method == 'POST':
        with db.cursor() as c:
            c.execute("UPDATE users SET company_name=%s, contact_name=%s, phone=%s, email=%s, address=%s WHERE id=%s",
                (request.form.get('company_name',''),request.form.get('contact_name',''),request.form.get('phone',''),request.form.get('email',''),request.form.get('address',''),session['user_id']))
        db.commit(); msg = '信息已更新'
    with db.cursor() as c: c.execute("SELECT * FROM users WHERE id=%s",(session['user_id'],)); user = c.fetchone()
    db.close()
    return render_template('supplier/profile.html', user=user, msg=msg)

# ==================== 管理端 ====================
@app.route('/admin')
@login_required
@role_required('admin')
def admin_dash():
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT COUNT(*) as c FROM users"); tu = c.fetchone()['c']
        c.execute("SELECT COUNT(*) as c FROM users WHERE role='supplier'"); sc = c.fetchone()['c']
        c.execute("SELECT COUNT(*) as c FROM users WHERE role='buyer'"); bc = c.fetchone()['c']
        c.execute("SELECT COUNT(*) as c FROM products"); tp = c.fetchone()['c']
        c.execute("SELECT COUNT(*) as c FROM products WHERE status='pending'"); pp = c.fetchone()['c']
        c.execute("SELECT COUNT(*) as c FROM orders"); to = c.fetchone()['c']
        c.execute("SELECT COALESCE(SUM(total_amount),0) as s FROM orders WHERE status IN ('confirmed','shipped','completed')"); gmv = c.fetchone()['s']
        c.execute("SELECT p.name,COUNT(oi.id) as sales FROM products p LEFT JOIN order_items oi ON p.id=oi.product_id GROUP BY p.id ORDER BY sales DESC LIMIT 10"); top_p = c.fetchall()
        c.execute("SELECT o.*, us.company_name AS sn, ub.company_name AS bn FROM orders o JOIN users us ON o.supplier_id=us.id JOIN users ub ON o.buyer_id=ub.id ORDER BY o.created_at DESC LIMIT 5"); recent = c.fetchall()
    db.close()
    return render_template('admin/dashboard.html', tu=tu, sc=sc, bc=bc, tp=tp, pp=pp, to=to, gmv=gmv, top_p=top_p, recent=recent)

@app.route('/admin/users')
@login_required
@role_required('admin')
def admin_users():
    db = get_db(); st = request.args.get('status',''); rl = request.args.get('role','')
    sql = "SELECT * FROM users WHERE role!='admin'"; params = []
    if st: sql += " AND status=%s"; params.append(st)
    if rl: sql += " AND role=%s"; params.append(rl)
    sql += " ORDER BY created_at DESC"
    with db.cursor() as c: c.execute(sql,params); users=c.fetchall()
    db.close()
    return render_template('admin/users.html', users=users, status=st, role=rl)

@app.route('/admin/user/<int:uid>')
@login_required
@role_required('admin')
def admin_user_detail(uid):
    db = get_db()
    with db.cursor() as c: c.execute("SELECT * FROM users WHERE id=%s",(uid,)); u = c.fetchone()
    db.close()
    if not u: return redirect('/admin/users')
    return render_template('admin/user_detail.html', u=u)

@app.route('/admin/user/<int:uid>/<action>')
@login_required
@role_required('admin')
def admin_user_action(uid, action):
    db = get_db()
    actions = {'approve':'active','ban':'banned','unban':'active'}
    if action in actions:
        with db.cursor() as c: c.execute("UPDATE users SET status=%s WHERE id=%s AND role!='admin'",(actions[action],uid))
    db.commit(); db.close()
    return redirect('/admin/users')

@app.route('/admin/products')
@login_required
@role_required('admin')
def admin_products():
    db = get_db(); st = request.args.get('status','')
    sql = "SELECT p.*, u.company_name FROM products p JOIN users u ON p.supplier_id=u.id"; params = []
    if st: sql += " WHERE p.status=%s"; params.append(st)
    sql += " ORDER BY CASE WHEN p.status='pending' THEN 0 ELSE 1 END, p.created_at DESC"
    with db.cursor() as c: c.execute(sql,params); products=c.fetchall()
    db.close()
    return render_template('admin/products.html', products=products, status=st)

@app.route('/admin/product/<int:pid>/<action>')
@login_required
@role_required('admin')
def admin_product_action(pid, action):
    db = get_db()
    actions = {'approve':'approved','reject':'rejected','offline':'offline','online':'approved','rereview':'pending'}
    if action in actions:
        with db.cursor() as c: c.execute("UPDATE products SET status=%s, updated_at=NOW() WHERE id=%s",(actions[action],pid))
    db.commit(); db.close()
    return redirect('/admin/products')

@app.route('/admin/product/<int:pid>')
@login_required
@role_required('admin')
def admin_product_detail(pid):
    db = get_db()
    with db.cursor() as c:
        c.execute("SELECT p.*, u.company_name FROM products p JOIN users u ON p.supplier_id=u.id WHERE p.id=%s",(pid,))
        p = c.fetchone()
        if not p: db.close(); return redirect('/admin/products')
        c.execute("SELECT * FROM product_images WHERE product_id=%s",(pid,))
        imgs = c.fetchall()
        c.execute("SELECT * FROM traceability WHERE product_id=%s",(pid,))
        trace = c.fetchone()
    db.close()
    return render_template('admin/product_detail.html', product=p, images=imgs, trace=trace)

@app.route('/admin/orders')
@login_required
@role_required('admin')
def admin_orders():
    db = get_db(); st = request.args.get('status','')
    sql = "SELECT o.*, us.company_name AS sn, ub.company_name AS bn FROM orders o JOIN users us ON o.supplier_id=us.id JOIN users ub ON o.buyer_id=ub.id"
    params = []
    if st: sql += " WHERE o.status=%s"; params.append(st)
    sql += " ORDER BY o.created_at DESC"
    with db.cursor() as c: c.execute(sql,params); orders=c.fetchall()
    db.close()
    return render_template('admin/orders.html', orders=orders, status=st)

@app.route('/admin/reports')
@login_required
@role_required('admin')
def admin_reports():
    db = get_db()
    with db.cursor() as c:
        today = datetime.now().strftime('%Y-%m-%d')
        c.execute("SELECT COUNT(*), COALESCE(SUM(total_amount),0) FROM orders WHERE DATE(created_at)=%s AND status!='cancelled'",(today,))
        r = c.fetchone()
        t_orders, t_gmv = r['COUNT(*)'], r['COALESCE(SUM(total_amount),0)']
        c.execute("SELECT COUNT(*), COALESCE(SUM(total_amount),0) FROM orders WHERE created_at>=%s AND status!='cancelled'",(datetime.now().strftime('%Y-%m-01'),))
        r = c.fetchone()
        m_orders, m_gmv = r['COUNT(*)'], r['COALESCE(SUM(total_amount),0)']
        c.execute("SELECT DATE_FORMAT(created_at,'%Y-%m') as m, COUNT(*) as c, COALESCE(SUM(total_amount),0) as g FROM orders WHERE status!='cancelled' GROUP BY m ORDER BY m DESC LIMIT 6")
        monthly = c.fetchall()
        c.execute("SELECT c.name, COUNT(oi.id) as sales, COALESCE(SUM(oi.quantity),0) as qty FROM categories c INNER JOIN products p ON p.category_id=c.id INNER JOIN order_items oi ON oi.product_id=p.id INNER JOIN orders o ON oi.order_id=o.id AND o.status!='cancelled' WHERE c.parent_id!=0 GROUP BY c.id ORDER BY qty DESC, c.id ASC")
        cat_stats = c.fetchall()
    db.close()
    return render_template('admin/reports.html', t_orders=t_orders, t_gmv=t_gmv, m_orders=m_orders, m_gmv=m_gmv, monthly=monthly, cat_stats=cat_stats)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', debug=False, port=port)
