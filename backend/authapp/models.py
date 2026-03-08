from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models

ROLE_CHOICES = [
    ('Admin', 'Admin'),
    ('Manager', 'Manager'),
    ('Pharmacist', 'Pharmacist'),
    ('Pharm-Tech', 'Pharm-Tech'),
    ('Salesperson', 'Salesperson'),
    ('Cashier', 'Cashier'),
    ('Wholesale Manager', 'Wholesale Manager'),
    ('Wholesale Operator', 'Wholesale Operator'),
    ('Wholesale Salesperson', 'Wholesale Salesperson'),
]

class PharmUserManager(BaseUserManager):
    def create_user(self, phone_number, password, role='Pharmacist', **extra):
        user = self.model(phone_number=phone_number, role=role, **extra)
        user.set_password(password)
        user.save()
        return user

    def create_superuser(self, phone_number, password, **extra):
        return self.create_user(phone_number, password, role='Admin',
                                is_staff=True, is_superuser=True, **extra)

class PharmUser(AbstractBaseUser, PermissionsMixin):
    phone_number         = models.CharField(max_length=20, unique=True)
    role                 = models.CharField(max_length=30, choices=ROLE_CHOICES, default='Pharmacist')
    is_active            = models.BooleanField(default=True)
    is_staff             = models.BooleanField(default=False)
    is_wholesale_operator = models.BooleanField(default=False)

    USERNAME_FIELD  = 'phone_number'
    REQUIRED_FIELDS = []
    objects = PharmUserManager()

    def to_api_dict(self):
        return {
            'id':                   self.id,
            'phoneNumber':          self.phone_number,
            'role':                 self.role,
            'isActive':             self.is_active,
            'isWholesaleOperator':  self.is_wholesale_operator,
        }

    def __str__(self):
        return f"{self.phone_number} ({self.role})"
