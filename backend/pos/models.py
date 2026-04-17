import uuid
from django.db import models
from django.conf import settings


class Cashier(models.Model):
    """Represents a cashier user who processes payments."""

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    cashier_id = models.CharField(max_length=50, unique=True, blank=True)
    name = models.CharField(max_length=200)
    cashier_type = models.CharField(
        max_length=20,
        choices=[
            ("retail", "Retail"),
            ("wholesale", "Wholesale"),
            ("both", "Both"),
        ],
        default="retail",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.cashier_id:
            self.cashier_id = f"CSH-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            "id": self.id,
            "cashierId": self.cashier_id,
            "name": self.name,
            "cashierType": self.cashier_type,
            "isActive": self.is_active,
        }

    def __str__(self):
        return f"{self.name} ({self.cashier_id})"


class Sale(models.Model):
    """A completed sale / receipt."""

    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='sales'
    )
    customer = models.ForeignKey(
        "customers.Customer",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="sales",
    )
    cashier = models.ForeignKey(
        Cashier, null=True, blank=True, on_delete=models.SET_NULL, related_name="sales"
    )
    dispenser = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="dispensed_sales",
    )
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_cash = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_pos = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_transfer = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_wallet = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_method = models.CharField(
        max_length=20,
        default="cash",
        choices=[
            ("cash", "Cash"),
            ("pos", "POS"),
            ("transfer", "Transfer"),
            ("wallet", "Wallet"),
            ("split", "Split"),
        ],
    )
    status = models.CharField(
        max_length=20,
        default="completed",
        choices=[
            ("pending", "Pending"),
            ("completed", "Completed"),
            ("returned", "Returned"),
            ("partial_return", "Partial Return"),
        ],
    )
    branch = models.ForeignKey(
        'branches.Branch',
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='sales',
    )
    is_wholesale = models.BooleanField(default=False)
    receipt_id = models.CharField(max_length=50, unique=True, blank=True)
    buyer_name = models.CharField(max_length=200, blank=True, default="")
    buyer_address = models.CharField(max_length=300, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created"]

    def save(self, *args, **kwargs):
        if not self.receipt_id:
            self.receipt_id = f"RCP-{uuid.uuid4().hex[:10].upper()}"
        super().save(*args, **kwargs)

    def to_api_dict(self):
        org = self.organization
        return {
            "id": self.id,
            "receiptId": self.receipt_id,
            "organizationName":    org.name    if org else "",
            "organizationAddress": org.address if org else "",
            "organizationPhone":   org.phone   if org else "",
            "customerId": self.customer_id,
            "customerName": self.customer.name
            if self.customer
            else self.buyer_name or "Walk-in",
            "cashierId": self.cashier_id,
            "cashierName": self.cashier.name if self.cashier else "",
            "dispenserId": self.dispenser_id,
            "dispenserName": (
                getattr(self.dispenser, "full_name", "")
                or getattr(self.dispenser, "phone_number", "")
                if self.dispenser else ""
            ),
            "totalAmount": float(self.total_amount),
            "discountTotal": float(self.discount_total),
            "paymentCash": float(self.payment_cash),
            "paymentPos": float(self.payment_pos),
            "paymentTransfer": float(self.payment_transfer),
            "paymentWallet": float(self.payment_wallet),
            "paymentMethod": self.payment_method,
            "status": self.status,
            "isWholesale": self.is_wholesale,
            "buyerName": self.buyer_name,
            "buyerAddress": self.buyer_address,
            "notes": self.notes,
            "created": self.created.isoformat(),
            "items": [i.to_api_dict() for i in self.items.all()],
        }

    def __str__(self):
        return f"{self.receipt_id} - ₦{self.total_amount}"


class SaleItem(models.Model):
    sale = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="items")
    item = models.ForeignKey(
        "inventory.Item",
        null=True,
        on_delete=models.SET_NULL,
        related_name="sale_items",
    )
    name = models.CharField(max_length=200, default="")
    brand = models.CharField(max_length=200, blank=True, default="")
    dosage_form = models.CharField(max_length=50, blank=True, default="")
    unit = models.CharField(max_length=20, blank=True, default="")
    quantity = models.DecimalField(max_digits=10, decimal_places=2, default=1)
    price = models.DecimalField(max_digits=12, decimal_places=2)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    barcode = models.CharField(max_length=100, blank=True, default="")
    returned = models.BooleanField(default=False)
    return_qty = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    def __str__(self):
        return f"{self.name} ×{self.quantity} [{self.sale.receipt_id}]"

    def save(self, *args, **kwargs):
        self.subtotal = (self.price * self.quantity) - self.discount
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            "id": self.id,
            "itemId": self.item_id,
            "name": self.name or (self.item.name if self.item else "Unknown"),
            "brand": self.brand or (self.item.brand if self.item else ""),
            "dosageForm": self.dosage_form,
            "unit": self.unit,
            "quantity": self.quantity,
            "price": float(self.price),
            "discount": float(self.discount),
            "subtotal": float(self.subtotal),
            "barcode": self.barcode,
            "returned": self.returned,
            "returnQty": self.return_qty,
        }


