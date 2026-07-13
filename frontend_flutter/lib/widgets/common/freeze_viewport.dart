import 'package:flutter/material.dart';

class FreezeViewport extends StatelessWidget {
  final Widget child;
  final double freezeWidth;

  const FreezeViewport({
    super.key,
    required this.child,
    this.freezeWidth = 1100,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(size: Size(freezeWidth, mq.size.height)),
      child: child,
    );
  }
}
