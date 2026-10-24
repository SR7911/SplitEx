import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/services/bank_sms_parser.dart';
import 'package:split_ex/services/bank_sms_service.dart';

void main() {
  final parser = BankSmsParser();
  final received = DateTime(2026, 10, 20, 12, 30);
  ParsedBankSms? parse(
    String body, {
    String sender = 'VM-TESTBK',
    String id = 'test-message',
  }) => parser.parse(id: id, sender: sender, body: body, receivedAt: received);
  const debit =
      'INR 500.25 debited from A/c XX1234 to CORNER STORE on 20/10/2026. UPI Ref 629300123456. Avl Bal INR 9,999.00';

  test(
    'extracts debit amount rather than available balance and keeps only account ending',
    () {
      final sms = parse(debit)!;
      expect(sms.amountMinor, 50025);
      expect(sms.direction, BankSmsDirection.debit);
      expect(sms.accountLast4, '1234');
      expect(sms.reference, '629300123456');
      expect(sms.merchant, 'CORNER STORE');
      expect(sms.reviewReasons, isEmpty);
      expect(sms.canAutoRecord, isTrue);
      expect(sms.date, received);
    },
  );
  test('normalizes DLT sender prefixes and suffixes', () {
    expect(BankSmsParser.normalizeSender('AD-TESTBK-S'), 'TESTBK');
    expect(BankSmsParser.normalizeSender('VM-TESTBK'), 'TESTBK');
  });
  test(
    'supports Indian grouping and rupee symbol without floating-point rounding',
    () {
      final sms = parse(
        'Your A/c XX1234 is debited by ₹1,23,456.78. UTR ABC123456789.',
      )!;
      expect(sms.amountMinor, 12345678);
    },
  );
  test('full account numbers are reduced to the last four digits', () {
    expect(
      parse(
        'Rs.100 debited from account 123456781234 Ref ABC123456789.',
      )!.accountLast4,
      '1234',
    );
  });
  test('credits always require review and never automatically become income', () {
    final sms = parse(
      'INR 700 credited to A/c XX1234 from FRIEND on 20/10/2026 Ref 629300123450.',
    )!;
    expect(sms.direction, BankSmsDirection.credit);
    expect(sms.canAutoRecord, isFalse);
    expect(sms.reviewReasons, isNotEmpty);
  });
  for (final text in [
    'OTP 123456 for payment of INR 500 from your card XX1234.',
    'INR 500 debited from A/c XX1234 failed. Ref 629300123456.',
    'Payment request of INR 500 received for UPI Ref 629300123456.',
    'INR 500 will be debited from account XX1234 tomorrow.',
    'Available balance INR 500 in account XX1234.',
    'Get INR 500 cashback on bank card purchases!',
    'USD 500 debited from A/c XX1234 Ref 629300123456.',
    'INR 0 debited from A/c XX1234 Ref 629300123456.',
    'INR 500 debited and INR 500 credited between bank accounts.',
  ]) {
    test(
      'ignores non-final or unsupported message: $text',
      () => expect(parse(text), isNull),
    );
  }
  test('personal numeric senders cannot be treated as bank senders', () {
    expect(parse(debit, sender: '+919999999999'), isNull);
  });
  test('missing reference or account ending requires review', () {
    expect(parse('INR 500 debited from bank account.')!.canAutoRecord, isFalse);
  });
  test(
    'EMI and self-transfer alerts require review even with a trusted sender',
    () {
      for (final suffix in [
        'EMI payment.',
        'Transfer to own account.',
        'Autopay mandate.',
      ]) {
        final sms = parse('$debit $suffix')!;
        expect(sms.canAutoRecord, isFalse);
      }
    },
  );
  test('multiple transaction amounts require review', () {
    expect(parse('$debit Fee Rs.2.00.')!.canAutoRecord, isFalse);
  });
  test(
    'SMS retries with the same reference produce the same durable receipt ID',
    () {
      final first = parse(debit, id: 'first')!;
      final repeat = parse(debit, sender: 'AD-TESTBK-S', id: 'repeat')!;
      expect(first.transactionId, repeat.transactionId);
      expect(first.transactionId, startsWith('sms_'));
    },
  );
  test('opposite directions do not share an import ID', () {
    final first = parse(debit)!;
    final credit = parse(
      'INR 500.25 credited to A/c XX1234 UPI Ref 629300123456.',
    )!;
    expect(first.transactionId, isNot(credit.transactionId));
  });
  test(
    'only trusted clear debits with no possible existing match auto-record',
    () {
      final sms = parse(debit)!;
      expect(
        BankSmsService.shouldAutoRecord(
          sms,
          automatic: true,
          trusted: {'TESTBK'},
          hasPossibleMatch: false,
        ),
        isTrue,
      );
      expect(
        BankSmsService.shouldAutoRecord(
          sms,
          automatic: true,
          trusted: {},
          hasPossibleMatch: false,
        ),
        isFalse,
      );
      expect(
        BankSmsService.shouldAutoRecord(
          sms,
          automatic: false,
          trusted: {'TESTBK'},
          hasPossibleMatch: false,
        ),
        isFalse,
      );
      expect(
        BankSmsService.shouldAutoRecord(
          sms,
          automatic: true,
          trusted: {'TESTBK'},
          hasPossibleMatch: true,
        ),
        isFalse,
      );
    },
  );
  test(
    'review candidates survive local serialization without precision changes',
    () {
      final original = parse(debit)!;
      final restored = ParsedBankSms.fromMap(original.toMap());
      expect(restored.amountMinor, original.amountMinor);
      expect(restored.transactionId, original.transactionId);
      expect(restored.date, original.date);
    },
  );
  test(
    'invalid dates require review instead of rolling into another month',
    () {
      final sms = parse(debit.replaceAll('20/10/2026', '31/02/2026'))!;
      expect(sms.canAutoRecord, isFalse);
      expect(sms.date, received);
    },
  );
  test(
    'sent-payment alerts use the payee rather than the sending bank as merchant',
    () {
      final sms = parse(
        'Sent Rs.500.00 from TEST Bank A/c XX1234 to CORNER STORE on 20/10/2026. UPI 629300123456.',
      )!;
      expect(sms.direction, BankSmsDirection.debit);
      expect(sms.amountMinor, 50000);
      expect(sms.merchant, 'CORNER STORE');
      expect(sms.canAutoRecord, isTrue);
    },
  );
  test('cash withdrawals and bank transfers require review', () {
    for (final body in [
      'INR 500 withdrawn from A/c XX1234 at ATM Ref ABC123456789.',
      'INR 500 debited from A/c XX1234 to FRIEND via NEFT Ref ABC123456789.',
    ]) {
      expect(parse(body)!.canAutoRecord, isFalse);
    }
  });
}
