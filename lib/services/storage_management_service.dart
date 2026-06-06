import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthData {
  final int expenses;
  final int bills;
  final int activities;
  final int settlements;
  final int notifications;

  const MonthData({
    this.expenses = 0,
    this.bills = 0,
    this.activities = 0,
    this.settlements = 0,
    this.notifications = 0,
  });

  int get total => expenses + bills + activities + settlements + notifications;
}

class StorageStats {
  final int totalExpenses;
  final int totalBills;
  final int totalActivities;
  final int totalSettlements;
  final int totalNotifications;
  final int totalImages;
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
    required this.totalImages,
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
      totalNotifications;
}

class StorageManagementService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> trackRead(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('usage_date') ?? '';
    if (storedDate != today) {
      await prefs.setString('usage_date', today);
      await prefs.setInt('daily_reads', count);
      await prefs.setInt('daily_writes', 0);
    } else {
      final current = prefs.getInt('daily_reads') ?? 0;
      await prefs.setInt('daily_reads', current + count);
    }
  }

  Future<void> trackWrite(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('usage_date') ?? '';
    if (storedDate != today) {
      await prefs.setString('usage_date', today);
      await prefs.setInt('daily_reads', 0);
      await prefs.setInt('daily_writes', count);
    } else {
      final current = prefs.getInt('daily_writes') ?? 0;
      await prefs.setInt('daily_writes', current + count);
    }
  }

  Future<Map<String, int>> _getDailyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString('usage_date') ?? '';
    if (storedDate != today) return {'reads': 0, 'writes': 0};
    return {
      'reads': prefs.getInt('daily_reads') ?? 0,
      'writes': prefs.getInt('daily_writes') ?? 0,
    };
  }

  String _monthFromTimestamp(Timestamp? ts) {
    if (ts == null) return 'unknown';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<StorageStats> getStats(String roomId, String userId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    final expensesSnap = await roomRef.collection('expenses').get();
    final billsSnap = await roomRef.collection('bills').get();
    final activitiesSnap = await roomRef.collection('activities').get();
    final settlementsSnap = await roomRef.collection('settlements').get();
    final notificationsSnap = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .get();

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

    final dataByMonth = monthMap.map(
      (month, counts) => MapEntry(
        month,
        MonthData(
          expenses: counts['expenses'] ?? 0,
          bills: counts['bills'] ?? 0,
          activities: counts['activities'] ?? 0,
          settlements: counts['settlements'] ?? 0,
          notifications: counts['notifications'] ?? 0,
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
        notificationsSnap.docs.length;

    final dailyUsage = await _getDailyUsage();
    final readsUsed = totalDocs + 5;
    await trackRead(readsUsed);

    return StorageStats(
      totalExpenses: expensesSnap.docs.length,
      totalBills: billsSnap.docs.length,
      totalActivities: activitiesSnap.docs.length,
      totalSettlements: settlementsSnap.docs.length,
      totalNotifications: notificationsSnap.docs.length,
      totalImages: totalImages,
      dataByMonth: dataByMonth,
      estimatedImageSizeBytes: estimatedImageSize,
      estimatedDocSizeBytes: totalDocs * 1024,
      dailyReads: dailyUsage['reads']! + readsUsed,
      dailyWrites: dailyUsage['writes']!,
    );
  }

  Future<int> clearExpensesByMonth(String roomId, String month) async {
    final snap = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('expenses')
        .where('month', isEqualTo: month)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await trackWrite(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearBillsByMonth(String roomId, String month) async {
    final snap = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await trackWrite(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearActivitiesByMonth(String roomId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('activities')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await trackWrite(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearSettlementsByMonth(String roomId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('settlements')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await trackWrite(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearNotificationsByMonth(String userId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1);
    final snap = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    await trackWrite(snap.docs.length);
    return snap.docs.length;
  }

  Future<int> clearAllDataByMonth(
    String roomId,
    String userId,
    String month,
  ) async {
    int total = 0;
    total += await clearExpensesByMonth(roomId, month);
    total += await clearBillsByMonth(roomId, month);
    total += await clearActivitiesByMonth(roomId, month);
    total += await clearSettlementsByMonth(roomId, month);
    total += await clearNotificationsByMonth(userId, month);
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
