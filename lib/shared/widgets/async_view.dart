import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// The rule for every screen: a loading indicator while data loads, a
/// friendly error with Retry, then [data]. Old data stays up while refreshing.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;

  const AsyncView({super.key, required this.value, required this.onRetry, required this.data});

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: ErrorMessages.from(error), onRetry: onRetry),
    );
  }
}