class DispensingLog(models.Model):
    """Tracks every item dispensed across all sales."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name="dispensing_logs", null=True
    )
    item = models.ForeignKey("inventory.Item", on_delete=models.SET_NULL, null=True)
    name = models.CharField(max_length=200)
    brand = models.CharField(max_length=200, blank=True, default="")
    dosage_form = models.CharField(max_length=50, blank=True, default="")
    unit = models.CharField(max_length=20, blank=True, default="")
    quantity = models.DecimalField(max_digits=10, decimal_places=2, default=1)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(
        max_length=20,
        default="Dispensed",
        choices=[
            ("Dispensed", "Dispensed"),
            ("Returned", "Returned"),
            ("Partially Returned", "Partially Returned"),
        ],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ×{self.quantity} ({self.status})"

    class Meta:
        ordering = ["-created_at"]

    def to_api_dict(self):
        dispenser = None
        if self.user:
            dispenser = getattr(self.user, "full_name", None) \
                or getattr(self.user, "get_full_name", lambda: None)() \
                or getattr(self.user, "phone_number", None) \
                or str(self.user)
        return {
            "id": self.id,
            "name": self.name,
            "brand": self.brand,
            "dosageForm": self.dosage_form,
            "unit": self.unit,
            "quantity": self.quantity,
            "amount": float(self.amount),
            "discount": float(self.discount_amount),
            "status": self.status,
            "dispenser": dispenser,
            "createdAt": self.created_at.isoformat(),
        }


class PaymentRequest(models.Model):
    """Dispenser sends cart to cashier for payment processing."""

    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='payment_requests'
    )
    request_id = models.CharField(max_length=50, unique=True, blank=True)
    dispenser = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sent_requests"
    )
    cashier = models.ForeignKey(
        Cashier,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="received_requests",
    )
    customer = models.ForeignKey(
        "customers.Customer", null=True, blank=True, on_delete=models.SET_NULL
    )
    payment_type = models.CharField(max_length=20, default="retail")
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(
        max_length=20,
        default="pending",
        choices=[
            ("pending", "Pending"),
            ("accepted", "Accepted"),
            ("rejected", "Rejected"),
            ("completed", "Completed"),
            ("cancelled", "Cancelled"),
        ],
    )
    buyer_name = models.CharField(max_length=200, blank=True, default="")
    buyer_address = models.CharField(max_length=300, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    receipt = models.ForeignKey(Sale, null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.request_id} — ₦{self.total_amount} ({self.status})"

    class Meta:
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        if not self.request_id:
            self.request_id = f"PRQ-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def to_api_dict(self):
        dispenser = self.dispenser
        dispenser_name = (
            getattr(dispenser, "full_name", "") or getattr(dispenser, "phone_number", "")
            if dispenser else ""
        )
        cashier_name = self.cashier.name if self.cashier else ""
        customer_name = (
            self.customer.name if self.customer
            else self.buyer_name or ""
        )
        return {
            "id": self.id,
            "requestId": self.request_id,
            "dispenserId": self.dispenser_id,
            "dispenserName": dispenser_name,
            "cashierId": self.cashier_id,
            "cashierName": cashier_name,
            "customerId": self.customer_id,
            "customerName": customer_name,
            "patientName": customer_name,
            "buyerName": self.buyer_name,
            "paymentType": self.payment_type,
            "totalAmount": float(self.total_amount),
            "status": self.status,
            "notes": self.notes,
            "items": [i.to_api_dict() for i in self.items.all()],
            "createdAt": self.created_at.isoformat(),
        }


class PaymentRequestItem(models.Model):
    payment_request = models.ForeignKey(
        PaymentRequest, on_delete=models.CASCADE, related_name="items"
    )
    item = models.ForeignKey("inventory.Item", null=True, on_delete=models.SET_NULL)
    item_name = models.CharField(max_length=200)
    brand = models.CharField(max_length=200, blank=True, default="")
    dosage_form = models.CharField(max_length=50, blank=True, default="")
    unit = models.CharField(max_length=20, blank=True, default="")
    quantity = models.IntegerField(default=1)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)

    def __str__(self):
        return f"{self.item_name} ×{self.quantity} [{self.payment_request.request_id}]"

    def save(self, *args, **kwargs):
        self.subtotal = (self.unit_price * self.quantity) - self.discount_amount
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            "id": self.id,
            "itemId": self.item_id,
            "itemName": self.item_name,
            "brand": self.brand,
            "dosageForm": self.dosage_form,
            "unit": self.unit,
            "quantity": self.quantity,
            "unitPrice": float(self.unit_price),
            "discount": float(self.discount_amount),
            "subtotal": float(self.subtotal),
        }


class ReceiptPayment(models.Model):
    """Individual payment record for split payments."""

    receipt = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="payments")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    payment_method = models.CharField(
        max_length=20,
        choices=[
            ("cash", "Cash"),
            ("pos", "POS"),
            ("transfer", "Transfer"),
            ("wallet", "Wallet"),
        ],
    )
    status = models.CharField(max_length=20, default="completed")
    date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.payment_method.upper()} ₦{self.amount} [{self.receipt.receipt_id}]"

    def to_api_dict(self):
        return {
            "id": self.id,
            "amount": float(self.amount),
            "paymentMethod": self.payment_method,
            "status": self.status,
            "date": self.date.isoformat(),
        }


class ReturnRecord(models.Model):
    """Tracks item returns."""

    sale = models.ForeignKey(Sale, on_delete=models.CASCADE, related_name="returns")
    sale_item = models.ForeignKey(
        SaleItem, on_delete=models.CASCADE, related_name="return_records"
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=2)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    refund_method = models.CharField(
        max_length=20,
        default="wallet",
        choices=[
            ("wallet", "Wallet"),
            ("cash", "Cash"),
            ("original", "Original Method"),
        ],
    )
    reason = models.CharField(max_length=300, blank=True, default="")
    returned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Return ×{self.quantity} from {self.sale.receipt_id}"

    def to_api_dict(self):
        return {
            "id": self.id,
            "saleId": self.sale_id,
            "saleItemId": self.sale_item_id,
            "itemName": self.sale_item.name if self.sale_item else "",
            "quantity": self.quantity,
            "amount": float(self.amount),
            "refundMethod": self.refund_method,
            "reason": self.reason,
            "createdAt": self.created_at.isoformat(),
        }


# ── Expense Tracking ─────────────────────────────────────────────────────────


class ExpenseCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

    def to_api_dict(self):
        return {"id": self.id, "name": self.name}


class Expense(models.Model):
    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='expenses'
    )
    category = models.ForeignKey(
        ExpenseCategory, on_delete=models.CASCADE, related_name="expenses"
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=300, blank=True, default="")
    date = models.DateField()
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.description or self.category.name} — ₦{self.amount} ({self.date})"

    class Meta:
        ordering = ["-date"]

    def to_api_dict(self):
        return {
            "id": self.id,
            "categoryId": self.category_id,
            "categoryName": self.category.name,
            "amount": float(self.amount),
            "description": self.description,
            "date": self.date.isoformat(),
        }


# ── Supplier & Procurement ───────────────────────────────────────────────────


class Supplier(models.Model):
    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='suppliers'
    )
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=20, blank=True, default="")
    contact_info = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    def to_api_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "phone": self.phone,
            "contactInfo": self.contact_info,
        }

    def __str__(self):
        return self.name


class Procurement(models.Model):
    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='procurements'
    )
    supplier = models.ForeignKey(
        Supplier, on_delete=models.CASCADE, related_name="procurements"
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    date = models.DateTimeField(auto_now_add=True)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(
        max_length=20,
        default="draft",
        choices=[("draft", "Draft"), ("completed", "Completed")],
    )

    def __str__(self):
        return f"#{self.id} {self.supplier} ({self.status})"

    def to_api_dict(self):
        return {
            "id": self.id,
            "supplierId": self.supplier_id,
            "supplierName": self.supplier.name,
            "total": float(self.total),
            "status": self.status,
            "date": self.date.isoformat(),
            "items": [i.to_api_dict() for i in self.items.all()],
        }


class ProcurementItem(models.Model):
    procurement = models.ForeignKey(
        Procurement, on_delete=models.CASCADE, related_name="items"
    )
    item_name = models.CharField(max_length=200)
    dosage_form = models.CharField(max_length=50, blank=True, default="")
    brand = models.CharField(max_length=200, blank=True, default="")
    unit = models.CharField(max_length=20, blank=True, default="Pcs")
    quantity = models.IntegerField(default=1)
    cost_price = models.DecimalField(max_digits=12, decimal_places=2)
    markup = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    expiry_date = models.DateField(null=True, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    barcode = models.CharField(max_length=100, blank=True, default="")

    def __str__(self):
        return f"{self.item_name} ×{self.quantity} [PO#{self.procurement_id}]"

    def save(self, *args, **kwargs):
        self.subtotal = self.cost_price * self.quantity
        super().save(*args, **kwargs)

    def to_api_dict(self):
        return {
            "id": self.id,
            "itemName": self.item_name,
            "dosageForm": self.dosage_form,
            "brand": self.brand,
            "unit": self.unit,
            "quantity": self.quantity,
            "costPrice": float(self.cost_price),
            "markup": float(self.markup),
            "subtotal": float(self.subtotal),
            "expiryDate": self.expiry_date.isoformat() if self.expiry_date else None,
            "barcode": self.barcode,
        }


# ── Stock Check ──────────────────────────────────────────────────────────────


class StockCheck(models.Model):
    STORE_CHOICES = [("retail", "Retail"), ("wholesale", "Wholesale")]

    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='stock_checks'
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    date = models.DateTimeField(auto_now_add=True)
    store_type = models.CharField(
        max_length=20, choices=STORE_CHOICES, default="retail",
        help_text="Which store this stock check belongs to"
    )
    status = models.CharField(
        max_length=20,
        default="pending",
        choices=[
            ("pending", "Pending"),
            ("in_progress", "In Progress"),
            ("completed", "Completed"),
        ],
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="approved_checks",
    )
    approved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Stock Check #{self.id} ({self.store_type}) — {self.status}"

    def to_api_dict(self):
        cb = self.created_by
        created_by_name = (
            (getattr(cb, "full_name", "") or getattr(cb, "phone_number", ""))
            if cb else ""
        )
        return {
            "id": self.id,
            "status": self.status,
            "storeType": self.store_type,
            "createdBy": created_by_name,
            "createdAt": self.date.isoformat(),
            "itemCount": self.items.count(),
            "items": [i.to_api_dict() for i in self.items.all()],
        }


class StockCheckItem(models.Model):
    stock_check = models.ForeignKey(
        StockCheck, on_delete=models.CASCADE, related_name="items"
    )
    item = models.ForeignKey("inventory.Item", on_delete=models.CASCADE)
    expected_quantity = models.DecimalField(max_digits=10, decimal_places=2)
    actual_quantity = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    status = models.CharField(
        max_length=20,
        default="pending",
        choices=[
            ("pending", "Pending"),
            ("approved", "Approved"),
            ("adjusted", "Adjusted"),
        ],
    )

    def __str__(self):
        return f"{self.item.name} (exp:{self.expected_quantity}, act:{self.actual_quantity})"

    def to_api_dict(self):
        discrepancy = (self.actual_quantity or self.expected_quantity) - self.expected_quantity
        unit_price = float(getattr(self.item, "price", 0) or 0)
        return {
            "id": self.id,
            "itemId": self.item_id,
            "itemName": self.item.name,
            "expected": self.expected_quantity,
            "actual": self.actual_quantity,
            "status": self.status,
            "discrepancy": discrepancy,
            "costDifference": round(float(discrepancy) * unit_price, 2),
        }


# ── Notifications ────────────────────────────────────────────────────────────


class Notification(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    notif_type = models.CharField(
        max_length=30,
        choices=[
            ("low_stock", "Low Stock"),
            ("out_of_stock", "Out of Stock"),
            ("expiry_alert", "Expiry Alert"),
            ("payment_request", "Payment Request"),
            ("system", "System Message"),
        ],
    )
    priority = models.CharField(
        max_length=10,
        default="medium",
        choices=[
            ("low", "Low"),
            ("medium", "Medium"),
            ("high", "High"),
            ("critical", "Critical"),
        ],
    )
    title = models.CharField(max_length=200)
    message = models.TextField()
    item = models.ForeignKey(
        "inventory.Item", null=True, blank=True, on_delete=models.SET_NULL
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.priority.upper()}] {self.title}"

    class Meta:
        ordering = ["-created_at"]

    def to_api_dict(self):
        return {
            "id": self.id,
            "type": self.notif_type,
            "priority": self.priority,
            "title": self.title,
            "message": self.message,
            "isRead": self.is_read,
            "createdAt": self.created_at.isoformat(),
        }


# ── Inter-Store Transfer ─────────────────────────────────────────────────────


class TransferRequest(models.Model):
    """Transfer items between retail and wholesale."""

    organization = models.ForeignKey(
        'authapp.Organization', null=True, blank=True,
        on_delete=models.CASCADE, related_name='transfer_requests'
    )
    from_wholesale = models.BooleanField(default=True)
    item_name = models.CharField(max_length=200)
    requested_quantity = models.DecimalField(max_digits=10, decimal_places=2)
    approved_quantity = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    unit = models.CharField(max_length=20, blank=True, default="Pcs")
    status = models.CharField(
        max_length=20,
        default="pending",
        choices=[
            ("pending", "Pending"),
            ("approved", "Approved"),
            ("rejected", "Rejected"),
            ("received", "Received"),
        ],
    )
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="transfer_requests",
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="approved_transfers",
    )
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        direction = "WS→Retail" if self.from_wholesale else "Retail→WS"
        return f"Transfer #{self.id} {direction}: {self.item_name} ×{self.requested_quantity}"

    class Meta:
        ordering = ["-created_at"]

    def to_api_dict(self):
        return {
            "id": self.id,
            "direction": "Wholesale → Retail"
            if self.from_wholesale
            else "Retail → Wholesale",
            "fromWholesale": self.from_wholesale,
            "itemName": self.item_name,
            "requestedQty": self.requested_quantity,
            "approvedQty": self.approved_quantity,
            "unit": self.unit,
            "status": self.status,
            "requestedBy": getattr(self.requested_by, "phone_number", ""),
            "notes": self.notes,
            "createdAt": self.created_at.isoformat(),
        }
