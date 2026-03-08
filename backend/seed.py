"""
Run with:  python manage.py shell < seed.py
Creates a test admin user + sample inventory items + customers.
"""
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pharmapi.settings')
django.setup()

from authapp.models import PharmUser
from inventory.models import Item
from customers.models import Customer

# ── Admin user ───────────────────────────────────────────────────────────────
if not PharmUser.objects.filter(phone_number='08000000000').exists():
    PharmUser.objects.create_superuser(
        phone_number='08000000000',
        password='admin1234',
    )
    print('Admin created: 08000000000 / admin1234')
else:
    print('Admin already exists.')

# ── Sample items ─────────────────────────────────────────────────────────────
items = [
    dict(name='Paracetamol 500mg', brand='GSK', dosage_form='Tablet',  price=150,  stock=200, low_stock_threshold=20, barcode='PAR500'),
    dict(name='Amoxicillin 250mg', brand='Pfizer', dosage_form='Capsule', price=350, stock=80, low_stock_threshold=15, barcode='AMX250'),
    dict(name='Ibuprofen 400mg',   brand='Bayer', dosage_form='Tablet',  price=200,  stock=5,  low_stock_threshold=20, barcode='IBU400'),
    dict(name='Vitamin C 1000mg',  brand='Seven Seas', dosage_form='Tablet', price=500, stock=150, low_stock_threshold=10, barcode='VTC1000'),
    dict(name='Metformin 500mg',   brand='Teva',  dosage_form='Tablet',  price=120,  stock=60, low_stock_threshold=10, barcode='MET500'),
    dict(name='Lisinopril 10mg',   brand='Zenith', dosage_form='Tablet', price=250, stock=3,  low_stock_threshold=15, barcode='LIS10'),
]
for d in items:
    Item.objects.get_or_create(barcode=d['barcode'], defaults=d)
print(f'{len(items)} items seeded.')

# ── Sample customers ──────────────────────────────────────────────────────────
customers = [
    dict(name='John Okafor',  phone='08011111111', is_wholesale=False, wallet_balance=5000),
    dict(name='Amina Bello',  phone='08022222222', is_wholesale=False, wallet_balance=2500),
    dict(name='Lagos Pharma Supplies', phone='08033333333', is_wholesale=True,  wallet_balance=50000),
    dict(name='Fatima Umar',  phone='08044444444', is_wholesale=False, wallet_balance=0),
    dict(name='MedBulk Ltd',  phone='08055555555', is_wholesale=True,  wallet_balance=100000),
]
for d in customers:
    Customer.objects.get_or_create(phone=d['phone'], defaults=d)
print(f'{len(customers)} customers seeded.')

print('\nDone! Login: 08000000000 / admin1234')
