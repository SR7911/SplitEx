import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:split_ex/services/usage_tracker.dart';

class MonthData {
  final int expenses;
  final int bills;
  final int activities;
  final int settlements;
  final int notifications;
  final int personalTransactions;
  final int personalBudgets;
  final int personalRecurring;

  const MonthData({
    this.expenses = 0,
    this.bills = 0,
    this.activities = 0,
    this.settlements = 0,
    this.notifications = 0,
    this.personalTransactions = 0,
    this.personalBudgets = 0,
    this.personalRecurring = 0,
  });

  int get total => expenses + bills + activities + settlements + notifications + personalTransactions + personalBudgets + personalRecurring;
}

class StorageStats {
  final int totalExpenses;
  final int totalBills;
  final int totalActivities;
  final int totalSettlements;
  final int totalNotifications;
  final int totalPersonalTransactions;
  final int totalPersonalBudgets;
  final int totalPersonalRecurring;
  final int totalImages;
  final int totalUsers;
  final Map<String, MonthData> dataByMonth;
  final int estimatedImageSizeBytes;
  final int estimatedDocSizeBytes;
  final int dailyReads;
  final int dailyWrites;

  const StorageStats({
    required this.totalExpenses,
    required this.totalBills,
    required this.totalActivities,
    required this.totalSettlements,
    required this.totalNotifications,
    required this.totalPersonalTransactions,
    required this.totalPersonalBudgets,
    required this.totalPersonalRecurring,
    required this.totalImages,
    required this.totalUsers,
    required this.dataByMonth,
    required this.estimatedImageSizeBytes,
    required this.estimatedDocSizeBytes,
    required this.dailyReads,
    required this.dailyWrites,
  });

  static const int maxDailyReads = 50000;
  static const int maxDailyWrites = 20000;
  static const int maxFirestoreBytes = 1073741824;
  static const int maxStorageBytes = 5368709120;

  int get totalDocs =>
      totalExpenses +
      totalBills +
      totalActivities +
      totalSettlements +
      totalNotifications +
      totalPersonalTransactions +
      totalPersonalBudgets +
      totalPersonalRecurring;
}

