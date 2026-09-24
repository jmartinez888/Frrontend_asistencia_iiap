import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class PendingCheckoutCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onManualRecord;

  const PendingCheckoutCard({
    super.key,
    required this.item,
    this.onManualRecord,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userName = item['user_name']?.toString() ?? 'Colaborador';
    final userEmail = item['user_email']?.toString() ?? '';
    final userDni = item['user_document']?.toString() ?? '';
    final workDate = item['work_date']?.toString() ?? '';
    final shiftLabel = item['shift_label']?.toString() ?? 'Mañana';
    final checkInTime = item['check_in_time']?.toString() ?? '—';
    final isToday = item['is_today'] == true;
    final hasPassedExit = item['has_passed_exit'] == true;
    final isMissing = !isToday || hasPassedExit;

    final isMorning = shiftLabel.toLowerCase().contains('mañana');
    final shiftColor = isMorning
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThemeService.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMissing
              ? Colors.amber.withValues(alpha: isDark ? 0.35 : 0.45)
              : ThemeService.cardBorder(context),
          width: isMissing ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila Superior: Nombre del Usuario + Badge de Alerta
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: shiftColor.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: shiftColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userDni.isNotEmpty ? 'DNI: $userDni • $userEmail' : userEmail,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMissing
                        ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)).withValues(alpha: 0.7)
                        : Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMissing ? Icons.warning_amber_rounded : Icons.timelapse_rounded,
                        size: 13,
                        color: isMissing
                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                            : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMissing ? 'Sin Salida' : 'En jornada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMissing
                              ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Detalles del turno y la entrada
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(workDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: shiftColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Turno $shiftLabel',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: shiftColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'Entrada: $checkInTime',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
