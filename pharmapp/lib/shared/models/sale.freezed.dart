// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SaleItemPayload _$SaleItemPayloadFromJson(Map<String, dynamic> json) {
  return _SaleItemPayload.fromJson(json);
}

/// @nodoc
mixin _$SaleItemPayload {
  String get barcode => throw _privateConstructorUsedError;
  int? get itemId => throw _privateConstructorUsedError;
  double get quantity => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  double get discount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SaleItemPayloadCopyWith<SaleItemPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SaleItemPayloadCopyWith<$Res> {
  factory $SaleItemPayloadCopyWith(
          SaleItemPayload value, $Res Function(SaleItemPayload) then) =
      _$SaleItemPayloadCopyWithImpl<$Res, SaleItemPayload>;
  @useResult
  $Res call({String barcode, int? itemId, double quantity, double price, double discount});
}

/// @nodoc
class _$SaleItemPayloadCopyWithImpl<$Res, $Val extends SaleItemPayload>
    implements $SaleItemPayloadCopyWith<$Res> {
  _$SaleItemPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? barcode = null,
    Object? itemId = freezed,
    Object? quantity = null,
    Object? price = null,
    Object? discount = null,
  }) {
    return _then(_value.copyWith(
      barcode: null == barcode
          ? _value.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String,
      itemId: freezed == itemId
          ? _value.itemId
          : itemId // ignore: cast_nullable_to_non_nullable
              as int?,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SaleItemPayloadImplCopyWith<$Res>
    implements $SaleItemPayloadCopyWith<$Res> {
  factory _$$SaleItemPayloadImplCopyWith(_$SaleItemPayloadImpl value,
          $Res Function(_$SaleItemPayloadImpl) then) =
      __$$SaleItemPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String barcode, int? itemId, double quantity, double price, double discount});
}

/// @nodoc
class __$$SaleItemPayloadImplCopyWithImpl<$Res>
    extends _$SaleItemPayloadCopyWithImpl<$Res, _$SaleItemPayloadImpl>
    implements _$$SaleItemPayloadImplCopyWith<$Res> {
  __$$SaleItemPayloadImplCopyWithImpl(
      _$SaleItemPayloadImpl _value, $Res Function(_$SaleItemPayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? barcode = null,
    Object? itemId = freezed,
    Object? quantity = null,
    Object? price = null,
    Object? discount = null,
  }) {
    return _then(_$SaleItemPayloadImpl(
      barcode: null == barcode
          ? _value.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String,
      itemId: freezed == itemId
          ? _value.itemId
          : itemId // ignore: cast_nullable_to_non_nullable
              as int?,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _value.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SaleItemPayloadImpl implements _SaleItemPayload {
  const _$SaleItemPayloadImpl(
      {required this.barcode,
      required this.itemId,
      required this.quantity,
      required this.price,
      this.discount = 0.0});

  factory _$SaleItemPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SaleItemPayloadImplFromJson(json);

  @override
  final String barcode;
  @override
  final int? itemId;
  @override
  final double quantity;
  @override
  final double price;
  @override
  @JsonKey()
  final double discount;

  @override
  String toString() {
    return 'SaleItemPayload(barcode: $barcode, itemId: $itemId, quantity: $quantity, price: $price, discount: $discount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SaleItemPayloadImpl &&
            (identical(other.barcode, barcode) || other.barcode == barcode) &&
            (identical(other.itemId, itemId) || other.itemId == itemId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.discount, discount) || other.discount == discount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, barcode, itemId, quantity, price, discount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SaleItemPayloadImplCopyWith<_$SaleItemPayloadImpl> get copyWith =>
      __$$SaleItemPayloadImplCopyWithImpl<_$SaleItemPayloadImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SaleItemPayloadImplToJson(
      this,
    );
  }
}

abstract class _SaleItemPayload implements SaleItemPayload {
  const factory _SaleItemPayload(
      {required final String barcode,
      required final int? itemId,
      required final double quantity,
      required final double price,
      final double discount}) = _$SaleItemPayloadImpl;

  factory _SaleItemPayload.fromJson(Map<String, dynamic> json) =
      _$SaleItemPayloadImpl.fromJson;

  @override
  String get barcode;
  @override
  int? get itemId;
  @override
  double get quantity;
  @override
  double get price;
  @override
  double get discount;
  @override
  @JsonKey(ignore: true)
  _$$SaleItemPayloadImplCopyWith<_$SaleItemPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentPayload _$PaymentPayloadFromJson(Map<String, dynamic> json) {
  return _PaymentPayload.fromJson(json);
}

/// @nodoc
mixin _$PaymentPayload {
  double get cash => throw _privateConstructorUsedError;
  double get pos => throw _privateConstructorUsedError;
  double get bankTransfer => throw _privateConstructorUsedError;
  double get wallet => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PaymentPayloadCopyWith<PaymentPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentPayloadCopyWith<$Res> {
  factory $PaymentPayloadCopyWith(
          PaymentPayload value, $Res Function(PaymentPayload) then) =
      _$PaymentPayloadCopyWithImpl<$Res, PaymentPayload>;
  @useResult
  $Res call({double cash, double pos, double bankTransfer, double wallet});
}

/// @nodoc
class _$PaymentPayloadCopyWithImpl<$Res, $Val extends PaymentPayload>
    implements $PaymentPayloadCopyWith<$Res> {
  _$PaymentPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cash = null,
    Object? pos = null,
    Object? bankTransfer = null,
    Object? wallet = null,
  }) {
    return _then(_value.copyWith(
      cash: null == cash
          ? _value.cash
          : cash // ignore: cast_nullable_to_non_nullable
              as double,
      pos: null == pos
          ? _value.pos
          : pos // ignore: cast_nullable_to_non_nullable
              as double,
      bankTransfer: null == bankTransfer
          ? _value.bankTransfer
          : bankTransfer // ignore: cast_nullable_to_non_nullable
              as double,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentPayloadImplCopyWith<$Res>
    implements $PaymentPayloadCopyWith<$Res> {
  factory _$$PaymentPayloadImplCopyWith(_$PaymentPayloadImpl value,
          $Res Function(_$PaymentPayloadImpl) then) =
      __$$PaymentPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double cash, double pos, double bankTransfer, double wallet});
}

/// @nodoc
class __$$PaymentPayloadImplCopyWithImpl<$Res>
    extends _$PaymentPayloadCopyWithImpl<$Res, _$PaymentPayloadImpl>
    implements _$$PaymentPayloadImplCopyWith<$Res> {
  __$$PaymentPayloadImplCopyWithImpl(
      _$PaymentPayloadImpl _value, $Res Function(_$PaymentPayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cash = null,
    Object? pos = null,
    Object? bankTransfer = null,
    Object? wallet = null,
  }) {
    return _then(_$PaymentPayloadImpl(
      cash: null == cash
          ? _value.cash
          : cash // ignore: cast_nullable_to_non_nullable
              as double,
      pos: null == pos
          ? _value.pos
          : pos // ignore: cast_nullable_to_non_nullable
              as double,
      bankTransfer: null == bankTransfer
          ? _value.bankTransfer
          : bankTransfer // ignore: cast_nullable_to_non_nullable
              as double,
      wallet: null == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentPayloadImpl implements _PaymentPayload {
  const _$PaymentPayloadImpl(
      {this.cash = 0.0,
      this.pos = 0.0,
      this.bankTransfer = 0.0,
      this.wallet = 0.0});

  factory _$PaymentPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentPayloadImplFromJson(json);

  @override
  @JsonKey()
  final double cash;
  @override
  @JsonKey()
  final double pos;
  @override
  @JsonKey()
  final double bankTransfer;
  @override
  @JsonKey()
  final double wallet;

  @override
  String toString() {
    return 'PaymentPayload(cash: $cash, pos: $pos, bankTransfer: $bankTransfer, wallet: $wallet)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentPayloadImpl &&
            (identical(other.cash, cash) || other.cash == cash) &&
            (identical(other.pos, pos) || other.pos == pos) &&
            (identical(other.bankTransfer, bankTransfer) ||
                other.bankTransfer == bankTransfer) &&
            (identical(other.wallet, wallet) || other.wallet == wallet));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, cash, pos, bankTransfer, wallet);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentPayloadImplCopyWith<_$PaymentPayloadImpl> get copyWith =>
      __$$PaymentPayloadImplCopyWithImpl<_$PaymentPayloadImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentPayloadImplToJson(
      this,
    );
  }
}

abstract class _PaymentPayload implements PaymentPayload {
  const factory _PaymentPayload(
      {final double cash,
      final double pos,
      final double bankTransfer,
      final double wallet}) = _$PaymentPayloadImpl;

  factory _PaymentPayload.fromJson(Map<String, dynamic> json) =
      _$PaymentPayloadImpl.fromJson;

  @override
  double get cash;
  @override
  double get pos;
  @override
  double get bankTransfer;
  @override
  double get wallet;
  @override
  @JsonKey(ignore: true)
  _$$PaymentPayloadImplCopyWith<_$PaymentPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CheckoutPayload _$CheckoutPayloadFromJson(Map<String, dynamic> json) {
  return _CheckoutPayload.fromJson(json);
}

/// @nodoc
mixin _$CheckoutPayload {
  List<SaleItemPayload> get items => throw _privateConstructorUsedError;
  PaymentPayload get payment => throw _privateConstructorUsedError;
  int? get customerId => throw _privateConstructorUsedError;
  bool? get isWholesale => throw _privateConstructorUsedError;
  String? get paymentMethod => throw _privateConstructorUsedError;
  double get totalAmount => throw _privateConstructorUsedError;
  String? get patientName => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CheckoutPayloadCopyWith<CheckoutPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckoutPayloadCopyWith<$Res> {
  factory $CheckoutPayloadCopyWith(
          CheckoutPayload value, $Res Function(CheckoutPayload) then) =
      _$CheckoutPayloadCopyWithImpl<$Res, CheckoutPayload>;
  @useResult
  $Res call(
      {List<SaleItemPayload> items,
      PaymentPayload payment,
      int? customerId,
      bool? isWholesale,
      String? paymentMethod,
      double totalAmount,
      String? patientName});

  $PaymentPayloadCopyWith<$Res> get payment;
}

/// @nodoc
class _$CheckoutPayloadCopyWithImpl<$Res, $Val extends CheckoutPayload>
    implements $CheckoutPayloadCopyWith<$Res> {
  _$CheckoutPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? payment = null,
    Object? customerId = freezed,
    Object? isWholesale = freezed,
    Object? paymentMethod = freezed,
    Object? totalAmount = null,
    Object? patientName = freezed,
  }) {
    return _then(_value.copyWith(
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SaleItemPayload>,
      payment: null == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as PaymentPayload,
      customerId: freezed == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as int?,
      isWholesale: freezed == isWholesale
          ? _value.isWholesale
          : isWholesale // ignore: cast_nullable_to_non_nullable
              as bool?,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      patientName: freezed == patientName
          ? _value.patientName
          : patientName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $PaymentPayloadCopyWith<$Res> get payment {
    return $PaymentPayloadCopyWith<$Res>(_value.payment, (value) {
      return _then(_value.copyWith(payment: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CheckoutPayloadImplCopyWith<$Res>
    implements $CheckoutPayloadCopyWith<$Res> {
  factory _$$CheckoutPayloadImplCopyWith(_$CheckoutPayloadImpl value,
          $Res Function(_$CheckoutPayloadImpl) then) =
      __$$CheckoutPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<SaleItemPayload> items,
      PaymentPayload payment,
      int? customerId,
      bool? isWholesale,
      String? paymentMethod,
      double totalAmount,
      String? patientName});

  @override
  $PaymentPayloadCopyWith<$Res> get payment;
}

/// @nodoc
class __$$CheckoutPayloadImplCopyWithImpl<$Res>
    extends _$CheckoutPayloadCopyWithImpl<$Res, _$CheckoutPayloadImpl>
    implements _$$CheckoutPayloadImplCopyWith<$Res> {
  __$$CheckoutPayloadImplCopyWithImpl(
      _$CheckoutPayloadImpl _value, $Res Function(_$CheckoutPayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? payment = null,
    Object? customerId = freezed,
    Object? isWholesale = freezed,
    Object? paymentMethod = freezed,
    Object? totalAmount = null,
    Object? patientName = freezed,
  }) {
    return _then(_$CheckoutPayloadImpl(
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SaleItemPayload>,
      payment: null == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as PaymentPayload,
      customerId: freezed == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as int?,
      isWholesale: freezed == isWholesale
          ? _value.isWholesale
          : isWholesale // ignore: cast_nullable_to_non_nullable
              as bool?,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      patientName: freezed == patientName
          ? _value.patientName
          : patientName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckoutPayloadImpl implements _CheckoutPayload {
  const _$CheckoutPayloadImpl(
      {required final List<SaleItemPayload> items,
      required this.payment,
      this.customerId,
      this.isWholesale,
      this.paymentMethod,
      required this.totalAmount,
      this.patientName})
      : _items = items;

  factory _$CheckoutPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckoutPayloadImplFromJson(json);

  final List<SaleItemPayload> _items;
  @override
  List<SaleItemPayload> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final PaymentPayload payment;
  @override
  final int? customerId;
  @override
  final bool? isWholesale;
  @override
  final String? paymentMethod;
  @override
  final double totalAmount;
  @override
  final String? patientName;

  @override
  String toString() {
    return 'CheckoutPayload(items: $items, payment: $payment, customerId: $customerId, isWholesale: $isWholesale, paymentMethod: $paymentMethod, totalAmount: $totalAmount, patientName: $patientName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckoutPayloadImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.payment, payment) ||
                other.payment == payment) &&
            (identical(other.customerId, customerId) ||
                other.customerId == customerId) &&
            (identical(other.isWholesale, isWholesale) ||
                other.isWholesale == isWholesale) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.patientName, patientName) ||
                other.patientName == patientName));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_items),
      payment,
      customerId,
      isWholesale,
      paymentMethod,
      totalAmount,
      patientName);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckoutPayloadImplCopyWith<_$CheckoutPayloadImpl> get copyWith =>
      __$$CheckoutPayloadImplCopyWithImpl<_$CheckoutPayloadImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckoutPayloadImplToJson(
      this,
    );
  }
}

abstract class _CheckoutPayload implements CheckoutPayload {
  const factory _CheckoutPayload(
      {required final List<SaleItemPayload> items,
      required final PaymentPayload payment,
      final int? customerId,
      final bool? isWholesale,
      final String? paymentMethod,
      required final double totalAmount,
      final String? patientName}) = _$CheckoutPayloadImpl;

  factory _CheckoutPayload.fromJson(Map<String, dynamic> json) =
      _$CheckoutPayloadImpl.fromJson;

  @override
  List<SaleItemPayload> get items;
  @override
  PaymentPayload get payment;
  @override
  int? get customerId;
  @override
  bool? get isWholesale;
  @override
  String? get paymentMethod;
  @override
  double get totalAmount;
  @override
  String? get patientName;
  @override
  @JsonKey(ignore: true)
  _$$CheckoutPayloadImplCopyWith<_$CheckoutPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
