// Result class for error handling without exceptions
// Provides a functional approach to error propagation

import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

@freezed
class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(Failure failure) = Error<T>;
}

@freezed
class Failure with _$Failure {
  const factory Failure({
    required String message,
    String? code,
    Exception? exception,
    StackTrace? stackTrace,
  }) = _Failure;
} 
