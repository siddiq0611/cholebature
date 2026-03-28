// This file provides a semantic layer on top of the core Transaction model
// for borrow/lend specific logic. No separate DB table is needed — all
// borrow/lend entries are stored as regular transactions with type
// TransactionType.borrowed or TransactionType.lend.

import 'transaction_model.dart';

/// Settlement status — stored as a note prefix so we don't need a new column.
/// Format in note field: "[SETTLED]original note" or "[PARTIAL:5000]original note"
enum SettlementStatus { open, partial, settled }

/// A rich wrapper around a Transaction that adds borrow/lend semantics.
class BorrowLendEntry {
  final Transaction transaction;

  const BorrowLendEntry(this.transaction);

  // ── Core accessors ──────────────────────────────────────────────────────────

  bool get isBorrowed => transaction.type == TransactionType.borrowed;
  bool get isLent => transaction.type == TransactionType.lend;

  String get personName => transaction.title;
  double get amount => transaction.amount;
  DateTime get date => transaction.date;
  String get id => transaction.id;

  // ── Settlement parsing from note field ──────────────────────────────────────

  SettlementStatus get settlementStatus {
    final note = transaction.note ?? '';
    if (note.startsWith('[SETTLED]')) return SettlementStatus.settled;
    if (note.startsWith('[PARTIAL:')) return SettlementStatus.partial;
    return SettlementStatus.open;
  }

  /// Amount already settled (0 if open/settled fully).
  double get settledAmount {
    final note = transaction.note ?? '';
    if (note.startsWith('[PARTIAL:')) {
      // e.g. "[PARTIAL:3000]some note"
      final end = note.indexOf(']');
      if (end > 9) {
        return double.tryParse(note.substring(9, end)) ?? 0;
      }
    }
    if (settlementStatus == SettlementStatus.settled) return amount;
    return 0;
  }

  double get outstandingAmount => amount - settledAmount;

  /// The user-visible note without settlement prefix.
  String get cleanNote {
    final note = transaction.note ?? '';
    if (note.startsWith('[SETTLED]')) return note.substring(9);
    if (note.startsWith('[PARTIAL:')) {
      final end = note.indexOf(']');
      if (end >= 0 && end < note.length - 1) return note.substring(end + 1);
      return '';
    }
    return note;
  }

  // ── Note builders for persistence ───────────────────────────────────────────

  /// Returns the note string to store when marking fully settled.
  static String settledNote(String existingCleanNote) =>
      '[SETTLED]$existingCleanNote';

  /// Returns the note string to store when partially settled.
  static String partialNote(double settledAmount, String existingCleanNote) =>
      '[PARTIAL:${settledAmount.toStringAsFixed(0)}]$existingCleanNote';

  /// Returns the note string to reopen (remove settlement prefix).
  static String openNote(String existingCleanNote) => existingCleanNote;

  // ── Display helpers ─────────────────────────────────────────────────────────

  String get statusLabel {
    switch (settlementStatus) {
      case SettlementStatus.open:
        return 'Open';
      case SettlementStatus.partial:
        return 'Partial';
      case SettlementStatus.settled:
        return 'Settled';
    }
  }

  String get directionLabel =>
      isBorrowed ? 'I owe them' : 'They owe me';
}

/// Aggregate stats for a borrow/lend list.
class BorrowLendSummary {
  final double totalBorrowed;
  final double totalLent;
  final double settledBorrowed;
  final double settledLent;

  const BorrowLendSummary({
    required this.totalBorrowed,
    required this.totalLent,
    required this.settledBorrowed,
    required this.settledLent,
  });

  double get outstandingBorrowed => totalBorrowed - settledBorrowed;
  double get outstandingLent => totalLent - settledLent;

  /// Positive = net owed TO me. Negative = I owe others.
  double get netPosition => outstandingLent - outstandingBorrowed;
  bool get netPositive => netPosition >= 0;

  factory BorrowLendSummary.from(List<BorrowLendEntry> entries) {
    double totalBorrowed = 0;
    double totalLent = 0;
    double settledBorrowed = 0;
    double settledLent = 0;

    for (final e in entries) {
      if (e.isBorrowed) {
        totalBorrowed += e.amount;
        settledBorrowed += e.settledAmount;
      } else {
        totalLent += e.amount;
        settledLent += e.settledAmount;
      }
    }

    return BorrowLendSummary(
      totalBorrowed: totalBorrowed,
      totalLent: totalLent,
      settledBorrowed: settledBorrowed,
      settledLent: settledLent,
    );
  }
}