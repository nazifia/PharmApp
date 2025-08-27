import decimal
from django import template
from decimal import Decimal

register = template.Library()

@register.filter
def multiply(value, arg):
    """
    Multiplies the value by the argument
    Usage: {{ value|multiply:arg }}
    """
    try:
        return Decimal(str(value)) * Decimal(str(arg))
    except (ValueError, TypeError, decimal.InvalidOperation):
        return Decimal('0.0')

@register.filter
def sub(value, arg):
    """
    Subtracts the argument from the value
    Usage: {{ value|sub:arg }}
    """
    try:
        return Decimal(str(value)) - Decimal(str(arg))
    except (ValueError, TypeError, decimal.InvalidOperation):
        return value