import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kPrimaryColor),
    );
  }
}
