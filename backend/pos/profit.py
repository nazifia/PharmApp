"""Shared profit maths: revenue, COGS and margin, net of returns.

Single source of truth so the profit report and the monthly report can never
drift apart. Everything here works off `SaleItem.cost` — the unit cost
snapshotted at checkout — and refunds are recognised on the date they happen,
not against the period the original sale fell in.
"""
from django.db.models import DecimalField, ExpressionWrapper, F, Q, Sum

from pos.models import ReturnRecord, SaleItem

# Statuses that represent a real, booked sale. 'credit' is dispensed but unpaid
# and 'pending' is not finalised, so neither is revenue. 'returned' IS one: the
# sale happened and earned revenue on its own date, and the refund cancels it
# on the refund's date. Dropping it here instead would delete the sale from its
# own period while still subtracting the refund from the later one.
REVENUE_STATUSES = ('completed', 'partial_return', 'returned')

_MONEY = DecimalField(max_digits=16, decimal_places=2)


def _money(expr):
    return ExpressionWrapper(expr, output_field=_MONEY)


def returns_in(org, **date_filter):
    """Refunds recorded in a period, whatever period their sale belongs to.

    `date_filter` is applied to `created_at`, e.g. ``created_at__date__gte``.
    Refunds against sales that never counted as revenue (credit, pending) are
    skipped — subtracting them would push revenue below zero.
    """
    return ReturnRecord.objects.filter(
        sale__organization=org, sale__status__in=REVENUE_STATUSES, **date_filter
    )


def profit_figures(sales, returns):
    """Revenue / COGS / margin for a period.

    `sales` are the sales made in the period; `returns` the refunds *recorded*
    in it, which may belong to sales from an earlier one. Netting by refund
    date is what keeps a closed month closed — charging a March refund back to
    a February sale would rewrite February's profit after the books were read.

    Returns floats plus `coverage`: the share of line revenue whose line has a
    recorded cost. Lines without one are NOT treated as zero-cost — they are
    excluded from COGS and shown in `coverage`, because pretending cost is 0
    reports the whole sale as profit.
    """
    gross = sales.aggregate(t=Sum('total_amount'))['t'] or 0
    refunds = returns.aggregate(t=Sum('amount'))['t'] or 0
    revenue = float(gross) - float(refunds)

    # ponytail: coverage uses quantity * price and ignores per-line discount —
    # it is a ratio for a warning banner, not a money figure.
    agg = SaleItem.objects.filter(sale__in=sales).aggregate(
        cogs=Sum(_money(F('quantity') * F('cost')), filter=Q(cost__gt=0)),
        costed=Sum(_money(F('quantity') * F('price')), filter=Q(cost__gt=0)),
        line_total=Sum(_money(F('quantity') * F('price'))),
    )
    # Cost of goods handed back, on the same refund date as the money. Lines
    # with no cost added none, so they subtract none.
    returned_cost = returns.aggregate(
        t=Sum(_money(F('quantity') * F('sale_item__cost')),
              filter=Q(sale_item__cost__gt=0))
    )['t'] or 0

    cogs = float(agg['cogs'] or 0) - float(returned_cost)
    costed = float(agg['costed'] or 0)
    line_total = float(agg['line_total'] or 0)

    profit = revenue - cogs
    return {
        'revenue':  round(revenue, 2),
        'cost':     round(cogs, 2),
        'refunds':  round(float(refunds), 2),
        'profit':   round(profit, 2),
        'margin':   round(profit / revenue * 100, 1) if revenue > 0 else 0.0,
        'coverage': round(costed / line_total, 4) if line_total > 0 else 0.0,
    }
