enum ViewMode { grid, list }
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
}
enum TransferFilter { all, toSend, toReceive, done }

/// What the logged-in user can do next on a transfer.
enum TransferAction { none, send, receive }