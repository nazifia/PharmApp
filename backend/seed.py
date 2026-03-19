"""
Run with:  python manage.py shell < seed.py
Creates a test admin user + sample inventory items + customers + cashiers + expenses + suppliers.
"""

import os, django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pharmapi.settings")
django.setup()

from authapp.models import PharmUser
from inventory.models import Item
from customers.models import Customer
from pos.models import Cashier, ExpenseCategory, Expense, Supplier
from datetime import date

# ── Admin user ───────────────────────────────────────────────────────────────
if not PharmUser.objects.filter(phone_number="08000000000").exists():
    PharmUser.objects.create_superuser(phone_number="08000000000", password="admin1234")
    print("Admin created: 08000000000 / admin1234")
else:
    print("Admin already exists.")

# ── Additional users ─────────────────────────────────────────────────────────
users_data = [
    ("08000000001", "cashier123", "Cashier"),
    ("08000000002", "pharm123", "Pharmacist"),
]
for phone, pwd, role in users_data:
    if not PharmUser.objects.filter(phone_number=phone).exists():
        PharmUser.objects.create_user(phone_number=phone, password=pwd, role=role)
        print(f"{role} created: {phone} / {pwd}")

# ── Cashiers ─────────────────────────────────────────────────────────────────
admin_user = PharmUser.objects.get(phone_number="08000000000")
cashier_user = PharmUser.objects.filter(phone_number="08000000001").first()
if cashier_user and not Cashier.objects.filter(user=cashier_user).exists():
    Cashier.objects.create(user=cashier_user, name="Main Cashier", cashier_type="both")
    print("Cashier created.")

# ── Sample items ─────────────────────────────────────────────────────────────
items = [
    dict(
        name="Paracetamol 500mg",
        brand="GSK",
        dosage_form="Tablet",
        unit="Tab",
        cost=100,
        markup=50,
        price=150,
        stock=200,
        low_stock_threshold=20,
        barcode="PAR500",
    ),
    dict(
        name="Amoxicillin 250mg",
        brand="Pfizer",
        dosage_form="Capsule",
        unit="Caps",
        cost=250,
        markup=40,
        price=350,
        stock=80,
        low_stock_threshold=15,
        barcode="AMX250",
    ),
    dict(
        name="Ibuprofen 400mg",
        brand="Bayer",
        dosage_form="Tablet",
        unit="Tab",
        cost=140,
        markup=43,
        price=200,
        stock=5,
        low_stock_threshold=20,
        barcode="IBU400",
    ),
    dict(
        name="Vitamin C 1000mg",
        brand="Seven Seas",
        dosage_form="Tablet",
        unit="Tab",
        cost=350,
        markup=43,
        price=500,
        stock=150,
        low_stock_threshold=10,
        barcode="VTC1000",
    ),
    dict(
        name="Metformin 500mg",
        brand="Teva",
        dosage_form="Tablet",
        unit="Tab",
        cost=80,
        markup=50,
        price=120,
        stock=60,
        low_stock_threshold=10,
        barcode="MET500",
    ),
    dict(
        name="Lisinopril 10mg",
        brand="Zenith",
        dosage_form="Tablet",
        unit="Tab",
        cost=170,
        markup=47,
        price=250,
        stock=3,
        low_stock_threshold=15,
        barcode="LIS10",
    ),
    dict(
        name="Cough Syrup 100ml",
        brand="Emzor",
        dosage_form="Syrup",
        unit="Bottle",
        cost=400,
        markup=25,
        price=500,
        stock=45,
        low_stock_threshold=10,
        barcode="CSY100",
    ),
    dict(
        name="Ibuprofen Injection",
        brand="GSK",
        dosage_form="Injection",
        unit="Amp",
        cost=800,
        markup=25,
        price=1000,
        stock=30,
        low_stock_threshold=5,
        barcode="IBUINJ",
    ),
]
for d in items:
    Item.objects.get_or_create(barcode=d["barcode"], defaults=d)
print(f"{len(items)} items seeded.")

# ── Sample customers ──────────────────────────────────────────────────────────
customers = [
    dict(
        name="John Okafor", phone="08011111111", is_wholesale=False, wallet_balance=5000
    ),
    dict(
        name="Amina Bello", phone="08022222222", is_wholesale=False, wallet_balance=2500
    ),
    dict(
        name="Lagos Pharma Supplies",
        phone="08033333333",
        is_wholesale=True,
        wallet_balance=50000,
    ),
    dict(name="Fatima Umar", phone="08044444444", is_wholesale=False, wallet_balance=0),
    dict(
        name="MedBulk Ltd",
        phone="08055555555",
        is_wholesale=True,
        wallet_balance=100000,
    ),
]
for d in customers:
    Customer.objects.get_or_create(phone=d["phone"], defaults=d)
print(f"{len(customers)} customers seeded.")

# ── Expense categories ───────────────────────────────────────────────────────
cats = [
    "Rent",
    "Utilities",
    "Salaries",
    "Supplies",
    "Maintenance",
    "Marketing",
    "Transport",
    "Insurance",
]
for c in cats:
    ExpenseCategory.objects.get_or_create(name=c)
print(f"{len(cats)} expense categories seeded.")

# ── Suppliers ────────────────────────────────────────────────────────────────
suppliers = [
    dict(
        name="Emzor Pharmaceuticals", phone="08060000001", contact_info="Lagos, Nigeria"
    ),
    dict(name="GSK Nigeria", phone="08060000002", contact_info="Ilupeju, Lagos"),
    dict(
        name="Pfizer Distributors",
        phone="08060000003",
        contact_info="Victoria Island, Lagos",
    ),
]
for s in suppliers:
    Supplier.objects.get_or_create(name=s["name"], defaults=s)
print(f"{len(suppliers)} suppliers seeded.")

print("\nDone! Login: 08000000000 / admin1234")
print("Cashier: 08000000001 / cashier123")
print("Pharmacist: 08000000002 / pharm123")
