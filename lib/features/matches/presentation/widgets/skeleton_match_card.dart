import 'package:flutter/material.dart';
import 'package:hamme_app/utils/constants/colors.dart';

class SkeletonMatchCard extends StatelessWidget {
  const SkeletonMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
