import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class PdfReportService {
  /// Genera y abre el visor de impresión / descarga de reporte PDF institucional del IIAP
  static Future<void> generateAndPreviewReport({
    required List<AttendanceModel> records,
    required UserModel currentUser,
    String? dateFilter,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final nowFormatted = '${_formatDate(now)} - ${_formatTime(now)}';

    // Estadísticas
    final total = records.length;
    final totalEntradas = records.where((r) => r.type == AttendanceType.CHECK_IN).length;
    final totalSalidas = records.where((r) => r.type == AttendanceType.CHECK_OUT).length;
    final totalManuales = records.where((r) => r.isManual).length;

    // Colores institucionales IIAP
    const primaryGreen = PdfColor.fromInt(0xFF004D40); // Verde IIAP oscuro
    const accentGreen = PdfColor.fromInt(0xFF00796B);
    const lightBg = PdfColor.fromInt(0xFFF1F8F6);
    const zebraBg = PdfColor.fromInt(0xFFFAFAFA);
    const textDark = PdfColor.fromInt(0xFF212121);
    const textMuted = PdfColor.fromInt(0xFF616161);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: primaryGreen, width: 2)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INSTITUTO DE INVESTIGACIONES DE LA AMAZONÍA PERUANA',
                      style: pw.TextStyle(
                        color: primaryGreen,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'SISTEMA INTEGRADO DE CONTROL DE ASISTENCIA (IIAP)',
                      style: const pw.TextStyle(
                        color: textMuted,
                        fontSize: 9,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'REPORTE OFICIAL CONSOLIDADO DE ASISTENCIAS',
                      style: pw.TextStyle(
                        color: primaryGreen,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: accentGreen, width: 0.8),
                      ),
                      child: pw.Text(
                        'SEDE CENTRAL IQUITOS',
                        style: pw.TextStyle(
                          color: primaryGreen,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Emisión: $nowFormatted',
                      style: const pw.TextStyle(color: textMuted, fontSize: 8),
                    ),
                    pw.Text(
                      'Generado por: ${currentUser.fullName} (${currentUser.role.name.toUpperCase()})',
                      style: const pw.TextStyle(color: textMuted, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'IIAP - Control de Asistencia © ${DateTime.now().year} | Documento Oficial de Auditoría Interna',
                  style: const pw.TextStyle(color: textMuted, fontSize: 8),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    color: primaryGreen,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Tarjetas de Resumen
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.teal200, width: 0.8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('Total Registros', '$total', primaryGreen),
                  _buildMetric('Entradas', '$totalEntradas', PdfColors.green800),
                  _buildMetric('Salidas', '$totalSalidas', PdfColors.orange800),
                  _buildMetric('Contingencia / Manuales', '$totalManuales', PdfColors.amber900),
                ],
              ),
            ),

            // Tabla de Registros
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryGreen),
              headerHeight: 24,
              cellHeight: 22,
              cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.centerLeft,
              },
              headers: [
                'N°',
                'Colaborador',
                'Fecha',
                'Hora',
                'Tipo',
                'Modalidad',
                'Observación / Justificación',
              ],
              data: List.generate(records.length, (index) {
                final r = records[index];
                final isCheckIn = r.type == AttendanceType.CHECK_IN;
                final tipo = isCheckIn ? 'ENTRADA' : 'SALIDA';
                final modalidad = r.isManual ? 'MANUAL' : 'CÓDIGO QR';
                final obs = r.observation?.isNotEmpty == true
                    ? r.observation!
                    : (r.isManual ? 'Avería/Pérdida de celular' : 'Registro Regular');

                return [
                  '${index + 1}',
                  r.userName ?? 'Usuario ID: ${r.userId.substring(0, r.userId.length > 8 ? 8 : r.userId.length)}...',
                  _formatDate(r.timestamp),
                  _formatTime(r.timestamp),
                  tipo,
                  modalidad,
                  obs,
                ];
              }),
              oddRowDecoration: const pw.BoxDecoration(color: zebraBg),
            ),

            pw.SizedBox(height: 20),

            // Firmas de Conformidad
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 24),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma de Supervisor / Garita', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                      pw.Text('Control de Asistencia IIAP', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('V°B° Administración / RRHH', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                      pw.Text('Dirección General IIAP', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Abrir la previsualización nativa con opciones de impresión y compartir PDF
    final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Asistencias_IIAP_$fileDate.pdf',
    );
  }

  static pw.Widget _buildMetric(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF616161),
            fontSize: 7.5,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute:$second $ampm';
  }
}
