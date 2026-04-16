import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current search query for the Transactions screen.
/// Empty string means no active search.
final transactionSearchProvider = StateProvider<String>((ref) => '');