import 'package:flutter/foundation.dart';

import 'api.dart';
import 'data.dart';

/// Holds the batches shown in the app. Loads from the server, or uses the
/// built-in sample content while the server address is not set yet.
class Catalog extends ChangeNotifier {
  static final Catalog instance = Catalog._();
  Catalog._();

  List<Batch> batches = [];
  bool loading = false;
  bool usingSample = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (!Api.isConfigured) {
        batches = sampleBatches;
        usingSample = true;
      } else {
        usingSample = false;
        batches = parseCatalog(await Api.catalogJson());
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
