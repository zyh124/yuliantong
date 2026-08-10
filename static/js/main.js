/**
 * 渔链通 - 全局 JavaScript
 */

document.addEventListener('DOMContentLoaded', function() {
    // 自动隐藏 alert（3秒后淡出）
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(function(alert) {
        setTimeout(function() {
            alert.style.transition = 'opacity 0.5s';
            alert.style.opacity = '0';
            setTimeout(function() { alert.remove(); }, 500);
        }, 5000);
    });

    // 确认删除/操作按钮
    document.querySelectorAll('[data-confirm]').forEach(function(btn) {
        btn.addEventListener('click', function(e) {
            if (!confirm(this.dataset.confirm || '确定要执行此操作吗？')) {
                e.preventDefault();
            }
        });
    });

    // 模态框操作
    document.querySelectorAll('[data-modal]').forEach(function(btn) {
        btn.addEventListener('click', function() {
            const modalId = this.dataset.modal;
            const modal = document.getElementById(modalId);
            if (modal) modal.classList.add('active');
        });
    });

    document.querySelectorAll('.modal-overlay').forEach(function(overlay) {
        overlay.addEventListener('click', function(e) {
            if (e.target === overlay) overlay.classList.remove('active');
        });
    });

    document.querySelectorAll('[data-close-modal]').forEach(function(btn) {
        btn.addEventListener('click', function() {
            const modal = this.closest('.modal-overlay');
            if (modal) modal.classList.remove('active');
        });
    });

    // 手机端导航切换
    const navToggle = document.querySelector('.nav-toggle');
    if (navToggle) {
        navToggle.addEventListener('click', function() {
            document.querySelector('.nav-menu').classList.toggle('active');
        });
    }

    // 搜索表单回车提交
    const searchInput = document.querySelector('.search-input');
    if (searchInput) {
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                const form = this.closest('form');
                if (form) form.submit();
            }
        });
    }

    // 文件上传预览
    const imageInputs = document.querySelectorAll('input[type="file"][data-preview]');
    imageInputs.forEach(function(input) {
        input.addEventListener('change', function() {
            const previewId = this.dataset.preview;
            const preview = document.getElementById(previewId);
            if (!preview) return;

            const file = this.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    if (preview.tagName === 'IMG') {
                        preview.src = e.target.result;
                    } else {
                        preview.style.backgroundImage = 'url(' + e.target.result + ')';
                        preview.style.backgroundSize = 'cover';
                    }
                };
                reader.readAsDataURL(file);
            }
        });
    });

    // 数字输入框增减按钮
    document.querySelectorAll('.qty-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            const input = document.getElementById(this.dataset.target);
            if (!input) return;
            let val = parseInt(input.value) || 1;
            const action = this.dataset.action;
            if (action === 'plus') val++;
            else if (action === 'minus') val = Math.max(1, val - 1);
            input.value = val;
            input.dispatchEvent(new Event('change'));
        });
    });

    // AJAX 通用封装
    window.api = {
        post: function(url, data) {
            return fetch(url, {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: new URLSearchParams(data)
            }).then(function(r) { return r.json(); });
        },
        get: function(url) {
            return fetch(url).then(function(r) { return r.json(); });
        }
    };
});

/**
 * 格式化数字
 */
function formatNumber(n) {
    if (n >= 10000) return (n / 10000).toFixed(2) + '万';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'k';
    return n.toString();
}

/**
 * 格式化价格
 */
function formatPriceYuan(n) {
    return '¥' + parseFloat(n).toFixed(2);
}
