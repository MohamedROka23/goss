import 'package:flutter_test/flutter_test.dart';
import 'package:goss/models/models.dart';
import 'package:goss/services/accounting.dart';

CustomerRequest _req({
  String id = 'r1',
  String createdAt = '2026-01-15T10:00:00.000',
  String status = RequestStatus.delivered,
  List<RequestItem>? items,
}) {
  return CustomerRequest(
    id: id,
    createdAt: createdAt,
    status: status,
    customerId: 'c1',
    company: 'Co',
    name: 'N',
    phone: '0100',
    email: 'a@b.c',
    notes: '',
    items: items ??
        [
          RequestItem(productId: 'p1', nameEn: 'Tomato', nameAr: 'طماطم', qty: 10, unit: 'kg', price: 20),
        ],
  );
}

void main() {
  group('invoiceAmount / isSaleRequest', () {
    test('invoice totals line price × qty', () {
      final r = _req(items: [
        RequestItem(productId: 'p1', nameEn: 'a', nameAr: 'أ', qty: 2, unit: 'kg', price: 5),
        RequestItem(productId: 'p2', nameEn: 'b', nameAr: 'ب', qty: 3, unit: 'kg', price: 4),
      ]);
      expect(invoiceAmount(r), 22);
    });

    test('rejected orders are not sales', () {
      expect(isSaleRequest(_req(status: RequestStatus.rejected)), isFalse);
      expect(isSaleRequest(_req(status: RequestStatus.confirmed)), isTrue);
    });
  });

  group('buildIncomeStatement', () {
    test('computes revenue, COGS and net profit in window', () {
      final st = buildIncomeStatement(
        requests: [
          _req(createdAt: '2026-01-05T10:00:00.000'), // 10 × 20 = 200 sell, cost 15
          _req(id: 'r2', createdAt: '2026-02-05T10:00:00.000'), // outside Jan
          _req(id: 'r3', createdAt: '2026-01-20T10:00:00.000', status: RequestStatus.rejected),
        ],
        expenses: [
          Expense(id: 'e1', date: '2026-01-10T00:00:00.000', category: 'Transport', description: '', amount: 30),
          Expense(id: 'e2', date: '2026-01-11T00:00:00.000', category: 'Transport', description: '', amount: 20),
          Expense(id: 'e3', date: '2026-02-11T00:00:00.000', category: 'Other', description: '', amount: 999),
        ],
        costByProduct: {'p1': 15},
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(st.revenue, 200);
      expect(st.cogs, 150);
      expect(st.grossProfit, 50);
      expect(st.totalExpenses, 50);
      expect(st.expenseBreakdown.length, 1); // Transport grouped
      expect(st.expenseBreakdown.first.amount, 50);
      expect(st.netProfit, 0);
    });

    test('unknown product cost falls back to the sell price (neutral COGS)', () {
      final st = buildIncomeStatement(
        requests: [_req()],
        expenses: const [],
        costByProduct: const {},
      );
      expect(st.revenue, 200);
      expect(st.cogs, 200);
      expect(st.grossProfit, 0);
    });

    test('no window means all time', () {
      final st = buildIncomeStatement(
        requests: [_req(createdAt: '2020-01-05T10:00:00.000'), _req(id: 'r2', createdAt: '2026-09-01T10:00:00.000')],
        expenses: const [],
        costByProduct: const {},
      );
      expect(st.revenue, 400);
    });
  });

  group('buildReceivables', () {
    test('invoice, paid and balance per order; rejected excluded', () {
      final list = buildReceivables(
        requests: [
          _req(createdAt: '2026-01-05T10:00:00.000'),
          _req(id: 'r2', createdAt: '2026-01-06T10:00:00.000', status: RequestStatus.rejected),
          _req(id: 'r3',
              createdAt: '2026-01-07T10:00:00.000',
              items: [RequestItem(productId: 'p1', nameEn: 'x', nameAr: 'س', qty: 1, unit: 'kg', price: 40)]),
        ],
        payments: [
          Payment(id: 'pay1', requestId: 'r1', customerId: 'c1', company: '', name: '', date: '', amount: 60, createdAt: ''),
        ],
      );
      expect(list.length, 2);
      expect(list.first.request.id, 'r1'); // sorted by balance desc: r1=140 > r3=40
      expect(list.first.balance, 140);
      expect(list[1].request.id, 'r3');
      expect(list[1].balance, 40);
    });
  });

  group('buildTrialBalance', () {
    JournalEntry balanced({String id = 'j1'}) => JournalEntry(
          id: id,
          date: '2026-01-01',
          memo: 'Test',
          debits: const [
            JournalLine(accountCode: '1010', accountEn: 'Cash', accountAr: 'خزينة', amount: 100),
            JournalLine(accountCode: '1020', accountEn: 'Bank', accountAr: 'بنك', amount: 50),
          ],
          credits: const [
            JournalLine(accountCode: '5000', accountEn: 'Sales', accountAr: 'مبيعات', amount: 150),
          ],
          createdAt: '',
        );

    test('unbalanced entries are ignored', () {
      final unbalanced = JournalEntry(
        id: 'bad',
        date: '2026-01-01',
        memo: 'Bad',
        debits: const [JournalLine(accountCode: '1010', accountEn: '', accountAr: '', amount: 100)],
        credits: const [JournalLine(accountCode: '5000', accountEn: '', accountAr: '', amount: 90)],
        createdAt: '',
      );
      final tb = buildTrialBalance([balanced(), unbalanced]);
      expect(tb.length, 3);
      final totalDebit = tb.fold<double>(0, (n, r) => n + r.debit);
      final totalCredit = tb.fold<double>(0, (n, r) => n + r.credit);
      expect(totalDebit, 150);
      expect(totalCredit, 150);
    });

    test('rows are sorted by account code', () {
      final tb = buildTrialBalance([balanced()]);
      expect(tb.map((r) => r.account.code).toList(), ['1010', '1020', '5000']);
    });
  });

  group('JournalEntry.isBalanced', () {
    test('true when debits equal credits and non-zero', () {
      final e = JournalEntry(
        id: 'x',
        date: '',
        memo: '',
        debits: const [JournalLine(accountCode: '1010', accountEn: '', accountAr: '', amount: 5)],
        credits: const [JournalLine(accountCode: '5000', accountEn: '', accountAr: '', amount: 5)],
        createdAt: '',
      );
      expect(e.isBalanced, isTrue);
    });

    test('false when they differ', () {
      final e = JournalEntry(
        id: 'x',
        date: '',
        memo: '',
        debits: const [JournalLine(accountCode: '1010', accountEn: '', accountAr: '', amount: 5)],
        credits: const [JournalLine(accountCode: '5000', accountEn: '', accountAr: '', amount: 4)],
        createdAt: '',
      );
      expect(e.isBalanced, isFalse);
    });
  });

  test('accountByCode resolves the default chart', () {
    expect(accountByCode('5000')?.type, AccountType.revenue);
    expect(accountByCode('1010')?.label(ar: true), 'النقدية بالخزينة');
    expect(accountByCode('nope'), isNull);
  });

  group('buildGeneralLedger', () {
    JournalEntry entry({
      required String id,
      required String date,
      required String memo,
      required List<JournalLine> debits,
      required List<JournalLine> credits,
    }) =>
        JournalEntry(id: id, date: date, memo: memo, debits: debits, credits: credits, createdAt: '');

    final dr100Cash = JournalLine(accountCode: '1010', accountEn: 'Cash', accountAr: '', amount: 100);
    final dr210Cash = JournalLine(accountCode: '1010', accountEn: 'Cash', accountAr: '', amount: 210);
    final dr40Cash = JournalLine(accountCode: '1010', accountEn: 'Cash', accountAr: '', amount: 40);
    final cr100Sales = JournalLine(accountCode: '5000', accountEn: 'Sales', accountAr: '', amount: 100);
    final cr210Sales = JournalLine(accountCode: '5000', accountEn: 'Sales', accountAr: '', amount: 210);
    final cr40Sales = JournalLine(accountCode: '5000', accountEn: 'Sales', accountAr: '', amount: 40);

    test('computes opening, movements and closing per period', () {
      final journal = [
        entry(id: 'j1', date: '2026-01-05T10:00:00.000Z', memo: 'Prior sale',
            debits: [dr100Cash], credits: [cr100Sales]),
        entry(id: 'j2', date: '2026-01-10T10:00:00.000Z', memo: 'Cash sale',
            debits: [dr210Cash], credits: [cr210Sales]),
      ];
      // Window = February: both January entries roll into the opening balance.
      final feb = buildGeneralLedger(journal, from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28));
      final cash = feb.firstWhere((a) => a.account.code == '1010');
      final sales = feb.firstWhere((a) => a.account.code == '5000');
      expect(cash.openingBalance, 310); // opening = prior debits − prior credits
      expect(cash.movements, isEmpty);
      expect(cash.displayedClosing, 310);
      // Sales is credit-normal, so a credit balance is displayed positive.
      expect(sales.openingBalance, -310); // −(100 + 210)
      expect(sales.displayedOpening, 310);
      expect(sales.displayedClosing, 310);
    });

    test('running balance accumulates in date order within the window', () {
      final journal = [
        entry(id: 'j1', date: '2026-02-02T10:00:00.000Z', memo: 'Old first',
            debits: [dr100Cash], credits: [cr100Sales]),
        entry(id: 'j2', date: '2026-02-10T10:00:00.000Z', memo: 'Second',
            debits: [dr40Cash], credits: [cr40Sales]),
      ];
      final feb = buildGeneralLedger(journal, from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28));
      final cash = feb.firstWhere((a) => a.account.code == '1010');
      expect(cash.movements.length, 2);
      expect(cash.movements.first.runningBalance, 100);
      expect(cash.movements.last.runningBalance, 140);
      expect(cash.displayedClosing, 140);
    });
  });

  group('timestamp-tolerant model parsing (Firestore serverTimestamp)', () {
    final epochSeconds = 1789049740837 ~/ 1000; // ~2026-09-10

    test('Payment.fromJson accepts a Timestamp-like createdAt', () {
      final p = Payment.fromJson({
        'id': 'p1',
        'requestId': 'r1',
        'customerId': 'c1',
        'company': 'Co',
        'name': 'N',
        'date': '2026-09-10T00:00:00.000',
        'amount': 100,
        'method': 'cash',
        'note': '',
        'createdAt': _FakeTimestamp(seconds: epochSeconds, nanoseconds: 0),
      });
      expect(p.amount, 100);
      expect(p.createdAt, startsWith('2026-'));
    });

    test('JournalEntry.fromJson accepts a Timestamp-like createdAt', () {
      final j = JournalEntry.fromJson({
        'id': 'j1',
        'date': '2026-09-10T00:00:00.000',
        'memo': 'm',
        'debits': [
          {'accountCode': '1010', 'accountEn': 'Cash', 'accountAr': '', 'amount': 100}
        ],
        'credits': [
          {'accountCode': '5000', 'accountEn': 'Sales', 'accountAr': '', 'amount': 100}
        ],
        'createdAt': _FakeTimestamp(seconds: epochSeconds, nanoseconds: 0),
      });
      expect(j.isBalanced, isTrue);
      expect(j.createdAt, startsWith('2026-'));
    });

    test('missing createdAt stays empty', () {
      final p = Payment.fromJson({
        'id': 'p2',
        'requestId': '',
        'customerId': 'c1',
        'company': 'Co',
        'name': 'N',
        'date': '2026-09-10T00:00:00.000',
        'amount': 1,
        'createdAt': null,
      });
      expect(p.createdAt, isEmpty);
    });
  });
}

/// Duck-typed stand-in for cloud_firestore's Timestamp, so models stay
/// dependency-free while still parsing Firestore serverTimestamp fields.
class _FakeTimestamp {
  final int seconds;
  final int nanoseconds;

  _FakeTimestamp({required this.seconds, required this.nanoseconds});
}