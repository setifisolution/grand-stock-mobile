import '../models/transfer_intern_model.dart';

class AppStrings {
  static String statusLabel(String s) => switch (s) {
    TransferStatus.pending => "En attente d'envoi",
    TransferStatus.sent => 'En route',
    TransferStatus.received => 'Reçu',
    TransferStatus.cancelled => 'Annulé',
    _ => s,
  };
}
