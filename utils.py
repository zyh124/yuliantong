# -*- coding: utf-8 -*-
"""工具函数库"""

def mask_phone(phone):
    if phone and len(phone) >= 11:
        return phone[:3] + '****' + phone[-4:]
    return '****'

def mask_name(name):
    if not name: return '**'
    return name[0] + '**'

def format_price(price):
    return '¥{:.2f}'.format(float(price))

def time_ago(dt):
    from datetime import datetime
    diff = datetime.now() - dt
    if diff.days > 30: return dt.strftime('%Y-%m-%d')
    if diff.days > 0: return f'{diff.days}天前'
    if diff.seconds > 3600: return f'{diff.seconds//3600}小时前'
    if diff.seconds > 60: return f'{diff.seconds//60}分钟前'
    return '刚刚'
