/// Single source of truth for load-related constants used across
/// PostLoadScreen, FindLoadsScreen, EntityExtractor, and the bot.
class LoadConstants {
  LoadConstants._();

  static const materials = [
    'Steel',
    'Cement',
    'Coal',
    'Sand',
    'Gravel',
    'Timber',
    'Cotton',
    'Rice',
    'Wheat',
    'Sugar',
    'Fertilizer',
    'Chemicals',
    'Electronics',
    'Furniture',
    'Machinery',
    'Pulses',
    'Oil',
    'Tiles',
    'Marble',
    'Granite',
    'Stone',
    'FMCG',
    'Other',
  ];

  static const truckTypes = [
    'Any',
    'Open',
    'Container',
    'Trailer',
    'Tanker',
    'Refrigerated',
  ];

  static const tyreOptions = [6, 10, 12, 14, 16, 18, 22];

  /// Broader categories used in FindLoads filter chips.
  static const filterMaterials = [
    'Any',
    'Steel',
    'Cement',
    'Coal',
    'Agriculture',
    'Chemicals',
    'Construction',
    'FMCG',
    'Other',
  ];

  /// P0-5: Maps category filter names to actual material values in the DB.
  /// Categories that map to multiple materials use `.in_()` query.
  /// Single-material categories use direct `.ilike()` match.
  static const Map<String, List<String>> categoryMaterialMap = {
    'Steel': ['Steel'],
    'Cement': ['Cement'],
    'Coal': ['Coal'],
    'Agriculture': ['Rice', 'Wheat', 'Sugar', 'Cotton', 'Pulses', 'Oil'],
    'Chemicals': ['Chemicals', 'Fertilizer'],
    'Construction': ['Cement', 'Sand', 'Gravel', 'Stone', 'Marble', 'Granite', 'Tiles'],
    'FMCG': ['FMCG', 'Electronics', 'Furniture'],
    'Other': ['Other', 'Timber', 'Machinery'],
  };
}
