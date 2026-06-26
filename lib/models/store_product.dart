enum ProductKind { premiumCountry, unlimited }

/// A purchasable product, as presented to the user. In production [priceLabel]
/// comes from the store (localised); [id] maps to the store product id.
class StoreProduct {
  final String id;
  final ProductKind kind;
  final String title;
  final String description;
  final String priceLabel;

  const StoreProduct({
    required this.id,
    required this.kind,
    required this.title,
    this.description = '',
    required this.priceLabel,
  });
}

class PurchaseOutcome {
  final bool success;
  final bool cancelled;
  final String? error;

  const PurchaseOutcome.success()
      : success = true,
        cancelled = false,
        error = null;

  const PurchaseOutcome.cancelled()
      : success = false,
        cancelled = true,
        error = null;

  const PurchaseOutcome.failed(this.error)
      : success = false,
        cancelled = false;
}
