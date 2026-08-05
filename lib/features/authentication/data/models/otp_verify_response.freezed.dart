// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'otp_verify_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OtpVerifyResponse {

 int? get status;@JsonKey(name: 'customer_Id') dynamic get customerId;@JsonKey(name: 'device_id') dynamic get deviceId;@JsonKey(name: 'access_token') String? get accessToken;@JsonKey(name: 'refresh') String? get refresh;@JsonKey(name: 'customer_type') dynamic get customerType;@JsonKey(name: 'appsflyer_id') dynamic get appsflyerId;
/// Create a copy of OtpVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OtpVerifyResponseCopyWith<OtpVerifyResponse> get copyWith => _$OtpVerifyResponseCopyWithImpl<OtpVerifyResponse>(this as OtpVerifyResponse, _$identity);

  /// Serializes this OtpVerifyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OtpVerifyResponse&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.customerId, customerId)&&const DeepCollectionEquality().equals(other.deviceId, deviceId)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refresh, refresh) || other.refresh == refresh)&&const DeepCollectionEquality().equals(other.customerType, customerType)&&const DeepCollectionEquality().equals(other.appsflyerId, appsflyerId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(customerId),const DeepCollectionEquality().hash(deviceId),accessToken,refresh,const DeepCollectionEquality().hash(customerType),const DeepCollectionEquality().hash(appsflyerId));

@override
String toString() {
  return 'OtpVerifyResponse(status: $status, customerId: $customerId, deviceId: $deviceId, accessToken: $accessToken, refresh: $refresh, customerType: $customerType, appsflyerId: $appsflyerId)';
}


}

