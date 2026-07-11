import 'package:flutter/material.dart';
import 'package:wanderwell/data/wonder_categories.dart';

class WonderMapPin extends StatelessWidget {
  final WonderCategory category;
  final bool selected;

  const WonderMapPin({
    super.key,
    required this.category,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 36.0 : 28.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        category.icon,
        size: selected ? 18 : 14,
        color: Colors.white,
      ),
    );
  }
}
