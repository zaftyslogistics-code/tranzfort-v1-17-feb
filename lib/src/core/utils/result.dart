enum AppError {
  network,
  auth,
  notFound,
  businessRule,
  server,
  unknown,
}

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(String message, AppError error) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => onSuccess(d),
      Failure<T>(message: final m, error: final e) => onFailure(m, e),
    };
  }

  T? get dataOrNull => switch (this) {
        Success<T>(data: final d) => d,
        Failure<T>() => null,
      };

  String? get errorMessage => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final m) => m,
      };
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

class Failure<T> extends Result<T> {
  final String message;
  final AppError error;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.error = AppError.unknown, this.stackTrace});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && message == other.message && error == other.error;

  @override
  int get hashCode => Object.hash(message, error);

  @override
  String toString() => 'Failure($error: $message)';
}
