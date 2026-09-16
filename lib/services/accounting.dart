import '../models/models.dart';

/// Pure accounting engine. Every statement is computed from the operational
/// data (requests, purchases, expenses, payments and journal postings) with
/// no side effects, so it is fully testable in isolation.

enum AccountType { asset, liability, equity, revenue, expense }

class JournalAccount {
  final String code;
  final String en;
  final String ar;
  final AccountType type;

  const JournalAccount({
    required this.code,
    required this.en,
    required this.ar,
    required this.type,
  });

  String label({required bool ar}) => ar ? this.ar : en;
}

/// Default chart of accounts used by the journal editor and trial balance.
const List<JournalAccount> defaultChartOfAccounts = [
  JournalAccount(code: '1010', en: 'Cash on hand', ar: 'النقدية بالخزينة', type: AccountType.asset),
  JournalAccount(code: '1020', en: 'Bank account', ar: 'الحساب البنكي', type: AccountType.asset),
  JournalAccount(code: '1100', en: 'Accounts receivable', ar: 'ذمم عملاء', type: AccountType.asset),
  JournalAccount(code: '1200', en: 'Inventory', ar: 'المخزون (بضاعة بالمخزن)', type: AccountType.asset),
  JournalAccount(code: '1500', en: 'Fixed assets', ar: 'أصول ثابتة', type: AccountType.asset),
  JournalAccount(code: '2010', en: 'Accounts payable', ar: 'ذمم موردين', type: AccountType.liability),
  JournalAccount(code: '3010', en: 'Owner capital', ar: 'رأس المال', type: AccountType.equity),
  JournalAccount(code: '3020', en: 'Retained earnings', ar: 'الأرباح المبقاة', type: AccountType.equity),
  JournalAccount(code: '5000', en: 'Sales revenue', ar: 'إيرادات المبيعات', type: AccountType.revenue),
  JournalAccount(code: '5100', en: 'Other income', ar: 'إيرادات أخرى', type: AccountType.revenue),
  JournalAccount(code: '6010', en: 'Cost of goods sold', ar: 'تكلفة المبيعات', type: AccountType.expense),
  JournalAccount(code: '7010', en: 'Operating expenses', ar: 'مصاريف التشغيل', type: AccountType.expense),
  JournalAccount(code: '7020', en: 'Transport & logistics', ar: 'مصاريف النقل واللوجستيات', type: AccountType.expense),
  JournalAccount(code: '7030', en: 'Salaries', ar: 'الرواتب', type: AccountType.expense),
  JournalAccount(code: '7040', en: 'General & administrative', ar: 'مصاريف إدارية وعمومية', type: AccountType.expense),
  JournalAccount(code: '7050', en: 'Other expenses', ar: 'مصاريف أخرى', type: AccountType.expense),
];

JournalAccount? accountByCode(String code) {
  for (final a in defaultChartOfAccounts) {
    if (a.code == code) return a;
  }
  return null;
}

/// A request only counts as a sale once it is not rejected/cancelled.
bool isSaleRequest(CustomerRequest r) => r.type == 'supply' && r.status != RequestStatus.rejected;

/// Invoice value of an order = sum of its line totals.
double invoiceAmount(CustomerRequest r) {
  var total = 0.0;
  for (final i in r.items) {
    total += i.price * i.qty;
  }
  return total;
}

/// Cost of the goods sold on an order based on the recorded buy-in price of
/// each product ([costByProduct]); unknown products fall back to the sell
/// price so the statement stays balanced and never shows negative COGS.
double cogsOfRequest(CustomerRequest r, Map<String, double> costByProduct) {
  var total = 0.0;
  for (final i in r.items) {
    final cost = costByProduct[i.productId] ?? i.price;
    total += cost * i.qty;
  }
  return total;
}

// ---------------------------------------------------------------------------
//  Income statement
// ---------------------------------------------------------------------------

class IncomeLine {
  final String labelEn;
  final String labelAr;
  final double amount;
  final bool isHeader;

  const IncomeLine({
    required this.labelEn,
    required this.labelAr,
    required this.amount,
    this.isHeader = false,
  });
}

class IncomeStatement {
  final DateTime? from;
  final DateTime? to;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final List<IncomeLine> expenseBreakdown;

  const IncomeStatement({
    this.from,
    this.to,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    this.expenseBreakdown = const [],
  });
}

