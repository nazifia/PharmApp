from datetime import date, timedelta
from django.db import models as db_models
from django.db.models import F
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from authapp.permissions import IsAdminOrManager, IsReportsUser
from authapp.utils import require_org
from customers.models import Customer
from inventory.models import Item
from pos.models import Cashier, Sale, SaleItem


# ── Date range helper ─────────────────────────────────────────────────────────

def _date_range(period: str):
    """
    Return (start_date, end_date) for the requested period.

    'month'   → first day of the current calendar month → today
    'quarter' → first day of the current quarter → today
    'year'    → 1 Jan of the current year → today
    """
    today = date.today()

    if period == 'today':
        return today, today

    if period == 'week':
        return today - timedelta(days=6), today

    if period == 'month':
        return today.replace(day=1), today

    if period == 'quarter':
        quarter_start_month = ((today.month - 1) // 3) * 3 + 1
        return today.replace(month=quarter_start_month, day=1), today

    if period == 'year':
        return today.replace(month=1, day=1), today

    return today.replace(day=1), today   # default: current month


# ── Sales report ──────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsReportsUser])
def sales_report(request):
    """Aggregate sales for the given period. Admin / Manager only."""
    org, err = require_org(request)
    if err:
        return err

    period = request.query_params.get('period', 'month')
    start, end = _date_range(period)

    sales = Sale.objects.filter(
        organization=org,
        created__date__gte=start,
        created__date__lte=end,
    )

    retail_sales    = sales.filter(is_wholesale=False)
    wholesale_sales = sales.filter(is_wholesale=True)

    total_retail = float(
        retail_sales.aggregate(t=db_models.Sum('total_amount'))['t'] or 0
    )
    total_wholesale = float(
        wholesale_sales.aggregate(t=db_models.Sum('total_amount'))['t'] or 0
    )
    total_revenue = total_retail + total_wholesale

    # Use SaleItem.name (stored at checkout) so deleted items still appear.
    top_items_qs = (
        SaleItem.objects
        .filter(sale__in=sales)
        .values('item_id', 'name')
        .annotate(
            qty=db_models.Sum('quantity'),
            revenue=db_models.Sum(
                db_models.ExpressionWrapper(
                    db_models.F('quantity') * db_models.F('price'),
                    output_field=db_models.FloatField(),
                )
            ),
        )
        .order_by('-qty')[:10]
    )

    top_items = [
        {
            'itemId':  r['item_id'],
            'name':    r['name'] or 'Unknown',
            'qty':     r['qty'] or 0,
            'revenue': float(r['revenue'] or 0),
        }
        for r in top_items_qs
    ]

    # Daily breakdown for sparkline / bar charts
    daily_qs = (
        sales
        .annotate(day=db_models.functions.TruncDate('created'))
        .values('day')
        .annotate(revenue=db_models.Sum('total_amount'))
        .order_by('day')
    )
    daily = [
        {'date': str(r['day']), 'revenue': float(r['revenue'] or 0)}
        for r in daily_qs
    ]

    return Response({
        'period':         period,
        'dateFrom':       str(start),
        'dateTo':         str(end),
        'totalRevenue':   total_revenue,
        'totalRetail':    total_retail,
        'totalWholesale': total_wholesale,
        'totalSales':     sales.count(),
        'topItems':       top_items,
        'dailyBreakdown': daily,
    })


# ── Inventory report ──────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsReportsUser])
def inventory_report(request):
    """Stock overview — Admin / Manager only."""
    org, err = require_org(request)
    if err:
        return err

    items     = Item.objects.filter(organization=org)
    low_stock = items.filter(stock__lte=db_models.F('low_stock_threshold'))

    stock_value = float(
        items.aggregate(
            v=db_models.Sum(
                db_models.ExpressionWrapper(
                    db_models.F('stock') * db_models.F('price'),
                    output_field=db_models.FloatField(),
                )
            )
        )['v'] or 0
    )

    cost_value = float(
        items.aggregate(
            v=db_models.Sum(
                db_models.ExpressionWrapper(
                    db_models.F('stock') * db_models.F('cost'),
                    output_field=db_models.FloatField(),
                )
            )
        )['v'] or 0
    )

    low_stock_items = [
        {
            'id':                i.id,
            'name':              i.name,
            'stock':             i.stock,
            'lowStockThreshold': i.low_stock_threshold,
        }
        for i in low_stock.order_by('stock')[:20]
    ]

    today  = date.today()
    in_30  = today + timedelta(days=30)
    expiring = items.filter(
        expiry_date__isnull=False,
        expiry_date__lte=in_30,
        expiry_date__gte=today,
    ).order_by('expiry_date')[:20]

    expiring_items = [
        {
            'id':         i.id,
            'name':       i.name,
            'stock':      i.stock,
            'expiryDate': str(i.expiry_date),
        }
        for i in expiring
    ]

    return Response({
        'totalItems':    items.count(),
        'activeItems':   items.filter(status='active').count(),
        'lowStockCount': low_stock.count(),
        'stockValue':    round(stock_value, 2),
        'costValue':     round(cost_value, 2),
        'lowStockItems': low_stock_items,
        'expiringItems': expiring_items,
    })


# ── Customer report ───────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsReportsUser])
def customer_report(request):
    """Customer analytics — Admin / Manager only."""
    org, err = require_org(request)
    if err:
        return err

    all_customers = Customer.objects.filter(organization=org)

    top_customers_qs = (
        Sale.objects
        .filter(organization=org, customer__isnull=False)
        .values('customer__id', 'customer__name')
        .annotate(spent=db_models.Sum('total_amount'))
        .order_by('-spent')[:10]
    )

    top_customers = [
        {
            'id':    r['customer__id'],
            'name':  r['customer__name'],
            'spent': float(r['spent'] or 0),
        }
        for r in top_customers_qs
    ]

    total_debt = float(
        all_customers.aggregate(d=db_models.Sum('outstanding_debt'))['d'] or 0
    )

    return Response({
        'total':        all_customers.count(),
        'retail':       all_customers.filter(is_wholesale=False).count(),
        'wholesale':    all_customers.filter(is_wholesale=True).count(),
        'totalDebt':    round(total_debt, 2),
        'topCustomers': top_customers,
    })


# ── Profit report ─────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsReportsUser])
def profit_report(request):
    """Profit & margin analytics — Admin / Manager only."""
    org, err = require_org(request)
    if err:
        return err

    period = request.query_params.get('period', 'month')
    start, end = _date_range(period)

    sales = Sale.objects.filter(
        organization=org,
        created__date__gte=start,
        created__date__lte=end,
    )
    revenue = float(sales.aggregate(t=db_models.Sum('total_amount'))['t'] or 0)

    cogs_result = SaleItem.objects.filter(
        sale__in=sales,
        item__isnull=False,
        item__cost__gt=0,
    ).aggregate(
        total_cost=db_models.Sum(
            db_models.ExpressionWrapper(
                db_models.F('quantity') * F('item__cost'),
                output_field=db_models.FloatField(),
            )
        )
    )
    cogs = float(cogs_result['total_cost'] or 0)

    if cogs > 0:
        cost   = cogs
        profit = revenue - cost
        margin = (profit / revenue * 100) if revenue > 0 else 0.0
        estimated = False
    else:
        cost      = revenue * 0.70
        profit    = revenue * 0.30
        margin    = 30.0
        estimated = True   # no item cost data — margin is an estimate

    return Response({
        'period':    period,
        'dateFrom':  str(start),
        'dateTo':    str(end),
        'revenue':   round(revenue, 2),
        'cost':      round(cost, 2),
        'profit':    round(profit, 2),
        'margin':    round(margin, 1),
        'estimated': estimated,
    })


# ── Monthly summary ───────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsReportsUser])
def monthly_report(request):
    """
    Full-month sales grouped by day for chart rendering.
    Query params: ?year=YYYY&month=M  (default: current month)
    """
    org, err = require_org(request)
    if err:
        return err

    today = date.today()
    try:
        year  = int(request.query_params.get('year',  today.year))
        month = int(request.query_params.get('month', today.month))
    except (TypeError, ValueError):
        year, month = today.year, today.month

    import calendar as cal
    _, last_day = cal.monthrange(year, month)
    start = date(year, month, 1)
    end   = date(year, month, last_day)

    sales = Sale.objects.filter(
        organization=org,
        created__date__gte=start,
        created__date__lte=end,
    )

    daily_qs = (
        sales
        .annotate(day=db_models.functions.TruncDate('created'))
        .values('day')
        .annotate(
            revenue=db_models.Sum('total_amount'),
            count=db_models.Count('id'),
        )
        .order_by('day')
    )
    daily_map = {
        str(r['day']): {'revenue': float(r['revenue'] or 0), 'count': r['count']}
        for r in daily_qs
    }

    # Continuous series (zero-fill days with no sales)
    full_series = []
    current = start
    while current <= end:
        key  = str(current)
        data = daily_map.get(key, {'revenue': 0.0, 'count': 0})
        full_series.append({'date': key, **data})
        current += timedelta(days=1)

    return Response({
        'year':         year,
        'month':        month,
        'totalRevenue': round(float(sales.aggregate(t=db_models.Sum('total_amount'))['t'] or 0), 2),
        'totalSales':   sales.count(),
        'dailySeries':  full_series,
    })


# ── Cashier / staff daily sales ───────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def cashier_sales_report(request):
    """
    Daily sales processed by cashier/staff.
    - Any authenticated user sees their own data.
    - Admin / Manager / Wholesale Manager can see all users (is_admin_view=true)
      or filter by ?user_id=<id>.
    """
    org, err = require_org(request)
    if err:
        return err

    period = request.query_params.get('period', 'today')
    start, end = _date_range(period)

    is_senior = request.user.role in ('Admin', 'Manager', 'Wholesale Manager')

    base_qs = Sale.objects.filter(
        organization=org,
        created__date__gte=start,
        created__date__lte=end,
        status__in=['completed', 'partial_return'],
        dispenser__isnull=False,
    )

    if is_senior:
        user_id_param = request.query_params.get('user_id')
        if user_id_param:
            try:
                uid = int(user_id_param)
                sales_qs = base_qs.filter(dispenser_id=uid)
                is_admin_view = False
            except (ValueError, TypeError):
                sales_qs = base_qs
                is_admin_view = True
        else:
            sales_qs = base_qs
            is_admin_view = True
    else:
        sales_qs = base_qs.filter(dispenser=request.user)
        is_admin_view = False

    user_stats = (
        sales_qs
        .values(
            'dispenser__id',
            'dispenser__full_name',
            'dispenser__phone_number',
            'dispenser__role',
        )
        .annotate(
            total_amount=db_models.Sum('total_amount'),
            total_sales=db_models.Count('id'),
            cash_amount=db_models.Sum('payment_cash'),
            pos_amount=db_models.Sum('payment_pos'),
            transfer_amount=db_models.Sum('payment_transfer'),
            wallet_amount=db_models.Sum('payment_wallet'),
        )
        .order_by('-total_amount')
    )

    users = []
    grand_total = 0.0
    grand_count = 0

    for u in user_stats:
        amt = float(u['total_amount'] or 0)
        cnt = u['total_sales'] or 0
        grand_total += amt
        grand_count += cnt
        users.append({
            'cashierId':      '',
            'cashierName':    u['dispenser__full_name'] or u['dispenser__phone_number'] or '',
            'userId':         u['dispenser__id'],
            'role':           u['dispenser__role'] or '',
            'totalAmount':    round(amt, 2),
            'totalSales':     cnt,
            'cashAmount':     round(float(u['cash_amount'] or 0), 2),
            'posAmount':      round(float(u['pos_amount'] or 0), 2),
            'transferAmount': round(float(u['transfer_amount'] or 0), 2),
            'walletAmount':   round(float(u['wallet_amount'] or 0), 2),
        })

    return Response({
        'period':      period,
        'dateFrom':    str(start),
        'dateTo':      str(end),
        'isAdminView': is_admin_view,
        'totalAmount': round(grand_total, 2),
        'totalSales':  grand_count,
        'users':       users,
    })
