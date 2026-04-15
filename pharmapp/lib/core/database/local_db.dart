import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Singleton SQLite database — replaces the Django REST backend entirely.
/// Default admin credentials: phone 0000000000 / password admin123
class LocalDb {
  static final LocalDb instance = LocalDb._();
  LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> initialize() async => await db;

  static String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  static String _now() => DateTime.now().toIso8601String();

  // ── Schema ─────────────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(p.join(dir, 'pharmapp.db'),
        version: 4, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE users ADD COLUMN username TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE sales ADD COLUMN patient_name TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE payment_requests ADD COLUMN patient_name TEXT NOT NULL DEFAULT ''");
    }
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone_number TEXT NOT NULL UNIQUE,
      username TEXT NOT NULL DEFAULT '',
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'Salesperson',
      is_active INTEGER NOT NULL DEFAULT 1,
      is_wholesale_operator INTEGER NOT NULL DEFAULT 0)''');

    await db.execute('''CREATE TABLE items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT NOT NULL DEFAULT '',
      dosage_form TEXT NOT NULL DEFAULT '',
      price REAL NOT NULL DEFAULT 0,
      cost_price REAL NOT NULL DEFAULT 0,
      stock INTEGER NOT NULL DEFAULT 0,
      low_stock_threshold INTEGER NOT NULL DEFAULT 10,
      barcode TEXT NOT NULL DEFAULT '',
      expiry_date TEXT,
      store TEXT NOT NULL DEFAULT 'retail')''');

    await db.execute('''CREATE TABLE customers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '',
      is_wholesale INTEGER NOT NULL DEFAULT 0,
      wallet_balance REAL NOT NULL DEFAULT 0,
      total_purchases REAL NOT NULL DEFAULT 0,
      outstanding_debt REAL NOT NULL DEFAULT 0,
      email TEXT,
      address TEXT,
      join_date TEXT,
      last_visit TEXT)''');

    await db.execute('''CREATE TABLE wallet_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT,
      date TEXT NOT NULL,
      balance_after REAL NOT NULL)''');

    await db.execute('''CREATE TABLE sales(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER,
      is_wholesale INTEGER NOT NULL DEFAULT 0,
      payment_cash REAL NOT NULL DEFAULT 0,
      payment_pos REAL NOT NULL DEFAULT 0,
      payment_bank_transfer REAL NOT NULL DEFAULT 0,
      payment_wallet REAL NOT NULL DEFAULT 0,
      total_amount REAL NOT NULL DEFAULT 0,
      payment_method TEXT NOT NULL DEFAULT 'cash',
      status TEXT NOT NULL DEFAULT 'completed',
      created_at TEXT NOT NULL,
      served_by INTEGER,
      patient_name TEXT NOT NULL DEFAULT '')''');

    await db.execute('''CREATE TABLE sale_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      item_id INTEGER,
      item_name TEXT NOT NULL,
      barcode TEXT,
      quantity INTEGER NOT NULL DEFAULT 1,
      price REAL NOT NULL,
      cost_price REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0)''');

    await db.execute('''CREATE TABLE suppliers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT DEFAULT '',
      contact_info TEXT DEFAULT '')''');

    await db.execute('''CREATE TABLE expense_categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE expenses(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER,
      amount REAL NOT NULL,
      description TEXT DEFAULT '',
      date TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE procurements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER,
      status TEXT NOT NULL DEFAULT 'draft',
      destination TEXT NOT NULL DEFAULT 'retail',
      date TEXT NOT NULL,
      total_amount REAL NOT NULL DEFAULT 0)''');

    await db.execute('''CREATE TABLE procurement_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      procurement_id INTEGER NOT NULL,
      item_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      cost_price REAL NOT NULL DEFAULT 0)''');

    await db.execute('''CREATE TABLE stock_checks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      created_by INTEGER)''');

    await db.execute('''CREATE TABLE stock_check_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stock_check_id INTEGER NOT NULL,
      item_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      counted_qty INTEGER NOT NULL DEFAULT 0,
      system_qty INTEGER NOT NULL DEFAULT 0,
      variance INTEGER NOT NULL DEFAULT 0,
      item_status TEXT NOT NULL DEFAULT 'pending')''');

    await db.execute('''CREATE TABLE transfers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_name TEXT NOT NULL,
      requested_qty INTEGER NOT NULL DEFAULT 0,
      approved_qty INTEGER NOT NULL DEFAULT 0,
      unit TEXT NOT NULL DEFAULT 'Pcs',
      from_wholesale INTEGER NOT NULL DEFAULT 1,
      notes TEXT DEFAULT '',
      status TEXT NOT NULL DEFAULT 'pending',
      date TEXT NOT NULL,
      created_by INTEGER)''');

    await db.execute('''CREATE TABLE payment_requests(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      items_json TEXT NOT NULL DEFAULT '[]',
      total_amount REAL NOT NULL DEFAULT 0,
      customer_id INTEGER,
      cashier_id INTEGER,
      payment_type TEXT NOT NULL DEFAULT 'retail',
      patient_name TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE dispensing_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      patient_name TEXT DEFAULT '',
      prescription_no TEXT DEFAULT '',
      dispensed_by INTEGER,
      date TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE notifications(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'info',
      is_read INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL)''');

    // Seed admin user
    await db.insert('users', {
      'phone_number': '0000000000',
      'username': 'Admin',
      'password_hash': _hash('admin123'),
      'role': 'Admin',
      'is_active': 1,
      'is_wholesale_operator': 0,
    });
    await db.insert('expense_categories', {'name': 'General'});
  }

  // ── USERS ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> authenticateUser(
      String phone, String password) async {
    final d = await db;
    final rows = await d.query('users',
        where: 'phone_number = ? AND is_active = 1', whereArgs: [phone]);
    if (rows.isEmpty) return null;
    if (rows.first['password_hash'] != _hash(password)) return null;
    return _userJson(rows.first);
  }

  Future<List<Map<String, dynamic>>> getAllUsers(
      {String? search, String? role}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (search != null && search.isNotEmpty) {
      conds.add('(phone_number LIKE ? OR username LIKE ?)');
      args.addAll(['%$search%', '%$search%']);
    }
    if (role != null && role.isNotEmpty) {
      conds.add('role = ?');
      args.add(role);
    }
    final rows = await d.query('users',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args);
    return rows.map(_userJson).toList();
  }

  Future<Map<String, dynamic>> createUser(
      String phone, String password, String role,
      {String username = ''}) async {
    final d = await db;
    final id = await d.insert('users', {
      'phone_number': phone,
      'username': username,
      'password_hash': _hash(password),
      'role': role,
      'is_active': 1,
      'is_wholesale_operator': 0,
    });
    return {
      'id': id,
      'phoneNumber': phone,
      'username': username,
      'role': role,
      'isActive': true,
      'isWholesaleOperator': false
    };
  }

  Future<void> deleteUser(int id) async =>
      (await db).delete('users', where: 'id = ?', whereArgs: [id]);

  Future<void> changeUserPassword(int id, String newPassword) async =>
      (await db).update('users', {'password_hash': _hash(newPassword)},
          where: 'id = ?', whereArgs: [id]);

  Future<Map<String, dynamic>> updateUser(int id,
      {String? role, bool? isActive, String? username, String? fullname}) async {
    final d = await db;
    final u = <String, dynamic>{};
    if (role != null) u['role'] = role;
    if (isActive != null) u['is_active'] = isActive ? 1 : 0;
    if (username != null) u['username'] = username;
    if (fullname != null) u['fullname'] = fullname;
    if (u.isNotEmpty)
      await d.update('users', u, where: 'id = ?', whereArgs: [id]);
    final rows = await d.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? {'id': id} : _userJson(rows.first);
  }

  Map<String, dynamic> _userJson(Map<String, dynamic> r) => {
        'id': r['id'],
        'phoneNumber': r['phone_number'],
        'username': r['username'] ?? '',
        'fullname': r['fullname'] ?? '',
        'role': r['role'],
        'isActive': r['is_active'] == 1,
        'isWholesaleOperator': r['is_wholesale_operator'] == 1,
      };

  // ── ITEMS ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getItems(
      {String? search, String? store}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (search != null && search.isNotEmpty) {
      conds.add('(name LIKE ? OR brand LIKE ? OR barcode LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (store != null && store.isNotEmpty) {
      conds.add('store = ?');
      args.add(store);
    }
    final rows = await d.query('items',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'name ASC');
    return rows.map(_itemJson).toList();
  }

  Future<Map<String, dynamic>?> getItemById(int id) async {
    final rows =
        await (await db).query('items', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _itemJson(rows.first);
  }

  Future<Map<String, dynamic>?> getItemByBarcode(String barcode) async {
    final rows = await (await db)
        .query('items', where: 'barcode = ?', whereArgs: [barcode]);
    return rows.isEmpty ? null : _itemJson(rows.first);
  }

  Map<String, dynamic> _itemJson(Map<String, dynamic> r) => {
        'id': r['id'],
        'name': r['name'],
        'brand': r['brand'] ?? '',
        'dosageForm': r['dosage_form'] ?? '',
        'price': (r['price'] as num).toDouble(),
        'costPrice': (r['cost_price'] as num).toDouble(),
        'stock': r['stock'],
        'lowStockThreshold': r['low_stock_threshold'],
        'barcode': r['barcode'] ?? '',
        'expiryDate': r['expiry_date'],
        'store': r['store'] ?? 'retail',
      };

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    final d = await db;
    final id = await d.insert('items', {
      'name': data['name'] ?? '',
      'brand': data['brand'] ?? data['brandName'] ?? '',
      'dosage_form': data['dosageForm'] ?? data['dosage_form'] ?? '',
      'price': ((data['price'] ?? 0) as num).toDouble(),
      'cost_price': ((data['costPrice'] ??
              data['cost_price'] ??
              data['cost'] ??
              0) as num)
          .toDouble(),
      'stock': data['stock'] ?? 0,
      'low_stock_threshold':
          data['lowStockThreshold'] ?? data['low_stock_threshold'] ?? 10,
      'barcode': data['barcode'] ?? '',
      'expiry_date': data['expiryDate'] ?? data['expiry_date'],
      'store': data['store'] ?? 'retail',
    });
    return (await getItemById(id))!;
  }

  Future<Map<String, dynamic>> updateItem(
      int id, Map<String, dynamic> data) async {
    final d = await db;
    final u = <String, dynamic>{};
    if (data.containsKey('name')) u['name'] = data['name'];
    if (data.containsKey('brand')) u['brand'] = data['brand'];
    if (data.containsKey('brandName')) u['brand'] = data['brandName'];
    if (data.containsKey('dosageForm')) u['dosage_form'] = data['dosageForm'];
    if (data.containsKey('dosage_form')) u['dosage_form'] = data['dosage_form'];
    if (data.containsKey('price'))
      u['price'] = (data['price'] as num).toDouble();
    if (data.containsKey('costPrice'))
      u['cost_price'] = (data['costPrice'] as num).toDouble();
    if (data.containsKey('cost_price'))
      u['cost_price'] = (data['cost_price'] as num).toDouble();
    if (data.containsKey('cost'))
      u['cost_price'] = (data['cost'] as num).toDouble();
    if (data.containsKey('stock')) u['stock'] = data['stock'];
    if (data.containsKey('lowStockThreshold'))
      u['low_stock_threshold'] = data['lowStockThreshold'];
    if (data.containsKey('low_stock_threshold'))
      u['low_stock_threshold'] = data['low_stock_threshold'];
    if (data.containsKey('barcode')) u['barcode'] = data['barcode'];
    if (data.containsKey('expiryDate')) u['expiry_date'] = data['expiryDate'];
    if (data.containsKey('expiry_date')) u['expiry_date'] = data['expiry_date'];
    if (data.containsKey('store')) u['store'] = data['store'];
    if (u.isNotEmpty)
      await d.update('items', u, where: 'id = ?', whereArgs: [id]);
    return (await getItemById(id))!;
  }

  Future<void> deleteItem(int id) async =>
      (await db).delete('items', where: 'id = ?', whereArgs: [id]);

  Future<Map<String, dynamic>> adjustStock(int id, int adjustment) async {
    final d = await db;
    await d.rawUpdate(
        'UPDATE items SET stock = stock + ? WHERE id = ?', [adjustment, id]);
    final item = (await getItemById(id))!;
    if ((item['stock'] as int) <= (item['lowStockThreshold'] as int)) {
      await addNotification(
          'Low stock: ${item['name']} has ${item['stock']} units', 'warning');
    }
    return item;
  }

  // ── CUSTOMERS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final rows = await (await db).query('customers', orderBy: 'name ASC');
    return rows.map(_customerJson).toList();
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final rows =
        await (await db).query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _customerJson(rows.first);
  }

  Map<String, dynamic> _customerJson(Map<String, dynamic> r) => {
        'id': r['id'],
        'name': r['name'],
        'phone': r['phone'] ?? '',
        'isWholesale': r['is_wholesale'] == 1,
        'walletBalance': (r['wallet_balance'] as num).toDouble(),
        'totalPurchases': (r['total_purchases'] as num).toDouble(),
        'outstandingDebt': (r['outstanding_debt'] as num).toDouble(),
        'email': r['email'],
        'address': r['address'],
        'joinDate': r['join_date'],
        'lastVisit': r['last_visit'],
      };

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final d = await db;
    final now = _now();
    final id = await d.insert('customers', {
      'name': data['name'] ?? '',
      'phone': data['phone'] ?? '',
      'is_wholesale':
          ((data['isWholesale'] ?? data['is_wholesale'] ?? false) == true)
              ? 1
              : 0,
      'wallet_balance':
          ((data['walletBalance'] ?? data['wallet_balance'] ?? 0) as num)
              .toDouble(),
      'total_purchases': 0.0,
      'outstanding_debt':
          ((data['outstandingDebt'] ?? data['outstanding_debt'] ?? 0) as num)
              .toDouble(),
      'email': data['email'],
      'address': data['address'],
      'join_date': now,
      'last_visit': now,
    });
    return (await getCustomerById(id))!;
  }

  Future<Map<String, dynamic>> updateCustomer(
      int id, Map<String, dynamic> data) async {
    final d = await db;
    final u = <String, dynamic>{};
    if (data.containsKey('name')) u['name'] = data['name'];
    if (data.containsKey('phone')) u['phone'] = data['phone'];
    if (data.containsKey('isWholesale'))
      u['is_wholesale'] = data['isWholesale'] ? 1 : 0;
    if (data.containsKey('is_wholesale'))
      u['is_wholesale'] = data['is_wholesale'] ? 1 : 0;
    if (data.containsKey('email')) u['email'] = data['email'];
    if (data.containsKey('address')) u['address'] = data['address'];
    if (data.containsKey('outstandingDebt'))
      u['outstanding_debt'] = (data['outstandingDebt'] as num).toDouble();
    if (data.containsKey('outstanding_debt'))
      u['outstanding_debt'] = (data['outstanding_debt'] as num).toDouble();
    if (u.isNotEmpty)
      await d.update('customers', u, where: 'id = ?', whereArgs: [id]);
    return (await getCustomerById(id))!;
  }

  Future<void> deleteCustomer(int id) async =>
      (await db).delete('customers', where: 'id = ?', whereArgs: [id]);

  Future<void> topUpWallet(int customerId, double amount) async {
    final d = await db;
    // Atomic increment — no read-then-write race.
    await d.rawUpdate(
        'UPDATE customers SET wallet_balance = wallet_balance + ? WHERE id = ?',
        [amount, customerId]);
    final row = await d.rawQuery(
        'SELECT wallet_balance FROM customers WHERE id = ?', [customerId]);
    final newBal = (row.first['wallet_balance'] as num).toDouble();
    await d.insert('wallet_transactions', {
      'customer_id': customerId,
      'type': 'top_up',
      'amount': amount,
      'note': 'Top-up',
      'date': _now(),
      'balance_after': newBal,
    });
  }

  Future<void> deductWallet(int customerId, double amount) async {
    final d = await db;
    // Atomic decrement with floor at zero — prevents negative balance and
    // eliminates the read-modify-write race between concurrent deductions.
    await d.rawUpdate(
        'UPDATE customers SET wallet_balance = MAX(0, wallet_balance - ?) WHERE id = ?',
        [amount, customerId]);
    final row = await d.rawQuery(
        'SELECT wallet_balance FROM customers WHERE id = ?', [customerId]);
    final newBal = (row.first['wallet_balance'] as num).toDouble();
    await d.insert('wallet_transactions', {
      'customer_id': customerId,
      'type': 'deduction',
      'amount': amount,
      'note': 'Deduction',
      'date': _now(),
      'balance_after': newBal,
    });
  }

  Future<void> resetWallet(int customerId) async {
    final d = await db;
    final c = (await getCustomerById(customerId))!;
    final old = c['walletBalance'] as double;
    await d.update('customers', {'wallet_balance': 0.0},
        where: 'id = ?', whereArgs: [customerId]);
    await d.insert('wallet_transactions', {
      'customer_id': customerId,
      'type': 'reset',
      'amount': old,
      'note': 'Wallet reset',
      'date': _now(),
      'balance_after': 0.0,
    });
  }

  Future<void> recordPayment(
      int customerId, double amount, String method) async {
    final d = await db;
    await d.rawUpdate(
        'UPDATE customers SET outstanding_debt = outstanding_debt - ? WHERE id = ?',
        [amount, customerId]);
    final c = (await getCustomerById(customerId))!;
    await d.insert('wallet_transactions', {
      'customer_id': customerId,
      'type': 'payment',
      'amount': amount,
      'note': 'Payment via $method',
      'date': _now(),
      'balance_after': c['walletBalance'],
    });
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(
      int customerId) async {
    final rows = await (await db).query('wallet_transactions',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'date DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'type': r['type'],
              'amount': (r['amount'] as num).toDouble(),
              'note': r['note'] ?? '',
              'date': r['date'],
              'balanceAfter': (r['balance_after'] as num).toDouble(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerSales(int customerId) async {
    final d = await db;
    final rows = await d.query('sales',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
        limit: 20);
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final items = await d
          .query('sale_items', where: 'sale_id = ?', whereArgs: [row['id']]);
      result.add({
        'id': row['id'],
        'date': row['created_at'],
        'items': items.length,
        'total': (row['total_amount'] as num).toDouble(),
        'status': row['status'],
      });
    }
    return result;
  }

  // ── SALES (CHECKOUT) ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> payload,
      {int? userId}) async {
    final d = await db;
    final now = _now();
    final items =
        (payload['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final payment = (payload['payment'] as Map<String, dynamic>?) ?? {};
    final customerId = payload['customerId'] as int?;
    final isWholesale = (payload['isWholesale'] ?? false) == true;
    final totalAmount = ((payload['totalAmount'] ?? 0) as num).toDouble();
    final paymentMethod = payload['paymentMethod'] as String? ?? 'cash';

    final patientName = payload['patientName'] as String? ?? '';

    final saleId = await d.insert('sales', {
      'customer_id': customerId,
      'is_wholesale': isWholesale ? 1 : 0,
      'payment_cash': ((payment['cash'] ?? 0) as num).toDouble(),
      'payment_pos': ((payment['pos'] ?? 0) as num).toDouble(),
      'payment_bank_transfer':
          ((payment['bankTransfer'] ?? payment['bank_transfer'] ?? 0) as num)
              .toDouble(),
      'payment_wallet': ((payment['wallet'] ?? 0) as num).toDouble(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': 'completed',
      'created_at': now,
      'served_by': userId,
      'patient_name': patientName,
    });

    for (final item in items) {
      final itemId = item['itemId'] as int?;
      final qty = ((item['quantity'] ?? 1) as num).toInt();
      final price = ((item['price'] ?? 0) as num).toDouble();
      final discount = ((item['discount'] ?? 0) as num).toDouble();
      String itemName = '';
      double costPrice = 0.0;
      if (itemId != null) {
        final dbItem = await getItemById(itemId);
        if (dbItem != null) {
          itemName = dbItem['name'] as String;
          costPrice = (dbItem['costPrice'] as num).toDouble();
          await d.rawUpdate(
              'UPDATE items SET stock = stock - ? WHERE id = ?', [qty, itemId]);
        }
      }
      await d.insert('sale_items', {
        'sale_id': saleId,
        'item_id': itemId,
        'item_name': itemName,
        'barcode': item['barcode'] ?? '',
        'quantity': qty,
        'price': price,
        'cost_price': costPrice,
        'discount': discount,
      });
    }

    if (customerId != null) {
      await d.rawUpdate(
          'UPDATE customers SET total_purchases = total_purchases + ?, last_visit = ? WHERE id = ?',
          [totalAmount, now, customerId]);
      final walletPay = ((payment['wallet'] ?? 0) as num).toDouble();
      if (walletPay > 0) {
        // Atomic decrement — prevents negative balance without a separate read.
        await d.rawUpdate(
            'UPDATE customers SET wallet_balance = MAX(0, wallet_balance - ?) WHERE id = ?',
            [walletPay, customerId]);
        final row = await d.rawQuery(
            'SELECT wallet_balance FROM customers WHERE id = ?', [customerId]);
        final newBal = (row.first['wallet_balance'] as num).toDouble();
        await d.insert('wallet_transactions', {
          'customer_id': customerId,
          'type': 'payment',
          'amount': walletPay,
          'note': 'POS sale #$saleId',
          'date': now,
          'balance_after': newBal,
        });
      }
    }
    return (await getSaleDetail(saleId)) ??
        {'id': saleId, 'status': 'completed'};
  }

  Future<List<Map<String, dynamic>>> getSales(
      {String? from,
      String? to,
      int? customerId,
      String? search,
      bool? isWholesale}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      conds.add('created_at >= ?');
      args.add(from);
    }
    if (to != null) {
      conds.add('created_at <= ?');
      args.add(to);
    }
    if (customerId != null) {
      conds.add('customer_id = ?');
      args.add(customerId);
    }
    if (isWholesale != null) {
      conds.add('is_wholesale = ?');
      args.add(isWholesale ? 1 : 0);
    }
    final rows = await d.query('sales',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'created_at DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final saleItems = await d
          .query('sale_items', where: 'sale_id = ?', whereArgs: [row['id']]);
      if (search != null && search.isNotEmpty) {
        final match = saleItems.any((i) => (i['item_name'] as String)
            .toLowerCase()
            .contains(search.toLowerCase()));
        if (!match) continue;
      }
      final resolvedName = await _resolveCustomerName(row);
      final dispenserName =
          await _resolveDispenserName(row['served_by'] as int?);
      result.add(_saleJson(row, saleItems,
          resolvedCustomerName: resolvedName, dispenserName: dispenserName));
    }
    return result;
  }

  Future<Map<String, dynamic>?> getSaleDetail(int id) async {
    final d = await db;
    final rows = await d.query('sales', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items =
        await d.query('sale_items', where: 'sale_id = ?', whereArgs: [id]);
    final resolvedName = await _resolveCustomerName(rows.first);
    final dispenserName =
        await _resolveDispenserName(rows.first['served_by'] as int?);
    return _saleJson(rows.first, items,
        resolvedCustomerName: resolvedName, dispenserName: dispenserName);
  }

  /// Resolves the customer name from the customers table for a given sale row.
  /// Returns null if no customer is linked (so the caller can default to 'Walk-in').
  Future<String?> _resolveCustomerName(Map<String, dynamic> saleRow) async {
    final customerId = saleRow['customer_id'] as int?;
    if (customerId == null) return null;
    final customer = await getCustomerById(customerId);
    return customer?['name'] as String?;
  }

  Future<String> _resolveDispenserName(int? servedBy) async {
    if (servedBy == null) return '';
    final d = await db;
    final rows = await d.query('users', where: 'id = ?', whereArgs: [servedBy]);
    if (rows.isEmpty) return '';
    final username = (rows.first['username'] as String?) ?? '';
    final phone = (rows.first['phone_number'] as String?) ?? '';
    return username.isNotEmpty ? username : phone;
  }

  Map<String, dynamic> _saleJson(
      Map<String, dynamic> r, List<Map<String, dynamic>> items,
      {String? resolvedCustomerName, String? dispenserName}) {
    final patientName = (r['patient_name'] as String?) ?? '';
    final customerId = r['customer_id'] as int?;
    // Priority: patient_name > resolved customer lookup > Walk-in
    String customerName = patientName.isNotEmpty
        ? patientName
        : (resolvedCustomerName ?? 'Walk-in');
    return {
      'id': r['id'],
      'customerId': customerId,
      'isWholesale': r['is_wholesale'] == 1,
      'payment': {
        'cash': r['payment_cash'],
        'pos': r['payment_pos'],
        'bankTransfer': r['payment_bank_transfer'],
        'wallet': r['payment_wallet'],
      },
      'payments': [
        {'method': r['payment_method'], 'amount': r['total_amount']}
      ],
      'totalAmount': (r['total_amount'] as num).toDouble(),
      'paymentMethod': r['payment_method'],
      'status': r['status'],
      'createdAt': r['created_at'],
      'patientName': patientName,
      'customerName': customerName,
      'dispenserName': dispenserName ?? '',
      'items': items
          .map((i) => {
                'id': i['id'],
                'itemId': i['item_id'],
                'itemName': i['item_name'],
                'name': i['item_name'],
                'barcode': i['barcode'],
                'quantity': i['quantity'],
                'price': i['price'],
                'costPrice': i['cost_price'],
                'discount': i['discount'],
                'subtotal': ((i['price'] as num) * (i['quantity'] as num) -
                        (i['discount'] as num))
                    .toDouble(),
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> returnSaleItem(int saleId,
      {required int saleItemId,
      required num quantity,
      String refundMethod = 'wallet',
      String reason = ''}) async {
    final d = await db;
    final rows =
        await d.query('sale_items', where: 'id = ?', whereArgs: [saleItemId]);
    if (rows.isNotEmpty) {
      final si = rows.first;
      final itemId = si['item_id'] as int?;
      if (itemId != null) {
        await d.rawUpdate('UPDATE items SET stock = stock + ? WHERE id = ?',
            [quantity, itemId]);
      }
      final refund = (si['price'] as num).toDouble() * quantity -
          (si['discount'] as num).toDouble();
      await d.rawUpdate(
          'UPDATE sales SET total_amount = total_amount - ? WHERE id = ?',
          [refund, saleId]);
    }
    return {'success': true, 'saleId': saleId};
  }

  // ── SUPPLIERS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSuppliers({String? search}) async {
    final d = await db;
    final rows = (search != null && search.isNotEmpty)
        ? await d
            .query('suppliers', where: 'name LIKE ?', whereArgs: ['%$search%'])
        : await d.query('suppliers', orderBy: 'name ASC');
    return rows
        .map((r) => {
              'id': r['id'],
              'name': r['name'],
              'phone': r['phone'] ?? '',
              'contactInfo': r['contact_info'] ?? '',
            })
        .toList();
  }

  Future<Map<String, dynamic>> createSupplier(String name,
      {String phone = '', String contactInfo = ''}) async {
    final id = await (await db).insert('suppliers',
        {'name': name, 'phone': phone, 'contact_info': contactInfo});
    return {'id': id, 'name': name, 'phone': phone, 'contactInfo': contactInfo};
  }

  Future<Map<String, dynamic>> updateSupplier(int id,
      {required String name, String phone = '', String contactInfo = ''}) async {
    await (await db).update(
      'suppliers',
      {'name': name, 'phone': phone, 'contact_info': contactInfo},
      where: 'id = ?',
      whereArgs: [id],
    );
    return {'id': id, 'name': name, 'phone': phone, 'contactInfo': contactInfo};
  }

  Future<void> deleteSupplier(int id) async =>
      (await db).delete('suppliers', where: 'id = ?', whereArgs: [id]);

  // ── EXPENSES ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final rows =
        await (await db).query('expense_categories', orderBy: 'name ASC');
    return rows.map((r) => {'id': r['id'], 'name': r['name']}).toList();
  }

  Future<Map<String, dynamic>> createExpenseCategory(String name) async {
    final id = await (await db).insert('expense_categories', {'name': name});
    return {'id': id, 'name': name};
  }

  Future<Map<String, dynamic>> updateExpenseCategory(int id, String name) async {
    await (await db).update('expense_categories', {'name': name},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'name': name};
  }

  Future<void> deleteExpenseCategory(int id) async {
    await (await db)
        .delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getExpenses(
      {String? from, String? to}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      conds.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      conds.add('date <= ?');
      args.add(to);
    }
    final rows = await d.query('expenses',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'categoryId': r['category_id'],
              'amount': (r['amount'] as num).toDouble(),
              'description': r['description'] ?? '',
              'date': r['date'],
            })
        .toList();
  }

  Future<Map<String, dynamic>> createExpense(
      {required int categoryId,
      required double amount,
      String description = '',
      String? date}) async {
    final d = await db;
    final expDate = date ?? _now();
    final id = await d.insert('expenses', {
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'date': expDate,
    });
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'description': description,
      'date': expDate
    };
  }

  Future<void> deleteExpense(int id) async =>
      (await db).delete('expenses', where: 'id = ?', whereArgs: [id]);

  // ── PROCUREMENTS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProcurements({String? search}) async {
    final d = await db;
    final rows = await d.query('procurements', orderBy: 'date DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final pItems = await d.query('procurement_items',
          where: 'procurement_id = ?', whereArgs: [row['id']]);
      result.add({
        'id': row['id'],
        'supplierId': row['supplier_id'],
        'status': row['status'],
        'destination': row['destination'],
        'date': row['date'],
        'totalAmount': (row['total_amount'] as num).toDouble(),
        'items': pItems
            .map((i) => {
                  'id': i['id'],
                  'itemId': i['item_id'],
                  'itemName': i['item_name'],
                  'quantity': i['quantity'],
                  'costPrice': i['cost_price'],
                })
            .toList(),
      });
    }
    if (search != null && search.isNotEmpty) {
      return result.where((r) {
        final itemsList = r['items'] as List;
        return itemsList.any((i) => (i['itemName'] as String)
            .toLowerCase()
            .contains(search.toLowerCase()));
      }).toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> createProcurement({
    required int supplierId,
    required List<Map<String, dynamic>> items,
    String status = 'draft',
    String destination = 'retail',
  }) async {
    final d = await db;
    double total = 0;
    final procId = await d.insert('procurements', {
      'supplier_id': supplierId,
      'status': status,
      'destination': destination,
      'date': _now(),
      'total_amount': 0,
    });
    for (final item in items) {
      final qty = ((item['quantity'] ?? 0) as num).toInt();
      final cost =
          ((item['costPrice'] ?? item['cost_price'] ?? 0) as num).toDouble();
      total += qty * cost;
      final dbItem = (item['itemId'] != null)
          ? await getItemById(item['itemId'] as int)
          : null;
      await d.insert('procurement_items', {
        'procurement_id': procId,
        'item_id': item['itemId'] ?? 0,
        'item_name': dbItem?['name'] ?? item['itemName'] ?? '',
        'quantity': qty,
        'cost_price': cost,
      });
    }
    await d.update('procurements', {'total_amount': total},
        where: 'id = ?', whereArgs: [procId]);
    return (await getProcurements()).firstWhere((r) => r['id'] == procId);
  }

  Future<Map<String, dynamic>> completeProcurement(int id,
      {String destination = 'retail'}) async {
    final d = await db;
    final pItems = await d.query('procurement_items',
        where: 'procurement_id = ?', whereArgs: [id]);
    for (final item in pItems) {
      final itemId = item['item_id'] as int?;
      if (itemId != null && itemId > 0) {
        final qty = item['quantity'] as int;
        final cost = (item['cost_price'] as num).toDouble();
        await d.rawUpdate(
            'UPDATE items SET stock = stock + ?, cost_price = ?, store = ? WHERE id = ?',
            [qty, cost, destination, itemId]);
      }
    }
    await d.update(
        'procurements', {'status': 'completed', 'destination': destination},
        where: 'id = ?', whereArgs: [id]);
    return (await getProcurements()).firstWhere((r) => r['id'] == id);
  }

  // ── STOCK CHECKS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStockChecks() async {
    final rows = await (await db).query('stock_checks', orderBy: 'date DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'date': r['date'],
              'status': r['status'],
              'createdBy': r['created_by']
            })
        .toList();
  }

  Future<Map<String, dynamic>> createStockCheck({int? userId}) async {
    final now = _now();
    final id = await (await db).insert('stock_checks',
        {'date': now, 'status': 'pending', 'created_by': userId});
    return {'id': id, 'date': now, 'status': 'pending', 'items': []};
  }

  Future<Map<String, dynamic>> getStockCheckDetail(int id) async {
    final d = await db;
    final rows =
        await d.query('stock_checks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return {};
    final items = await d.query('stock_check_items',
        where: 'stock_check_id = ?', whereArgs: [id]);
    return {
      'id': rows.first['id'],
      'date': rows.first['date'],
      'status': rows.first['status'],
      'items': items
          .map((i) => {
                'id': i['id'],
                'itemId': i['item_id'],
                'itemName': i['item_name'],
                'countedQty': i['counted_qty'],
                'systemQty': i['system_qty'],
                'variance': i['variance'],
                'status': i['item_status'],
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> addStockCheckItem(
      int checkId, int itemId) async {
    final d = await db;
    final item = await getItemById(itemId);
    if (item == null) throw Exception('Item not found');
    final sysQty = item['stock'] as int;
    final id = await d.insert('stock_check_items', {
      'stock_check_id': checkId,
      'item_id': itemId,
      'item_name': item['name'],
      'counted_qty': sysQty,
      'system_qty': sysQty,
      'variance': 0,
      'item_status': 'pending',
    });
    return {
      'id': id,
      'itemId': itemId,
      'itemName': item['name'],
      'countedQty': sysQty,
      'systemQty': sysQty,
      'variance': 0
    };
  }

  Future<Map<String, dynamic>> updateStockCheckItem(
      int checkId, int itemId, int actualQty, String itemStatus) async {
    final d = await db;
    final rows = await d.query('stock_check_items',
        where: 'stock_check_id = ? AND item_id = ?',
        whereArgs: [checkId, itemId]);
    if (rows.isEmpty) throw Exception('Item not in stock check');
    final sysQty = rows.first['system_qty'] as int;
    final variance = actualQty - sysQty;
    await d.update(
        'stock_check_items',
        {
          'counted_qty': actualQty,
          'variance': variance,
          'item_status': itemStatus
        },
        where: 'stock_check_id = ? AND item_id = ?',
        whereArgs: [checkId, itemId]);
    return {
      'itemId': itemId,
      'countedQty': actualQty,
      'systemQty': sysQty,
      'variance': variance,
      'status': itemStatus
    };
  }

  Future<Map<String, dynamic>> approveStockCheck(int id) async {
    final d = await db;
    final items = await d.query('stock_check_items',
        where: 'stock_check_id = ?', whereArgs: [id]);
    for (final item in items) {
      await d.update('items', {'stock': item['counted_qty']},
          where: 'id = ?', whereArgs: [item['item_id']]);
    }
    await d.update('stock_checks', {'status': 'approved'},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'status': 'approved'};
  }

  Future<void> deleteStockCheck(int id) async {
    final d = await db;
    await d.delete('stock_check_items',
        where: 'stock_check_id = ?', whereArgs: [id]);
    await d.delete('stock_checks', where: 'id = ?', whereArgs: [id]);
  }

  // ── TRANSFERS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTransfers(
      {String? status, String? direction}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (status != null) {
      conds.add('status = ?');
      args.add(status);
    }
    if (direction == 'outgoing') conds.add('from_wholesale = 1');
    if (direction == 'incoming') conds.add('from_wholesale = 0');
    final rows = await d.query('transfers',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'itemName': r['item_name'],
              'requestedQty': r['requested_qty'],
              'approvedQty': r['approved_qty'],
              'unit': r['unit'],
              'fromWholesale': r['from_wholesale'] == 1,
              'notes': r['notes'],
              'status': r['status'],
              'date': r['date'],
              'createdAt': r['date'],
            })
        .toList();
  }

  Future<Map<String, dynamic>> createTransfer({
    required String itemName,
    required double requestedQty,
    String unit = 'Pcs',
    bool fromWholesale = true,
    String notes = '',
  }) async {
    final id = await (await db).insert('transfers', {
      'item_name': itemName,
      'requested_qty': requestedQty,
      'approved_qty': 0,
      'unit': unit,
      'from_wholesale': fromWholesale ? 1 : 0,
      'notes': notes,
      'status': 'pending',
      'date': _now(),
    });
    return {
      'id': id,
      'itemName': itemName,
      'requestedQty': requestedQty,
      'status': 'pending'
    };
  }

  Future<Map<String, dynamic>> approveTransfer(int id, double approvedQty) async {
    final d = await db;
    final rows = await d.query('transfers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Transfer not found');
    final currentStatus = rows.first['status'] as String?;
    if (currentStatus != 'pending') {
      throw Exception('Transfer is already $currentStatus');
    }
    await d.update('transfers', {'status': 'approved', 'approved_qty': approvedQty},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'status': 'approved', 'approvedQty': approvedQty};
  }

  Future<Map<String, dynamic>> rejectTransfer(int id) async {
    await (await db).update('transfers', {'status': 'rejected'},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'status': 'rejected'};
  }

  Future<Map<String, dynamic>> receiveTransfer(int id) async {
    final d = await db;

    // Fetch the transfer record
    final rows = await d.query('transfers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Transfer not found');
    final t = rows.first;

    final currentStatus = t['status'] as String?;
    if (currentStatus != 'approved') {
      throw Exception('Transfer must be approved before it can be received');
    }

    final itemName = t['item_name'] as String;
    final approvedQty = (t['approved_qty'] as int?) ?? 0;
    final fromWholesale = (t['from_wholesale'] as int?) == 1;
    final srcStore = fromWholesale ? 'wholesale' : 'retail';
    final dstStore = fromWholesale ? 'retail' : 'wholesale';

    if (approvedQty > 0) {
      // Deduct from source store item (match by name, case-insensitive)
      final srcRows = await d.query('items',
          where: 'LOWER(name) = LOWER(?) AND store = ?',
          whereArgs: [itemName, srcStore]);
      if (srcRows.isNotEmpty) {
        final srcId = srcRows.first['id'] as int;
        final srcStock = srcRows.first['stock'] as int;
        final newStock = srcStock - approvedQty;
        await d.update('items', {'stock': newStock < 0 ? 0 : newStock},
            where: 'id = ?', whereArgs: [srcId]);
      }

      // Add to destination store item (match by name, case-insensitive)
      final dstRows = await d.query('items',
          where: 'LOWER(name) = LOWER(?) AND store = ?',
          whereArgs: [itemName, dstStore]);
      if (dstRows.isNotEmpty) {
        final dstId = dstRows.first['id'] as int;
        final dstStock = dstRows.first['stock'] as int;
        await d.update('items', {'stock': dstStock + approvedQty},
            where: 'id = ?', whereArgs: [dstId]);
      }
    }

    await d.update('transfers', {'status': 'received'},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'status': 'received'};
  }

  // ── PAYMENT REQUESTS ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPaymentRequests(
      {String? status}) async {
    final d = await db;
    final rows = status != null
        ? await d.query('payment_requests',
            where: 'status = ?',
            whereArgs: [status],
            orderBy: 'created_at DESC')
        : await d.query('payment_requests', orderBy: 'created_at DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'items': jsonDecode(r['items_json'] as String),
              'totalAmount': (r['total_amount'] as num).toDouble(),
              'customerId': r['customer_id'],
              'cashierId': r['cashier_id'],
              'paymentType': r['payment_type'],
              'status': r['status'],
              'patientName': r['patient_name'] ?? '',
              'createdAt': r['created_at'],
            })
        .toList();
  }

  Future<Map<String, dynamic>> createPaymentRequest(
      List<Map<String, dynamic>> items,
      {int? customerId,
      int? cashierId,
      String paymentType = 'retail',
      String? patientName}) async {
    final total = items.fold<double>(
        0,
        (s, i) =>
            s +
            ((i['price'] ?? 0) as num).toDouble() *
                ((i['quantity'] ?? 1) as num).toDouble());
    final id = await (await db).insert('payment_requests', {
      'items_json': jsonEncode(items),
      'total_amount': total,
      'customer_id': customerId,
      'cashier_id': cashierId,
      'payment_type': paymentType,
      'patient_name': patientName ?? '',
      'status': 'pending',
      'created_at': _now(),
    });
    return {
      'id': id,
      'totalAmount': total,
      'status': 'pending',
      'patientName': patientName ?? ''
    };
  }

  Future<Map<String, dynamic>> updatePaymentRequestStatus(
      int id, String status) async {
    await (await db).update('payment_requests', {'status': status},
        where: 'id = ?', whereArgs: [id]);
    return {'id': id, 'status': status};
  }

  // ── DISPENSING LOG ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDispensingLog(
      {String? search, String? from, String? to}) async {
    final d = await db;
    final conds = <String>[];
    final args = <dynamic>[];
    if (search != null && search.isNotEmpty) {
      conds.add('(item_name LIKE ? OR patient_name LIKE ?)');
      args.addAll(['%$search%', '%$search%']);
    }
    if (from != null) {
      conds.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      conds.add('date <= ?');
      args.add(to);
    }
    final rows = await d.query('dispensing_log',
        where: conds.isEmpty ? null : conds.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'date DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'itemId': r['item_id'],
              'itemName': r['item_name'],
              'quantity': r['quantity'],
              'patientName': r['patient_name'],
              'prescriptionNo': r['prescription_no'],
              'date': r['date'],
            })
        .toList();
  }

  Future<Map<String, dynamic>> getDispensingStats() async {
    final d = await db;
    final total = await d.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(quantity),0) as total FROM dispensing_log');
    final today = await d.rawQuery(
        "SELECT COUNT(*) as cnt FROM dispensing_log WHERE date(date) = date('now')");
    return {
      'totalDispensed': total.first['total'] ?? 0,
      'totalEntries': total.first['cnt'] ?? 0,
      'todayCount': today.first['cnt'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> addDispensingEntry({
    required int itemId,
    required String itemName,
    required int quantity,
    String patientName = '',
    String prescriptionNo = '',
    int? dispensedBy,
  }) async {
    final id = await (await db).insert('dispensing_log', {
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'patient_name': patientName,
      'prescription_no': prescriptionNo,
      'dispensed_by': dispensedBy,
      'date': _now(),
    });
    return {'id': id, 'itemName': itemName, 'quantity': quantity};
  }

  // ── NOTIFICATIONS ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final rows = await (await db)
        .query('notifications', orderBy: 'date DESC', limit: 50);
    return rows
        .map((r) => {
              'id': r['id'],
              'message': r['message'],
              'type': r['type'],
              'isRead': r['is_read'] == 1,
              'date': r['date'],
            })
        .toList();
  }

  Future<int> getUnreadCount() async {
    final rows = await (await db).rawQuery(
        "SELECT COUNT(*) as cnt FROM notifications WHERE is_read = 0");
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int id) async =>
      (await db).update('notifications', {'is_read': 1},
          where: 'id = ?', whereArgs: [id]);

  Future<void> addNotification(String message, String type) async =>
      (await db).insert('notifications',
          {'message': message, 'type': type, 'is_read': 0, 'date': _now()});

  // ── REPORTS ────────────────────────────────────────────────────────────────

  String _periodWhere(String period, {String table = ''}) {
    final col = table.isEmpty ? 'created_at' : '$table.created_at';
    if (period.startsWith('custom:')) {
      final parts = period.split(':');
      if (parts.length >= 3) {
        return "$col >= '${parts[1]}' AND $col <= '${parts[2]} 23:59:59'";
      }
    }
    switch (period) {
      case 'today':
        return "date($col) = date('now')";
      case 'week':
        return "$col >= datetime('now', '-7 days')";
      case 'month':
        return "$col >= datetime('now', '-1 month')";
      case 'quarter':
        return "$col >= datetime('now', '-3 months')";
      case 'year':
        return "$col >= datetime('now', '-1 year')";
      default:
        return "$col >= datetime('now', '-30 days')";
    }
  }

  Future<Map<String, dynamic>> getSalesReport(String period) async {
    final d = await db;
    final w = _periodWhere(period);
    final rows = await d.rawQuery('''
      SELECT COALESCE(SUM(total_amount),0) as total,
             COALESCE(SUM(CASE WHEN is_wholesale=0 THEN total_amount ELSE 0 END),0) as retail,
             COALESCE(SUM(CASE WHEN is_wholesale=1 THEN total_amount ELSE 0 END),0) as wholesale,
             COUNT(*) as cnt
      FROM sales WHERE $w AND status='completed' ''');
    final top = await d.rawQuery('''
      SELECT si.item_name as name, SUM(si.quantity) as qty,
             SUM(si.price*si.quantity-si.discount) as revenue
      FROM sale_items si JOIN sales s ON s.id=si.sale_id
      WHERE ${_periodWhere(period, table: 's')} AND s.status='completed'
      GROUP BY si.item_name ORDER BY revenue DESC LIMIT 5''');
    final r = rows.first;
    return {
      'period': period,
      'totalRevenue': (r['total'] as num).toDouble(),
      'totalRetail': (r['retail'] as num).toDouble(),
      'totalWholesale': (r['wholesale'] as num).toDouble(),
      'totalSales': r['cnt'],
      'topItems': top
          .map((i) => {
                'itemId': 0,
                'name': i['name'],
                'qty': i['qty'],
                'revenue': i['revenue'] ?? 0,
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> getInventoryReport() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(cost_price*stock),0) as val FROM items');
    final low = await d.rawQuery(
        'SELECT id,name,stock,low_stock_threshold FROM items WHERE stock<=low_stock_threshold ORDER BY stock ASC');
    return {
      'totalItems': rows.first['cnt'] ?? 0,
      'lowStockCount': low.length,
      'stockValue': (rows.first['val'] as num? ?? 0).toDouble(),
      'lowStockItems': low
          .map((i) => {
                'id': i['id'],
                'name': i['name'],
                'stock': i['stock'],
                'lowStockThreshold': i['low_stock_threshold'],
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> getCustomerReport() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT COUNT(*) as total,
             SUM(CASE WHEN is_wholesale=0 THEN 1 ELSE 0 END) as retail,
             SUM(CASE WHEN is_wholesale=1 THEN 1 ELSE 0 END) as wholesale,
             COALESCE(SUM(outstanding_debt),0) as debt
      FROM customers''');
    final top = await d.rawQuery(
        'SELECT id,name,total_purchases as spent FROM customers ORDER BY total_purchases DESC LIMIT 5');
    final r = rows.first;
    return {
      'total': r['total'] ?? 0,
      'retail': r['retail'] ?? 0,
      'wholesale': r['wholesale'] ?? 0,
      'totalDebt': (r['debt'] as num? ?? 0).toDouble(),
      'topCustomers': top
          .map((c) => {
                'id': c['id'],
                'name': c['name'],
                'spent': c['spent'] ?? 0,
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> getProfitReport(String period) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT COALESCE(SUM(s.total_amount),0) as revenue,
             COALESCE(SUM(si.cost_price*si.quantity),0) as cost
      FROM sales s LEFT JOIN sale_items si ON si.sale_id=s.id
      WHERE ${_periodWhere(period, table: 's')} AND s.status='completed' ''');
    final revenue = (rows.first['revenue'] as num? ?? 0).toDouble();
    final cost = (rows.first['cost'] as num? ?? 0).toDouble();
    final profit = revenue - cost;
    return {
      'period': period,
      'revenue': revenue,
      'profit': profit,
      'margin': revenue > 0 ? (profit / revenue * 100) : 0.0,
    };
  }

  Future<Map<String, dynamic>> getMonthlyReport({int? month, int? year}) async {
    final d = await db;
    final now = DateTime.now();
    final m = (month ?? now.month).toString().padLeft(2, '0');
    final y = (year ?? now.year).toString();
    final daily = await d.rawQuery('''
      SELECT strftime('%d', created_at) as day,
             SUM(total_amount) as revenue, COUNT(*) as cnt
      FROM sales WHERE strftime('%m',created_at)=? AND strftime('%Y',created_at)=?
        AND status='completed'
      GROUP BY day ORDER BY day ASC''', [m, y]);
    final total = await d.rawQuery('''
      SELECT COALESCE(SUM(total_amount),0) as revenue, COUNT(*) as cnt
      FROM sales WHERE strftime('%m',created_at)=? AND strftime('%Y',created_at)=?
        AND status='completed' ''', [m, y]);
    return {
      'month': int.parse(m),
      'year': int.parse(y),
      'totalRevenue': (total.first['revenue'] as num? ?? 0).toDouble(),
      'totalSales': total.first['cnt'] ?? 0,
      'dailyData': daily
          .map((r) => {
                'day': r['day'],
                'revenue': r['revenue'] ?? 0,
                'count': r['cnt'] ?? 0,
              })
          .toList(),
    };
  }

  // ── WHOLESALE DASHBOARD ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWholesaleDashboard() async {
    final d = await db;
    final today = await d.rawQuery('''
      SELECT COALESCE(SUM(total_amount),0) as rev, COUNT(*) as cnt
      FROM sales WHERE is_wholesale=1 AND date(created_at)=date('now') AND status='completed' ''');
    final unitsToday = await d.rawQuery('''
      SELECT COALESCE(SUM(si.quantity),0) as units
      FROM sale_items si JOIN sales s ON si.sale_id=s.id
      WHERE s.is_wholesale=1 AND date(s.created_at)=date('now') AND s.status='completed' ''');
    final debt = await d.rawQuery(
        "SELECT COALESCE(SUM(outstanding_debt),0) as d FROM customers WHERE is_wholesale=1");
    final custCount = await d
        .rawQuery("SELECT COUNT(*) as cnt FROM customers WHERE is_wholesale=1");
    final lowStock = await d.rawQuery(
        "SELECT COUNT(*) as cnt FROM items WHERE store='wholesale' AND stock<=low_stock_threshold");

    // Top products today
    final topProductsRows = await d.rawQuery('''
      SELECT si.name, SUM(si.quantity) as qty, SUM(si.quantity * si.price) as revenue
      FROM sale_items si JOIN sales s ON si.sale_id=s.id
      WHERE s.is_wholesale=1 AND date(s.created_at)=date('now') AND s.status='completed'
      GROUP BY si.name ORDER BY qty DESC LIMIT 5 ''');

    // Pending transfers
    final pendingTransfersRows = await d.query('transfers',
        where: 'status = ?', whereArgs: ['pending'], orderBy: 'date DESC');

    return {
      'todayRevenue': (today.first['rev'] as num? ?? 0).toDouble(),
      'revenueToday':
          (today.first['rev'] as num? ?? 0).toDouble(), // legacy alias
      'salesToday': today.first['cnt'] ?? 0,
      'unitsSold': (unitsToday.first['units'] as num? ?? 0).toInt(),
      'unitsSoldToday':
          (unitsToday.first['units'] as num? ?? 0).toInt(), // legacy alias
      'outstandingDebt': (debt.first['d'] as num? ?? 0).toDouble(),
      'wholesaleDebt':
          (debt.first['d'] as num? ?? 0).toDouble(), // legacy alias
      'wholesaleCustomers': custCount.first['cnt'] ?? 0,
      'lowStockCount': lowStock.first['cnt'] ?? 0,
      'topProducts': topProductsRows
          .map((r) => {
                'name': r['name'] ?? 'Unknown',
                'qty': (r['qty'] as num? ?? 0).toInt(),
                'revenue': (r['revenue'] as num? ?? 0).toDouble(),
              })
          .toList(),
      'pendingTransfers': pendingTransfersRows
          .map((t) => {
                'id': t['id'],
                'itemName': t['item_name'],
                'requestedQty': t['requested_qty'],
                'approvedQty': t['approved_qty'],
                'unit': t['unit'],
                'fromWholesale': t['from_wholesale'] == 1,
                'status': t['status'],
                'notes': t['notes'],
              })
          .toList(),
    };
  }

  Future<List<Map<String, dynamic>>> getWholesaleSalesByUser(
      {String? from, String? to}) async {
    final d = await db;
    final conds = <String>['is_wholesale = 1', "status = 'completed'"];
    final args = <dynamic>[];
    if (from != null) {
      conds.add('created_at >= ?');
      args.add(from);
    }
    if (to != null) {
      conds.add('created_at <= ?');
      args.add(to);
    }

    // Aggregate sales by served_by user
    final rows = await d.rawQuery('''
      SELECT s.served_by, u.username, u.phone_number,
             COUNT(*) as sale_count,
             COALESCE(SUM(s.total_amount), 0) as total_amount
      FROM sales s
      LEFT JOIN users u ON u.id = s.served_by
      WHERE ${conds.join(' AND ')}
      GROUP BY s.served_by
      ORDER BY total_amount DESC
    ''', args);

    // For each user, also get total items sold
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final servedBy = row['served_by'];
      int totalItems = 0;
      if (servedBy != null) {
        final itemRows = await d.rawQuery('''
          SELECT COALESCE(SUM(si.quantity), 0) as total_items
          FROM sale_items si
          JOIN sales s ON s.id = si.sale_id
          WHERE s.served_by = ? AND s.is_wholesale = 1 AND s.status = 'completed'
          ${from != null ? "AND s.created_at >= ?" : ""}
          ${to != null ? "AND s.created_at <= ?" : ""}
        ''', [servedBy, if (from != null) from, if (to != null) to]);
        totalItems = (itemRows.first['total_items'] as num?)?.toInt() ?? 0;
      }
      final username = (row['username'] as String?) ?? '';
      final phone = (row['phone_number'] as String?) ?? '';
      final name = username.isNotEmpty
          ? username
          : (phone.isNotEmpty ? phone : 'Unknown');
      result.add({
        'userName': name,
        'totalItems': totalItems,
        'totalAmount': (row['total_amount'] as num?)?.toDouble() ?? 0.0,
        'saleCount': row['sale_count'] ?? 0,
      });
    }
    return result;
  }

  Future<Map<String, dynamic>> getWholesaleInventoryValue() async {
    final d = await db;
    final rows = await d
        .rawQuery("SELECT COALESCE(SUM(cost_price*stock),0) as purchase_val, "
            "COALESCE(SUM(price*stock),0) as stock_val, COUNT(*) as cnt "
            "FROM items WHERE store='wholesale'");
    final purchase = (rows.first['purchase_val'] as num? ?? 0).toDouble();
    final stockVal = (rows.first['stock_val'] as num? ?? 0).toDouble();
    return {
      'totalPurchaseValue': purchase,
      'totalStockValue': stockVal,
      'potentialProfit': stockVal - purchase,
      'totalItems': rows.first['cnt'] ?? 0,
      // legacy aliases
      'totalValue': stockVal,
      'itemCount': rows.first['cnt'] ?? 0,
    };
  }
}
