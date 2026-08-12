import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A 5-star rating row (blueprint §4.3).
///
/// Renders filled stars based on [rating] (0–5). Fractional ratings fill the
/// star when they round to that index.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
  });

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i - 0.5 ? Icons.star : Icons.star_border,
            size: size,
            color: rating >= i - 0.5 ? AppColors.warning : AppColors.neutralText,
          ),
      ],
    );
  }
}
