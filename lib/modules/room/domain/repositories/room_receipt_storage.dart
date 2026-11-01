abstract interface class RoomReceiptStorage {
  Future<String?> pickImagePath({bool fromCamera = false});
  Future<String?> uploadReceipt({
    required String filePath,
    required String roomId,
    required String folder,
  });
}