/// @nodoc
abstract mixin class $OtpVerifyResponseCopyWith<$Res>  {
  factory $OtpVerifyResponseCopyWith(OtpVerifyResponse value, $Res Function(OtpVerifyResponse) _then) = _$OtpVerifyResponseCopyWithImpl;
@useResult
$Res call({
 int? status,@JsonKey(name: 'customer_Id') dynamic customerId,@JsonKey(name: 'device_id') dynamic deviceId,@JsonKey(name: 'access_token') String? accessToken,@JsonKey(name: 'refresh') String? refresh,@JsonKey(name: 'customer_type') dynamic customerType,@JsonKey(name: 'appsflyer_id') dynamic appsflyerId
});




}
/// @nodoc
class _$OtpVerifyResponseCopyWithImpl<$Res>
    implements $OtpVerifyResponseCopyWith<$Res> {
  _$OtpVerifyResponseCopyWithImpl(this._self, this._then);

  final OtpVerifyResponse _self;
  final $Res Function(OtpVerifyResponse) _then;

/// Create a copy of OtpVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? customerId = freezed,Object? deviceId = freezed,Object? accessToken = freezed,Object? refresh = freezed,Object? customerType = freezed,Object? appsflyerId = freezed,}) {
  return _then(_self.copyWith(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as dynamic,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as dynamic,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refresh: freezed == refresh ? _self.refresh : refresh // ignore: cast_nullable_to_non_nullable
as String?,customerType: freezed == customerType ? _self.customerType : customerType // ignore: cast_nullable_to_non_nullable
as dynamic,appsflyerId: freezed == appsflyerId ? _self.appsflyerId : appsflyerId // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [OtpVerifyResponse].
extension OtpVerifyResponsePatterns on OtpVerifyResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OtpVerifyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OtpVerifyResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OtpVerifyResponse value)  $default,){
final _that = this;
switch (_that) {
case _OtpVerifyResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OtpVerifyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OtpVerifyResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? status, @JsonKey(name: 'customer_Id')  dynamic customerId, @JsonKey(name: 'device_id')  dynamic deviceId, @JsonKey(name: 'access_token')  String? accessToken, @JsonKey(name: 'refresh')  String? refresh, @JsonKey(name: 'customer_type')  dynamic customerType, @JsonKey(name: 'appsflyer_id')  dynamic appsflyerId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OtpVerifyResponse() when $default != null:
return $default(_that.status,_that.customerId,_that.deviceId,_that.accessToken,_that.refresh,_that.customerType,_that.appsflyerId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? status, @JsonKey(name: 'customer_Id')  dynamic customerId, @JsonKey(name: 'device_id')  dynamic deviceId, @JsonKey(name: 'access_token')  String? accessToken, @JsonKey(name: 'refresh')  String? refresh, @JsonKey(name: 'customer_type')  dynamic customerType, @JsonKey(name: 'appsflyer_id')  dynamic appsflyerId)  $default,) {final _that = this;
switch (_that) {
case _OtpVerifyResponse():
return $default(_that.status,_that.customerId,_that.deviceId,_that.accessToken,_that.refresh,_that.customerType,_that.appsflyerId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? status, @JsonKey(name: 'customer_Id')  dynamic customerId, @JsonKey(name: 'device_id')  dynamic deviceId, @JsonKey(name: 'access_token')  String? accessToken, @JsonKey(name: 'refresh')  String? refresh, @JsonKey(name: 'customer_type')  dynamic customerType, @JsonKey(name: 'appsflyer_id')  dynamic appsflyerId)?  $default,) {final _that = this;
switch (_that) {
case _OtpVerifyResponse() when $default != null:
return $default(_that.status,_that.customerId,_that.deviceId,_that.accessToken,_that.refresh,_that.customerType,_that.appsflyerId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OtpVerifyResponse implements OtpVerifyResponse {
  const _OtpVerifyResponse({this.status, @JsonKey(name: 'customer_Id') this.customerId, @JsonKey(name: 'device_id') this.deviceId, @JsonKey(name: 'access_token') this.accessToken, @JsonKey(name: 'refresh') this.refresh, @JsonKey(name: 'customer_type') this.customerType, @JsonKey(name: 'appsflyer_id') this.appsflyerId});
  factory _OtpVerifyResponse.fromJson(Map<String, dynamic> json) => _$OtpVerifyResponseFromJson(json);

@override final  int? status;
@override@JsonKey(name: 'customer_Id') final  dynamic customerId;
@override@JsonKey(name: 'device_id') final  dynamic deviceId;
@override@JsonKey(name: 'access_token') final  String? accessToken;
@override@JsonKey(name: 'refresh') final  String? refresh;
@override@JsonKey(name: 'customer_type') final  dynamic customerType;
@override@JsonKey(name: 'appsflyer_id') final  dynamic appsflyerId;

/// Create a copy of OtpVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OtpVerifyResponseCopyWith<_OtpVerifyResponse> get copyWith => __$OtpVerifyResponseCopyWithImpl<_OtpVerifyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OtpVerifyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OtpVerifyResponse&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.customerId, customerId)&&const DeepCollectionEquality().equals(other.deviceId, deviceId)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refresh, refresh) || other.refresh == refresh)&&const DeepCollectionEquality().equals(other.customerType, customerType)&&const DeepCollectionEquality().equals(other.appsflyerId, appsflyerId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(customerId),const DeepCollectionEquality().hash(deviceId),accessToken,refresh,const DeepCollectionEquality().hash(customerType),const DeepCollectionEquality().hash(appsflyerId));

@override
String toString() {
  return 'OtpVerifyResponse(status: $status, customerId: $customerId, deviceId: $deviceId, accessToken: $accessToken, refresh: $refresh, customerType: $customerType, appsflyerId: $appsflyerId)';
}


}

/// @nodoc
abstract mixin class _$OtpVerifyResponseCopyWith<$Res> implements $OtpVerifyResponseCopyWith<$Res> {
  factory _$OtpVerifyResponseCopyWith(_OtpVerifyResponse value, $Res Function(_OtpVerifyResponse) _then) = __$OtpVerifyResponseCopyWithImpl;
@override @useResult
$Res call({
 int? status,@JsonKey(name: 'customer_Id') dynamic customerId,@JsonKey(name: 'device_id') dynamic deviceId,@JsonKey(name: 'access_token') String? accessToken,@JsonKey(name: 'refresh') String? refresh,@JsonKey(name: 'customer_type') dynamic customerType,@JsonKey(name: 'appsflyer_id') dynamic appsflyerId
});




}
/// @nodoc
class __$OtpVerifyResponseCopyWithImpl<$Res>
    implements _$OtpVerifyResponseCopyWith<$Res> {
  __$OtpVerifyResponseCopyWithImpl(this._self, this._then);

  final _OtpVerifyResponse _self;
  final $Res Function(_OtpVerifyResponse) _then;

/// Create a copy of OtpVerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? customerId = freezed,Object? deviceId = freezed,Object? accessToken = freezed,Object? refresh = freezed,Object? customerType = freezed,Object? appsflyerId = freezed,}) {
  return _then(_OtpVerifyResponse(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as dynamic,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as dynamic,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refresh: freezed == refresh ? _self.refresh : refresh // ignore: cast_nullable_to_non_nullable
as String?,customerType: freezed == customerType ? _self.customerType : customerType // ignore: cast_nullable_to_non_nullable
as dynamic,appsflyerId: freezed == appsflyerId ? _self.appsflyerId : appsflyerId // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
