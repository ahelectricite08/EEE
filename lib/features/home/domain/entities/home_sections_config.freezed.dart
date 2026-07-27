// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_sections_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HomeSectionsConfig {
  DateTime? get podcastNextEventAt => throw _privateConstructorUsedError;
  HomeLayoutHints get layoutHints => throw _privateConstructorUsedError;

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeSectionsConfigCopyWith<HomeSectionsConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeSectionsConfigCopyWith<$Res> {
  factory $HomeSectionsConfigCopyWith(
          HomeSectionsConfig value, $Res Function(HomeSectionsConfig) then) =
      _$HomeSectionsConfigCopyWithImpl<$Res, HomeSectionsConfig>;
  @useResult
  $Res call({DateTime? podcastNextEventAt, HomeLayoutHints layoutHints});

  $HomeLayoutHintsCopyWith<$Res> get layoutHints;
}

/// @nodoc
class _$HomeSectionsConfigCopyWithImpl<$Res, $Val extends HomeSectionsConfig>
    implements $HomeSectionsConfigCopyWith<$Res> {
  _$HomeSectionsConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? podcastNextEventAt = freezed,
    Object? layoutHints = null,
  }) {
    return _then(_value.copyWith(
      podcastNextEventAt: freezed == podcastNextEventAt
          ? _value.podcastNextEventAt
          : podcastNextEventAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      layoutHints: null == layoutHints
          ? _value.layoutHints
          : layoutHints // ignore: cast_nullable_to_non_nullable
              as HomeLayoutHints,
    ) as $Val);
  }

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HomeLayoutHintsCopyWith<$Res> get layoutHints {
    return $HomeLayoutHintsCopyWith<$Res>(_value.layoutHints, (value) {
      return _then(_value.copyWith(layoutHints: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HomeSectionsConfigImplCopyWith<$Res>
    implements $HomeSectionsConfigCopyWith<$Res> {
  factory _$$HomeSectionsConfigImplCopyWith(_$HomeSectionsConfigImpl value,
          $Res Function(_$HomeSectionsConfigImpl) then) =
      __$$HomeSectionsConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime? podcastNextEventAt, HomeLayoutHints layoutHints});

  @override
  $HomeLayoutHintsCopyWith<$Res> get layoutHints;
}

/// @nodoc
class __$$HomeSectionsConfigImplCopyWithImpl<$Res>
    extends _$HomeSectionsConfigCopyWithImpl<$Res, _$HomeSectionsConfigImpl>
    implements _$$HomeSectionsConfigImplCopyWith<$Res> {
  __$$HomeSectionsConfigImplCopyWithImpl(_$HomeSectionsConfigImpl _value,
      $Res Function(_$HomeSectionsConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? podcastNextEventAt = freezed,
    Object? layoutHints = null,
  }) {
    return _then(_$HomeSectionsConfigImpl(
      podcastNextEventAt: freezed == podcastNextEventAt
          ? _value.podcastNextEventAt
          : podcastNextEventAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      layoutHints: null == layoutHints
          ? _value.layoutHints
          : layoutHints // ignore: cast_nullable_to_non_nullable
              as HomeLayoutHints,
    ));
  }
}

/// @nodoc

class _$HomeSectionsConfigImpl implements _HomeSectionsConfig {
  const _$HomeSectionsConfigImpl(
      {this.podcastNextEventAt, this.layoutHints = const HomeLayoutHints()});

  @override
  final DateTime? podcastNextEventAt;
  @override
  @JsonKey()
  final HomeLayoutHints layoutHints;

  @override
  String toString() {
    return 'HomeSectionsConfig(podcastNextEventAt: $podcastNextEventAt, layoutHints: $layoutHints)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeSectionsConfigImpl &&
            (identical(other.podcastNextEventAt, podcastNextEventAt) ||
                other.podcastNextEventAt == podcastNextEventAt) &&
            (identical(other.layoutHints, layoutHints) ||
                other.layoutHints == layoutHints));
  }

  @override
  int get hashCode => Object.hash(runtimeType, podcastNextEventAt, layoutHints);

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeSectionsConfigImplCopyWith<_$HomeSectionsConfigImpl> get copyWith =>
      __$$HomeSectionsConfigImplCopyWithImpl<_$HomeSectionsConfigImpl>(
          this, _$identity);
}

abstract class _HomeSectionsConfig implements HomeSectionsConfig {
  const factory _HomeSectionsConfig(
      {final DateTime? podcastNextEventAt,
      final HomeLayoutHints layoutHints}) = _$HomeSectionsConfigImpl;

  @override
  DateTime? get podcastNextEventAt;
  @override
  HomeLayoutHints get layoutHints;

  /// Create a copy of HomeSectionsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeSectionsConfigImplCopyWith<_$HomeSectionsConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
