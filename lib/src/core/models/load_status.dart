enum LoadStatus {
  active,
  pendingApproval,
  booked,
  inTransit,
  delivered,
  completed,
  cancelled,
  expired;

  static LoadStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return LoadStatus.active;
      case 'pending_approval':
        return LoadStatus.pendingApproval;
      case 'booked':
        return LoadStatus.booked;
      case 'in_transit':
        return LoadStatus.inTransit;
      case 'delivered':
        return LoadStatus.delivered;
      case 'completed':
        return LoadStatus.completed;
      case 'cancelled':
        return LoadStatus.cancelled;
      case 'expired':
        return LoadStatus.expired;
      default:
        return LoadStatus.active;
    }
  }

  String toDbValue() {
    switch (this) {
      case LoadStatus.active:
        return 'active';
      case LoadStatus.pendingApproval:
        return 'pending_approval';
      case LoadStatus.booked:
        return 'booked';
      case LoadStatus.inTransit:
        return 'in_transit';
      case LoadStatus.delivered:
        return 'delivered';
      case LoadStatus.completed:
        return 'completed';
      case LoadStatus.cancelled:
        return 'cancelled';
      case LoadStatus.expired:
        return 'expired';
    }
  }

  bool canTransitionTo(LoadStatus next) {
    switch (this) {
      case LoadStatus.active:
        return next == LoadStatus.pendingApproval ||
            next == LoadStatus.cancelled ||
            next == LoadStatus.expired;
      case LoadStatus.pendingApproval:
        return next == LoadStatus.booked ||
            next == LoadStatus.active; // rejection resets to active
      case LoadStatus.booked:
        return next == LoadStatus.inTransit ||
            next == LoadStatus.cancelled;
      case LoadStatus.inTransit:
        return next == LoadStatus.delivered ||
            next == LoadStatus.completed;
      case LoadStatus.delivered:
        return next == LoadStatus.completed;
      case LoadStatus.completed:
        return false;
      case LoadStatus.cancelled:
        return false;
      case LoadStatus.expired:
        return false;
    }
  }

  String displayName(String role, String locale) {
    if (locale == 'hi') {
      return _hindiDisplayName(role);
    }
    return _englishDisplayName(role);
  }

  String _englishDisplayName(String role) {
    switch (this) {
      case LoadStatus.active:
        return role == 'supplier'
            ? 'Live — waiting for truckers'
            : 'Available';
      case LoadStatus.pendingApproval:
        return role == 'supplier'
            ? 'Booking request received'
            : 'Awaiting supplier approval';
      case LoadStatus.booked:
        return 'Booked';
      case LoadStatus.inTransit:
        return 'In Transit';
      case LoadStatus.delivered:
        return role == 'supplier'
            ? 'Delivered — confirm receipt'
            : 'Delivered — awaiting confirmation';
      case LoadStatus.completed:
        return 'Completed';
      case LoadStatus.cancelled:
        return 'Cancelled';
      case LoadStatus.expired:
        return 'Expired';
    }
  }

  String _hindiDisplayName(String role) {
    switch (this) {
      case LoadStatus.active:
        return role == 'supplier'
            ? 'लाइव — ट्रकर्स का इंतजार'
            : 'उपलब्ध';
      case LoadStatus.pendingApproval:
        return role == 'supplier'
            ? 'बुकिंग रिक्वेस्ट आई है'
            : 'सप्लायर की मंजूरी का इंतजार';
      case LoadStatus.booked:
        return 'बुक हो गया';
      case LoadStatus.inTransit:
        return 'रास्ते में';
      case LoadStatus.delivered:
        return role == 'supplier'
            ? 'डिलीवर हुआ — पुष्टि करें'
            : 'डिलीवर हुआ — पुष्टि का इंतजार';
      case LoadStatus.completed:
        return 'पूरा हुआ';
      case LoadStatus.cancelled:
        return 'रद्द';
      case LoadStatus.expired:
        return 'समय समाप्त';
    }
  }

  String? primaryAction(String role) {
    switch (this) {
      case LoadStatus.active:
        return role == 'trucker' ? 'Book Load' : null;
      case LoadStatus.pendingApproval:
        return role == 'supplier' ? 'Approve / Reject' : null;
      case LoadStatus.booked:
        return role == 'trucker' ? 'Start Trip' : null;
      case LoadStatus.inTransit:
        return role == 'trucker' ? 'Mark Delivered' : null;
      case LoadStatus.delivered:
        return role == 'supplier' ? 'Confirm Delivery' : null;
      case LoadStatus.completed:
      case LoadStatus.cancelled:
      case LoadStatus.expired:
        return null;
    }
  }

  bool get isTerminal =>
      this == LoadStatus.completed ||
      this == LoadStatus.cancelled ||
      this == LoadStatus.expired;
}
