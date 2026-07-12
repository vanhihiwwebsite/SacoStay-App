import 'package:flutter/material.dart';

import '../../../core/utils/vip_tier.dart';

/// House-shaped map pin — mirrors web `createHouseMarkerIcon`.
class HouseMapMarker extends StatelessWidget {
  const HouseMapMarker({
    super.key,
    required this.tier,
    this.selected = false,
  });

  final VipTier tier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = vipTierMarkerColor(tier, selected: selected);
    return SizedBox(
      width: 36,
      height: 42,
      child: CustomPaint(
        painter: _HousePainter(color: color),
      ),
    );
  }
}

class _HousePainter extends CustomPainter {
  _HousePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 36;
    final scaleY = size.height / 42;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(const Offset(18, 38), 5, shadow);

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final roof = Path()
      ..moveTo(18, 2)
      ..lineTo(2, 14)
      ..lineTo(34, 14)
      ..close();
    canvas.drawPath(roof, fill);
    canvas.drawPath(roof, stroke);

    final body = Path()
      ..moveTo(4, 14)
      ..lineTo(4, 34)
      ..lineTo(14, 34)
      ..lineTo(14, 24)
      ..lineTo(22, 24)
      ..lineTo(22, 34)
      ..lineTo(32, 34)
      ..lineTo(32, 14)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    canvas.drawCircle(const Offset(18, 36), 4, fill);
    canvas.drawCircle(const Offset(18, 36), 4, stroke);
    canvas.drawLine(const Offset(18, 32), const Offset(18, 40), stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HousePainter oldDelegate) =>
      oldDelegate.color != color;
}
