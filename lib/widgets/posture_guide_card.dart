import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tarjeta con una ilustración de referencia + tips cortos de cómo tomar
/// la foto de espalda, para que el análisis salga confiable.
class PostureGuideCard extends StatelessWidget {
  const PostureGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 56,
            height: 68,
            child: CustomPaint(painter: _PostureGuidePainter()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cómo tomar la foto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'De espaldas a la cámara, de cuerpo entero, con buena luz '
                  'y sin ropa que tape hombros ni cadera.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedInk,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Silueta minimalista de espalda con la columna recta: sirve solo de
/// guía visual de encuadre, no representa ningún resultado de análisis.
class _PostureGuidePainter extends CustomPainter {
  const _PostureGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final headCenter = Offset(size.width / 2, size.height * 0.14);
    final headRadius = size.width * 0.17;
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, outlinePaint);

    final shoulderY = size.height * 0.32;
    final hipY = size.height * 0.88;
    final torsoPath = Path()
      ..moveTo(size.width * 0.18, shoulderY)
      ..lineTo(size.width * 0.82, shoulderY)
      ..quadraticBezierTo(
          size.width * 0.90, (shoulderY + hipY) / 2, size.width * 0.76, hipY)
      ..lineTo(size.width * 0.24, hipY)
      ..quadraticBezierTo(
          size.width * 0.10, (shoulderY + hipY) / 2, size.width * 0.18, shoulderY)
      ..close();
    canvas.drawPath(torsoPath, fillPaint);
    canvas.drawPath(torsoPath, outlinePaint);

    final spinePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, shoulderY + 4),
      Offset(size.width / 2, hipY - 4),
      spinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
