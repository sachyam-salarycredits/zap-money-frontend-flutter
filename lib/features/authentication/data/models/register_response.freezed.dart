// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'register_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterResponse {

 int? get status; String? get message;
/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterResponseCopyWith<RegisterResponse> get copyWith => _$RegisterResponseCopyWithImpl<RegisterResponse>(this as RegisterResponse, _$identity);

  /// Serializes this RegisterResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterResponse&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,message);

@override
String toString() {
  return 'RegisterResponse(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class $RegisterResponseCopyWith<$Res>  {
  factory $RegisterResponseCopyWith(RegisterResponse value, $Res Function(RegisterResponse) _then) = _$RegisterResponseCopyWithImpl;
@useResult
$Res call({
 int? status, String? message
});




}
/// @nodoc
class _$RegisterResponseCopyWithImpl<$Res>
    implements $RegisterResponseCopyWith<$Res> {
  _$RegisterResponseCopyWithImpl(this._self, this._then);

  final RegisterResponse _self;
  final $Res Function(RegisterResponse) _then;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? message = freezed,}) {
  return _then(_self.copyWith(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RegisterResponse].
extension RegisterResponsePatterns on RegisterResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegisterResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegisterResponse value)  $default,){
final _that = this;
switch (_that) {
case _RegisterResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegisterResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? status,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
return $default(_that.status,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? status,  String? message)  $default,) {final _that = this;
switch (_that) {
case _RegisterResponse():
return $default(_that.status,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? status,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _RegisterResponse() when $default != null:
return $default(_that.status,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RegisterResponse implements RegisterResponse {
  const _RegisterResponse({this.status, this.message});
  factory _RegisterResponse.fromJson(Map<String, dynamic> json) => _$RegisterResponseFromJson(json);

@override final  int? status;
@override final  String? message;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterResponseCopyWith<_RegisterResponse> get copyWith => __$RegisterResponseCopyWithImpl<_RegisterResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterResponse&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,message);

@override
String toString() {
  return 'RegisterResponse(status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class _$RegisterResponseCopyWith<$Res> implements $RegisterResponseCopyWith<$Res> {
  factory _$RegisterResponseCopyWith(_RegisterResponse value, $Res Function(_RegisterResponse) _then) = __$RegisterResponseCopyWithImpl;
@override @useResult
$Res call({
 int? status, String? message
});




}
/// @nodoc
class __$RegisterResponseCopyWithImpl<$Res>
    implements _$RegisterResponseCopyWith<$Res> {
  __$RegisterResponseCopyWithImpl(this._self, this._then);

  final _RegisterResponse _self;
  final $Res Function(_RegisterResponse) _then;

/// Create a copy of RegisterResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? message = freezed,}) {
  return _then(_RegisterResponse(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