/// Builds the income statement for an optional window (inclusive, by date).
/// [costByProduct] maps productId -> cost price so sold goods are valued at
/// purchase cost; missing products use their sell price as the fallback.
IncomeStatement buildIncomeStatement({
  required List<CustomerRequest> requests,
  required List<Expense> expenses,
  required Map<String, double> costByProduct,
  DateTime? from,
  DateTime? to,
}) {
  var revenue = 0.0;
  var cogs = 0.0;
  for (final r in requests) {
    if (!isSaleRequest(r)) continue;
    if (!_inWindow(r.createdAt, from, to)) continue;
    revenue += invoiceAmount(r);
    cogs += cogsOfRequest(r, costByProduct);
  }
  final gross = revenue - cogs;

  final byCategory = <String, double>{};
  for (final e in expenses) {
    if (!_inWindow(e.date, from, to)) continue;
    final key = e.category.isEmpty ? 'General' : e.category;
    byCategory[key] = (byCategory[key] ?? 0) + e.amount;
  }
  final breakdown = byCategory.entries.map((e) => IncomeLine(
        labelEn: e.key,
        labelAr: e.key,
        amount: e.value,
      )).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final totalExpenses = breakdown.fold(0.0, (n, l) => n + l.amount);

  return IncomeStatement(
    from: from,
    to: to,
    revenue: revenue,
    cogs: cogs,
    grossProfit: gross,
    totalExpenses: totalExpenses,
    netProfit: gross - totalExpenses,
    expenseBreakdown: breakdown,
  );
}

// ---------------------------------------------------------------------------
//  Receivables (customer balances)
// ---------------------------------------------------------------------------

class Receivable {
  final CustomerRequest request;
  final double invoice;
  final double paid;

  const Receivable({
    required this.request,
    required this.invoice,
    required this.paid,
  });

  double get balance => invoice - paid;
}

/// Outstanding invoices per order (rejected orders are excluded). Includes
/// fully paid invoices so the admin can audit the payment trail.
List<Receivable> buildReceivables({
  required List<CustomerRequest> requests,
  required List<Payment> payments,
}) {
  final paidByRequest = <String, double>{};
  for (final p in payments) {
    paidByRequest[p.requestId] = (paidByRequest[p.requestId] ?? 0) + p.amount;
  }
  final out = <Receivable>[];
  for (final r in requests) {
    if (!isSaleRequest(r)) continue;
    out.add(Receivable(
      request: r,
      invoice: invoiceAmount(r),
      paid: paidByRequest[r.id] ?? 0,
    ));
  }
  out.sort((a, b) => b.balance.compareTo(a.balance));
  return out;
}

// ---------------------------------------------------------------------------
//  Trial balance & journal
// ---------------------------------------------------------------------------

class TrialBalanceRow {
  final JournalAccount account;
  final double debit;
  final double credit;

  const TrialBalanceRow({
    required this.account,
    required this.debit,
    required this.credit,
  });

  double get balance => debit - credit;
}

/// Sums every posted journal entry per account. Only balanced entries count.
List<TrialBalanceRow> buildTrialBalance(List<JournalEntry> entries) {
  final byCode = <String, (double, double, JournalAccount)>{};
  for (final e in entries) {
    if (!e.isBalanced) continue;
    for (final l in e.debits) {
      final account = accountByCode(l.accountCode) ??
          JournalAccount(code: l.accountCode, en: l.accountEn, ar: l.accountAr, type: AccountType.asset);
      final cur = byCode[l.accountCode] ?? (0, 0, account);
      byCode[l.accountCode] = (cur.$1 + l.amount, cur.$2, account);
    }
    for (final l in e.credits) {
      final account = accountByCode(l.accountCode) ??
          JournalAccount(code: l.accountCode, en: l.accountEn, ar: l.accountAr, type: AccountType.asset);
      final cur = byCode[l.accountCode] ?? (0, 0, account);
      byCode[l.accountCode] = (cur.$1, cur.$2 + l.amount, account);
    }
  }
  final rows = byCode.values
      .map((v) => TrialBalanceRow(account: v.$3, debit: v.$1, credit: v.$2))
      .toList();
  rows.sort((a, b) => a.account.code.compareTo(b.account.code));
  return rows;
}

// ---------------------------------------------------------------------------
//  General ledger (per-account book)
// ---------------------------------------------------------------------------

