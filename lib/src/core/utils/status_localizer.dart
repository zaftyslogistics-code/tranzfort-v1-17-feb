/// Centralised display + spoken text for all DB status values.
/// Covers load status, trip status, verification status, and trip stage.
class StatusLocalizer {
  StatusLocalizer._();

  // ── Load / Trip status ──────────────────────────────────────────────────────

  static String displayText(String status, String languageCode) {
    if (languageCode == 'hi') return _hiDisplay[status] ?? status;
    return _enDisplay[status] ?? status;
  }

  static String spokenText(String status, String languageCode) {
    if (languageCode == 'hi') return _hiSpoken[status] ?? status;
    return _enSpoken[status] ?? status;
  }

  // ── Trip stage ──────────────────────────────────────────────────────────────

  static String stageDisplay(String stage, String languageCode) {
    if (languageCode == 'hi') return _hiStageDisplay[stage] ?? stage;
    return _enStageDisplay[stage] ?? stage;
  }

  static String stageSpoken(String stage, String languageCode) {
    if (languageCode == 'hi') return _hiStageSpoken[stage] ?? stage;
    return _enStageSpoken[stage] ?? stage;
  }

  // ── EN display ──────────────────────────────────────────────────────────────

  static const _enDisplay = {
    'unverified': 'Unverified',
    'pending': 'Pending',
    'verified': 'Verified',
    'rejected': 'Rejected',
    'active': 'Active',
    'booked': 'Booked',
    'in_transit': 'In Transit',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };

  static const _enSpoken = {
    'unverified': 'Not verified',
    'pending': 'Under review',
    'verified': 'Verified',
    'rejected': 'Rejected',
    'active': 'Active',
    'booked': 'Booked',
    'in_transit': 'In transit',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };

  // ── HI display ──────────────────────────────────────────────────────────────

  static const _hiDisplay = {
    'unverified': 'अवेरिफाइड',
    'pending': 'पेंडिंग',
    'verified': 'वेरिफाइड',
    'rejected': 'अस्वीकृत',
    'active': 'एक्टिव',
    'booked': 'बुक्ड',
    'in_transit': 'ट्रांज़िट में',
    'completed': 'पूर्ण',
    'cancelled': 'रद्द',
    'expired': 'एक्सपायर्ड',
  };

  static const _hiSpoken = {
    'unverified': 'वेरिफाई नहीं हुआ',
    'pending': 'समीक्षा में है',
    'verified': 'वेरिफाइड',
    'rejected': 'अस्वीकृत',
    'active': 'एक्टिव',
    'booked': 'बुक हो गया',
    'in_transit': 'रास्ते में है',
    'completed': 'पूरा हो गया',
    'cancelled': 'रद्द हो गया',
    'expired': 'समय सीमा समाप्त',
  };

  // ── EN stage display / spoken ───────────────────────────────────────────────

  static const _enStageDisplay = {
    'not_started': 'Not Started',
    'reached_pickup': 'Reached Pickup',
    'loading': 'Loading',
    'in_transit': 'In Transit',
    'reached_destination': 'Reached Destination',
    'unloading': 'Unloading',
    'delivered': 'Delivered',
  };

  static const _enStageSpoken = {
    'not_started': 'Not started yet',
    'reached_pickup': 'Reached pickup point',
    'loading': 'Loading goods onto truck',
    'in_transit': 'In transit, on the way',
    'reached_destination': 'Reached destination',
    'unloading': 'Unloading goods',
    'delivered': 'Delivered successfully',
  };

  // ── HI stage display / spoken ───────────────────────────────────────────────

  static const _hiStageDisplay = {
    'not_started': 'शुरू नहीं हुआ',
    'reached_pickup': 'उठान स्थान पहुँचे',
    'loading': 'लोड हो रहा है',
    'in_transit': 'रास्ते में',
    'reached_destination': 'गंतव्य पहुँचे',
    'unloading': 'उतर रहा है',
    'delivered': 'डिलीवर हो गया',
  };

  static const _hiStageSpoken = {
    'not_started': 'अभी शुरू नहीं हुआ',
    'reached_pickup': 'उठान स्थान पहुँच गए',
    'loading': 'ट्रक पर माल लोड हो रहा है',
    'in_transit': 'रास्ते में है',
    'reached_destination': 'गंतव्य पहुँच गए',
    'unloading': 'माल उतर रहा है',
    'delivered': 'सफलतापूर्वक डिलीवर हो गया',
  };
}
