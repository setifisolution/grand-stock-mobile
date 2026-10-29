import 'package:flutter/material.dart';

import '../models/transfer_intern_model.dart';

class AppIcons {
  static IconData statusIcon(String s) => switch (s) {
    TransferStatus.pending => Icons.schedule_rounded,
    TransferStatus.sent => Icons.local_shipping_rounded,
    TransferStatus.received => Icons.check_circle_rounded,
    TransferStatus.cancelled => Icons.cancel_rounded,
    _ => Icons.help_outline_rounded,
  };
}