class StorageManagementService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _tracker = UsageTracker.instance;

  String _monthFromTimestamp(Timestamp? ts) {
    if (ts == null) return 'unknown';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<StorageStats> getStats(String roomId, String userId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    // Room collections
    final expensesSnap = await roomRef.collection('expenses').get();
    final billsSnap = await roomRef.collection('bills').get();
    final activitiesSnap = await roomRef.collection('activities').get();
    final settlementsSnap = await roomRef.collection('settlements').get();

    // ALL notifications (admin has full access)
    final notificationsSnap = await _firestore.collection('notifications').get();

    // ALL users
    final usersSnap = await _firestore.collection('users').get();
    final totalUsers = usersSnap.docs.length;

    // Personal expense data for ALL users
    int totalPersonalTxns = 0;
    int totalPersonalBudgets = 0;
    int totalPersonalRecurring = 0;
    final personalMonthData = <String, Map<String, int>>{};

    for (final userDoc in usersSnap.docs) {
      final uid = userDoc.id;
      final txnSnap = await _firestore.collection('users').doc(uid).collection('personal_transactions').get();
      final budgetSnap = await _firestore.collection('users').doc(uid).collection('personal_budgets').get();
      final recurSnap = await _firestore.collection('users').doc(uid).collection('personal_recurring').get();

      totalPersonalTxns += txnSnap.docs.length;
      totalPersonalBudgets += budgetSnap.docs.length;
      totalPersonalRecurring += recurSnap.docs.length;

      for (final doc in txnSnap.docs) {
        final month = doc.data()['month'] as String? ?? 'unknown';
        personalMonthData.putIfAbsent(month, () => {});
        personalMonthData[month]!['personalTransactions'] = (personalMonthData[month]!['personalTransactions'] ?? 0) + 1;
      }
      for (final doc in budgetSnap.docs) {
        final month = doc.data()['month'] as String? ?? 'unknown';
        personalMonthData.putIfAbsent(month, () => {});
        personalMonthData[month]!['personalBudgets'] = (personalMonthData[month]!['personalBudgets'] ?? 0) + 1;
      }
    }

    // Build month data
    final monthMap = <String, Map<String, int>>{};

    void addToMonth(String month, String type) {
      monthMap.putIfAbsent(month, () => {});
      monthMap[month]![type] = (monthMap[month]![type] ?? 0) + 1;
    }

    for (final doc in expensesSnap.docs) {
      final month = doc.data()['month'] as String? ?? 'unknown';
      addToMonth(month, 'expenses');
    }
    for (final doc in billsSnap.docs) {
      final month = doc.data()['month'] as String? ?? 'unknown';
      addToMonth(month, 'bills');
    }
    for (final doc in activitiesSnap.docs) {
      final month = _monthFromTimestamp(doc.data()['createdAt'] as Timestamp?);
      addToMonth(month, 'activities');
    }
    for (final doc in settlementsSnap.docs) {
      final month = _monthFromTimestamp(doc.data()['createdAt'] as Timestamp?);
      addToMonth(month, 'settlements');
    }
    for (final doc in notificationsSnap.docs) {
      final month = _monthFromTimestamp(doc.data()['createdAt'] as Timestamp?);
      addToMonth(month, 'notifications');
    }

    // Merge personal month data
    for (final entry in personalMonthData.entries) {
      monthMap.putIfAbsent(entry.key, () => {});
      monthMap[entry.key]!.addAll(entry.value);
    }

    final dataByMonth = monthMap.map(
      (month, counts) => MapEntry(
        month,
        MonthData(
          expenses: counts['expenses'] ?? 0,
          bills: counts['bills'] ?? 0,
          activities: counts['activities'] ?? 0,
          settlements: counts['settlements'] ?? 0,
          notifications: counts['notifications'] ?? 0,
          personalTransactions: counts['personalTransactions'] ?? 0,
          personalBudgets: counts['personalBudgets'] ?? 0,
          personalRecurring: counts['personalRecurring'] ?? 0,
        ),
      ),
    );

    // Images
    int totalImages = 0;
    int estimatedImageSize = 0;
    try {
      final listResult = await _storage.ref('receipts/$roomId').listAll();
      for (final folder in listResult.prefixes) {
        final items = await folder.listAll();
        totalImages += items.items.length;
        estimatedImageSize += items.items.length * 512000;
      }
    } catch (_) {}

    final totalDocs =
        expensesSnap.docs.length +
        billsSnap.docs.length +
        activitiesSnap.docs.length +
        settlementsSnap.docs.length +
        notificationsSnap.docs.length +
        totalPersonalTxns +
        totalPersonalBudgets +
        totalPersonalRecurring;

    final dailyUsage = await _tracker.getDailyUsage();
    final readsUsed = totalDocs + 5;
    await _tracker.trackReads(readsUsed);

    return StorageStats(
      totalExpenses: expensesSnap.docs.length,
      totalBills: billsSnap.docs.length,
      totalActivities: activitiesSnap.docs.length,
      totalSettlements: settlementsSnap.docs.length,
      totalNotifications: notificationsSnap.docs.length,
      totalPersonalTransactions: totalPersonalTxns,
      totalPersonalBudgets: totalPersonalBudgets,
      totalPersonalRecurring: totalPersonalRecurring,
      totalImages: totalImages,
      totalUsers: totalUsers,
      dataByMonth: dataByMonth,
      estimatedImageSizeBytes: estimatedImageSize,
      estimatedDocSizeBytes: totalDocs * 1024,
      dailyReads: dailyUsage['reads']! + readsUsed,
      dailyWrites: dailyUsage['writes']!,
    );
  }

  // ─── Clear operations ───

  Future<int> clearExpensesByMonth(String roomId, String month) async {
    final snap = await _firestore.collection('rooms').doc(roomId).collection('expenses').where('month', isEqualTo: month).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await _tracker.trackWrites(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearBillsByMonth(String roomId, String month) async {
    final snap = await _firestore.collection('rooms').doc(roomId).collection('bills').where('month', isEqualTo: month).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await _tracker.trackWrites(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearActivitiesByMonth(String roomId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore.collection('rooms').doc(roomId).collection('activities')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end)).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await _tracker.trackWrites(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearSettlementsByMonth(String roomId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore.collection('rooms').doc(roomId).collection('settlements')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end)).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await _tracker.trackWrites(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearNotificationsByMonth(String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore.collection('notifications')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end)).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await _tracker.trackWrites(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearPersonalTransactionsByMonth(String month) async {
    int count = 0;
    final usersSnap = await _firestore.collection('users').get();
    for (final userDoc in usersSnap.docs) {
      final snap = await _firestore.collection('users').doc(userDoc.id).collection('personal_transactions')
          .where('month', isEqualTo: month).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
      count += snap.docs.length;
    }
    await _tracker.trackWrites(count);
    return count;
  }

  Future<int> clearAllDataByMonth(String roomId, String month) async {
    int total = 0;
    total += await clearExpensesByMonth(roomId, month);
    total += await clearBillsByMonth(roomId, month);
    total += await clearActivitiesByMonth(roomId, month);
    total += await clearSettlementsByMonth(roomId, month);
    total += await clearNotificationsByMonth(month);
    total += await clearPersonalTransactionsByMonth(month);
    return total;
  }

  Future<int> clearAllImages(String roomId) async {
    int deleted = 0;
    try {
      final listResult = await _storage.ref('receipts/$roomId').listAll();
      for (final folder in listResult.prefixes) {
        final items = await folder.listAll();
        for (final item in items.items) {
          await item.delete();
          deleted++;
        }
      }
    } catch (_) {}
    return deleted;
  }
}