/// Asset and expense accounts normally hold a debit balance; liability,
/// equity and revenue accounts a credit balance.
bool isDebitNormal(AccountType t) => t == AccountType.asset || t == AccountType.expense;

double _displayBalance(AccountType t, double debitPositive) =>
    isDebitNormal(t) ? debitPositive : -debitPositive;

class LedgerMovement {
  final DateTime date;
  final String memo;
  final double debit;
  final double credit;
  final double runningBalance; // debit-positive after this movement

  const LedgerMovement({
    required this.date,
    required this.memo,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
}

class AccountLedger {
  final JournalAccount account;
  final double openingBalance; // debit-positive (assets/expenses +, others −)
  final List<LedgerMovement> movements;

  const AccountLedger({
    required this.account,
    required this.openingBalance,
    required this.movements,
  });

  double get totalDebit => movements.fold(0.0, (n, m) => n + m.debit);
  double get totalCredit => movements.fold(0.0, (n, m) => n + m.credit);
  double get closingBalance => openingBalance + totalDebit - totalCredit;

  double get displayedOpening => _displayBalance(account.type, openingBalance);
  double get displayedClosing => _displayBalance(account.type, closingBalance);

  double display(double debitPositive) => _displayBalance(account.type, debitPositive);
}

/// Builds the general ledger from posted journal entries: for every account it
/// computes the opening balance (entries before [from]), the movements within
/// the window and the closing balance. Only balanced entries count.
List<AccountLedger> buildGeneralLedger(
  List<JournalEntry> journal, {
  DateTime? from,
  DateTime? to,
}) {
  final opening = <String, double>{};
  final raw = <String, List<({DateTime date, String memo, String createdAt, double debit, double credit})>>{};
  final metas = <String, JournalAccount>{};

  void metaFor(String code) {
    metas.putIfAbsent(code, () => accountByCode(code) ??
        JournalAccount(code: code, en: code, ar: code, type: AccountType.asset));
  }

  final monthStart = from != null ? DateTime(from.year, from.month, from.day) : null;

  for (final e in journal) {
    if (!e.isBalanced) continue;
    final dt = DateTime.tryParse(e.date);
    if (dt == null) continue;
    final local = dt.toLocal();

    final isOpening = monthStart != null && local.isBefore(monthStart);
    if (isOpening) {
      for (final l in e.debits) {
        metaFor(l.accountCode);
        opening[l.accountCode] = (opening[l.accountCode] ?? 0) + l.amount;
      }
      for (final l in e.credits) {
        metaFor(l.accountCode);
        opening[l.accountCode] = (opening[l.accountCode] ?? 0) - l.amount;
      }
      continue;
    }

    if (!_inWindow(e.date, from, to)) continue;
    for (final l in e.debits) {
      metaFor(l.accountCode);
      raw[l.accountCode] = [
        ...?raw[l.accountCode],
        (date: local, memo: e.memo, createdAt: e.createdAt, debit: l.amount, credit: 0),
      ];
    }
    for (final l in e.credits) {
      metaFor(l.accountCode);
      raw[l.accountCode] = [
        ...?raw[l.accountCode],
        (date: local, memo: e.memo, createdAt: e.createdAt, debit: 0, credit: l.amount),
      ];
    }
  }

  final out = <AccountLedger>[];
  for (final m in metas.entries) {
    final lines = (raw[m.key] ?? [])..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
      });
    var running = opening[m.key] ?? 0;
    final movements = <LedgerMovement>[];
    for (final ln in lines) {
      running += ln.debit - ln.credit;
      movements.add(LedgerMovement(
        date: ln.date,
        memo: ln.memo,
        debit: ln.debit,
        credit: ln.credit,
        runningBalance: running,
      ));
    }
    out.add(AccountLedger(account: m.value, openingBalance: opening[m.key] ?? 0, movements: movements));
  }
  out.sort((a, b) => a.account.code.compareTo(b.account.code));
  return out;
}

// ---------------------------------------------------------------------------
//  helpers
// ---------------------------------------------------------------------------

bool _inWindow(String iso, DateTime? from, DateTime? to) {
  final d = DateTime.tryParse(iso);
  if (d == null) return from == null && to == null;
  final local = d.toLocal();
  if (from != null && local.isBefore(DateTime(from.year, from.month, from.day))) {
    return false;
  }
  if (to != null &&
      local.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59, 999))) {
    return false;
  }
  return true;
}