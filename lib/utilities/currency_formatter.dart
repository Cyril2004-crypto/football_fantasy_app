import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatPrice(double price) {
    if (price >= 1) {
      return '£${price.toStringAsFixed(1)}m';
    } else {
      return '£${(price * 10).toStringAsFixed(1)}m';
    }
  }

  static String formatBudget(double budget) {
    return '£${budget.toStringAsFixed(1)}m';
  }

  static String formatPoints(int points) {
    return NumberFormat('#,###').format(points);
  }

  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  static String formatRank(int rank) {
    if (rank >= 1000000) {
      return '${(rank / 1000000).toStringAsFixed(1)}M';
    } else if (rank >= 1000) {
      return '${(rank / 1000).toStringAsFixed(1)}K';
    } else {
      return rank.toString();
    }
  }
}
