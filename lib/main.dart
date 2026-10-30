import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';

// ======================== SEARCH HELPERS ========================
const Map<int, String> _foldMap = {
  0x00E0: 'a', 0x00E1: 'a', 0x00E2: 'a', 0x00E3: 'a', 0x00E4: 'a', 0x00E5: 'a',
  0x00E7: 'c',
  0x00E8: 'e', 0x00E9: 'e', 0x00EA: 'e', 0x00EB: 'e',
  0x00EC: 'i', 0x00ED: 'i', 0x00EE: 'i', 0x00EF: 'i',
  0x00F1: 'n',
  0x00F2: 'o', 0x00F3: 'o', 0x00F4: 'o', 0x00F5: 'o', 0x00F6: 'o',
  0x00F9: 'u', 0x00FA: 'u', 0x00FB: 'u', 0x00FC: 'u',
  0x00FD: 'y', 0x00FF: 'y',
  0x0153: 'oe', 0x00E6: 'ae',
};

String _foldForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final replacement = _foldMap[rune];
    if (replacement != null) {
      buffer.write(replacement);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _isWordBoundary(String ch) {
  if (ch.isEmpty) return true;
  final code = ch.codeUnitAt(0);
  if (code <= 32) return true;
  return ch == ',' || ch == '.' || ch == ';' || ch == ':' || ch == '!' ||
      ch == '?' || ch == '-' || ch == '(' || ch == ')' || ch == '[' ||
      ch == ']' || ch == '\'' || ch == '"' || ch == '«' || ch == '»' ||
      ch == '/' || ch == '&' || ch == '+';
}

bool _containsWholeWord(String text, String word) {
  if (word.isEmpty) return false;
  var index = 0;
  while (true) {
    index = text.indexOf(word, index);
    if (index == -1) return false;
    final before = index == 0 ? ' ' : text[index - 1];
    final afterIdx = index + word.length;
    final after = afterIdx >= text.length ? ' ' : text[afterIdx];
    if (_isWordBoundary(before) && _isWordBoundary(after)) return true;
    index = afterIdx;
  }
}

int _compareHymnNumber(String a, String b) {
  final ai = int.tryParse(a);
  final bi = int.tryParse(b);
  if (ai != null && bi != null) return ai.compareTo(bi);
  if (ai != null) return -1;
  if (bi != null) return 1;
  return a.compareTo(b);
}

class _HymnSearchIndex {
  final String numberFolded;
  final String titleFolded;
  final String auteurFolded;
  final String themesFolded;
  final String lyricsFolded;

  _HymnSearchIndex(Hymn h)
      : numberFolded = _foldForSearch(h.number),
        titleFolded = _foldForSearch(h.title),
        auteurFolded = _foldForSearch(h.auteur ?? ''),
        themesFolded = _foldForSearch(h.themes ?? ''),
        lyricsFolded = _foldForSearch(h.lyrics);
}

int _scoreMatch(_HymnSearchIndex idx, String q) {
  if (q.isEmpty) return 0;
  if (idx.numberFolded == q) return 100000;
  if (idx.numberFolded.startsWith(q)) return 90000;
  if (idx.titleFolded == q) return 80000;
  if (idx.titleFolded.startsWith(q)) return 70000;
  if (_containsWholeWord(idx.titleFolded, q)) return 60000;
  if (idx.titleFolded.contains(q)) return 50000;
  if (_containsWholeWord(idx.auteurFolded, q)) return 40000;
  if (idx.auteurFolded.contains(q)) return 35000;
  if (_containsWholeWord(idx.themesFolded, q)) return 30000;
  if (idx.themesFolded.contains(q)) return 25000;
  if (q.length >= 2 && idx.lyricsFolded.contains(q)) return 5000;
  return 0;
}

/// ======================== INFO CARD (Bottom Sheet Content) ========================
class InfoAuteurChant extends StatelessWidget {
  final String titreChant;
  final String auteur;
  final String annee;
  final String histoire;
  final String? compositeur;
  final String? traducteur;
  final String? source;
  final String? referenceBiblique;
  final String? themes;
  final String? metadataReviewNote;

  const InfoAuteurChant({
    super.key,
    required this.titreChant,
    required this.auteur,
    required this.annee,
    required this.histoire,
    this.compositeur,
    this.traducteur,
    this.source,
    this.referenceBiblique,
    this.themes,
    this.metadataReviewNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget detail(String label, String? value, IconData icon) {
      if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '$label : ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'À propos de : $titreChant',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                detail('Auteur', auteur, Icons.person_outline_rounded),
                detail('Année', annee, Icons.event_outlined),
                detail('Compositeur', compositeur, Icons.music_note_rounded),
                detail('Traducteur', traducteur, Icons.translate_rounded),
                detail('Source', source, Icons.menu_book_rounded),
                detail('Référence', referenceBiblique, Icons.auto_stories_rounded),
                detail('Thèmes', themes, Icons.sell_outlined),
              ],
            ),
          ),
          if ((metadataReviewNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.tertiary.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Note : ${metadataReviewNote!.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
          if (histoire.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Histoire du cantique',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              histoire,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================== READER ========================
class HymnReaderScreen extends StatefulWidget {
  final Hymn hymn;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final double fontSize;
  final double scrollSpeed;

  const HymnReaderScreen({
    super.key,
    required this.hymn,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.fontSize,
    required this.scrollSpeed,
  });

  @override
  State<HymnReaderScreen> createState() => _HymnReaderScreenState();
}

class _HymnReaderScreenState extends State<HymnReaderScreen> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
  }

  void _toggleFavorite() {
    setState(() => _isFav = !_isFav);
    widget.onToggleFavorite();
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65, // Starts at 65% of screen height
        minChildSize: 0.3,
        maxChildSize: 0.95, // Never covers the whole screen (leaves 5%)
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: InfoAuteurChant(
              titreChant: widget.hymn.title,
              auteur: widget.hymn.auteur ?? 'Inconnu',
              annee: widget.hymn.annee ?? '',
              histoire: widget.hymn.histoire ?? '',
              compositeur: widget.hymn.compositeur,
              traducteur: widget.hymn.traducteur,
              source: widget.hymn.source,
              referenceBiblique: widget.hymn.referenceBiblique,
              themes: widget.hymn.themes,
              metadataReviewNote: widget.hymn.metadataReviewNote,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.hymn.number}. ${widget.hymn.title}"),
        actions: [
          if (!widget.hymn.isCustom)
            IconButton(
              icon: Icon(
                _isFav ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: _toggleFavorite,
            ),
          // NEW: Info Button to trigger the Bottom Sheet
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'À propos',
            onPressed: () => _showInfoSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share_txt') {
                Share.share(_hymnShareText(widget.hymn),
                    subject: "Chants de Victoire - ${widget.hymn.title}");
              } else if (value == 'share_pdf') {
                _exportPdf(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'share_txt',
                  child: ListTile(
                    leading:
                        Icon(Icons.text_snippet, color: AppTheme.primaryGreen),
                    title: Text("Exporter en TXT"),
                    contentPadding: EdgeInsets.zero,
                  )),
              const PopupMenuItem(
                  value: 'share_pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text("Exporter en PDF"),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                child: SelectionArea(
                  child: Text(
                    widget.hymn.lyrics,
                    style: TextStyle(fontSize: widget.fontSize, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 60), // Padding at bottom so FAB doesn't cover text
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.fullscreen),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorshipModeScreen(
                hymn: widget.hymn,
                scrollSpeed: widget.scrollSpeed,
                fontSize: widget.fontSize.clamp(24.0, 40.0),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final file = await PdfGenerator.generateHymnPdf(widget.hymn);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Share.shareXFiles([XFile(file.path)],
          subject: '${widget.hymn.title} — PDF');
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export PDF impossible : $error')),
      );
    }
  }
}

void main() {
  runApp(const ChantsDeVictoireApp());
}

// ======================== APP ROOT ========================
class ChantsDeVictoireApp extends StatelessWidget {
  const ChantsDeVictoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chants de Victoire',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

// ======================== THEME ========================
class AppTheme {
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color splashRed = Color(0xFFB71C1C);
  static const Color gold = Color(0xFFFFC107);
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color cardBackground = Color(0xFF1A1D24);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: gold,
        surface: cardBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
      ),
    );
  }

  static double responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12;
    if (width < 600) return 16;
    return 24;
  }

  static double responsiveFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return base * 0.8;
    if (width < 600) return base;
    return base * 1.2;
  }
}

// ======================== BEAUTIFUL ADAPTIVE PDF GENERATION ========================
class PdfGenerator {
  static const PdfColor _brandGreen = PdfColor.fromInt(0xFF1B5E20);
  static const PdfColor _brandGold = PdfColor.fromInt(0xFFFFC107);
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFF0F0F0);
  static const PdfColor _midGrey = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _darkText = PdfColor.fromInt(0xFF1F2937);

  static Future<File> generateHymnPdf(Hymn hymn) => _generatePdf(
        hymns: [hymn],
        fileName: '${hymn.number}_${hymn.title}',
        documentTitle: 'Chants de Victoire — ${hymn.title}',
        startEachHymnOnNewPage: false,
        includeTitlePage: false,
      );

  static Future<File> generateFavoritesPdf(List<Hymn> hymns) => _generatePdf(
        hymns: hymns,
        fileName: 'Chants_Favorites',
        documentTitle: 'Mes Favoris',
        startEachHymnOnNewPage: true,
        includeTitlePage: true,
      );

  static Future<File> generateSongsPdf(List<Hymn> hymns) => _generatePdf(
        hymns: hymns,
        fileName: 'Mes_Chants',
        documentTitle: 'Mes Chants Personnels',
        startEachHymnOnNewPage: true,
        includeTitlePage: true,
      );

  static Future<File> _generatePdf({
    required List<Hymn> hymns,
    required String fileName,
    required String documentTitle,
    required bool startEachHymnOnNewPage,
    required bool includeTitlePage,
  }) async {
    if (hymns.isEmpty) throw ArgumentError('Aucun cantique à exporter.');

    final pdf = pw.Document(
      compress: true,
      title: documentTitle,
      author: 'Chants de Victoire',
      subject: 'Cantiques',
      creator: 'Chants de Victoire App',
    );

    final serif = pw.Font.times();
    final serifItalic = pw.Font.timesItalic();
    final sans = pw.Font.helvetica();
    final sansBold = pw.Font.helveticaBold();

    final coverTitleStyle = pw.TextStyle(font: sansBold, fontSize: 36, color: _brandGreen, lineSpacing: 6);
    final coverSubtitleStyle = pw.TextStyle(font: serifItalic, fontSize: 14, color: _midGrey);
    final hymnTitleStyle = pw.TextStyle(font: sansBold, fontSize: 22, color: _darkText, lineSpacing: 4);
    final creditStyle = pw.TextStyle(font: serifItalic, fontSize: 10, color: _midGrey, lineSpacing: 3);
    final numberStyle = pw.TextStyle(font: sansBold, fontSize: 12, color: _brandGreen);
    final bodyStyle = pw.TextStyle(font: serif, fontSize: 12, color: _darkText, lineSpacing: 4);
    final sectionLabelStyle = pw.TextStyle(font: sansBold, fontSize: 11, color: _brandGreen, letterSpacing: 0.8);
    final repeatStyle = pw.TextStyle(font: serifItalic, fontSize: 9.5, color: _midGrey);
    final pageNumberStyle = pw.TextStyle(font: sans, fontSize: 9, color: _midGrey);
    final headerStyle = pw.TextStyle(font: serifItalic, fontSize: 9, color: _midGrey);

    if (includeTitlePage) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(60),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Spacer(flex: 2),
              pw.Container(
                padding: const pw.EdgeInsets.all(30),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _brandGreen, width: 2),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('CHANTS DE VICTOIRE', style: pw.TextStyle(font: sansBold, fontSize: 14, color: _brandGreen, letterSpacing: 3)),
                    pw.SizedBox(height: 24),
                    pw.Text(documentTitle, textAlign: pw.TextAlign.center, style: coverTitleStyle),
                    pw.SizedBox(height: 12),
                    pw.Container(width: 80, height: 3, color: _brandGold),
                    pw.SizedBox(height: 12),
                    pw.Text('${hymns.length} cantique${hymns.length > 1 ? 's' : ''}', style: coverSubtitleStyle),
                    pw.SizedBox(height: 6),
                    pw.Text('Exporté le ${_formatDate(DateTime.now())}', style: coverSubtitleStyle),
                  ],
                ),
              ),
              pw.Spacer(flex: 3),
              pw.Text('Que tout ce qui respire loue l\'Éternel !', style: pw.TextStyle(font: serifItalic, fontSize: 12, color: _midGrey)),
            ],
          ),
        ),
      ));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(55, 65, 55, 55),
        maxPages: 2000,
        header: (context) {
          if (includeTitlePage && context.pageNumber == 2) return pw.SizedBox();
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _lightGrey, width: 1))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Chants de Victoire', style: headerStyle),
                pw.Text(documentTitle, style: headerStyle),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('— ', style: pageNumberStyle),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(color: _brandGreen, borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Text('${context.pageNumber}', style: pw.TextStyle(font: sansBold, fontSize: 9, color: PdfColors.white)),
              ),
              pw.Text(' —', style: pageNumberStyle),
            ],
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (var hymnIndex = 0; hymnIndex < hymns.length; hymnIndex++) {
            final hymn = hymns[hymnIndex];

            if (hymnIndex > 0) {
              if (startEachHymnOnNewPage) {
                widgets.add(pw.NewPage());
              } else {
                widgets.add(pw.SizedBox(height: 40));
              }
            }

            final stanzas = _parseStanzas(hymn.lyrics);
            final totalLines = stanzas.fold<int>(0, (sum, s) => sum + s.lines.length);

            if (hymns.length == 1) {
              if (totalLines <= 24) {
                widgets.add(pw.Container(
                  height: 640,
                  alignment: pw.Alignment.center,
                  child: _buildHymnBlock(hymn, stanzas, hymnTitleStyle: hymnTitleStyle, creditStyle: creditStyle, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle),
                ));
              } else if (totalLines <= 75) {
                final (left, right) = _splitStanzas(stanzas, totalLines);
                widgets.add(pw.Container(
                  height: 640,
                  alignment: pw.Alignment.center,
                  child: _buildHymnBlockTwoCols(hymn, left, right, hymnTitleStyle: hymnTitleStyle, creditStyle: creditStyle, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle),
                ));
              } else {
                widgets.add(_buildHymnBlock(hymn, stanzas, hymnTitleStyle: hymnTitleStyle, creditStyle: creditStyle, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle));
              }
            } else {
              widgets.add(_buildHymnBlock(hymn, stanzas, hymnTitleStyle: hymnTitleStyle, creditStyle: creditStyle, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle));
            }
          }
          return widgets;
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    await directory.create(recursive: true);
    final safeFileName = _safeFileName(fileName);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${safeFileName}_$stamp.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static (List<_StanzaData>, List<_StanzaData>) _splitStanzas(List<_StanzaData> stanzas, int totalLines) {
    final left = <_StanzaData>[];
    final right = <_StanzaData>[];
    var leftLines = 0;
    final mid = totalLines / 2;

    for (final s in stanzas) {
      if (leftLines < mid) {
        left.add(s);
        leftLines += s.lines.length;
      } else {
        right.add(s);
      }
    }
    return (left, right);
  }

  static pw.Widget _buildHymnBlock(Hymn hymn, List<_StanzaData> stanzas, {required pw.TextStyle hymnTitleStyle, required pw.TextStyle creditStyle, required pw.TextStyle numberStyle, required pw.TextStyle bodyStyle, required pw.TextStyle sectionLabelStyle, required pw.TextStyle repeatStyle}) {
    final children = <pw.Widget>[];

    children.add(pw.Center(child: pw.Text(_pdfCompatibleText('${hymn.number}. ${hymn.title}'), textAlign: pw.TextAlign.center, style: hymnTitleStyle)));
    children.add(pw.SizedBox(height: 10));
    children.add(pw.Center(child: pw.Container(width: 60, height: 2, color: _brandGold)));

    final credits = <String>[];
    if ((hymn.auteur ?? '').trim().isNotEmpty) credits.add(_clip(hymn.auteur, 60));
    if ((hymn.compositeur ?? '').trim().isNotEmpty && (hymn.compositeur ?? '') != (hymn.auteur ?? '')) credits.add('Musique : ${_clip(hymn.compositeur, 50)}');
    if ((hymn.annee ?? '').trim().isNotEmpty) credits.add(_clip(hymn.annee, 30));
    if (credits.isNotEmpty) {
      children.add(pw.SizedBox(height: 8));
      children.add(pw.Center(child: pw.Text(_pdfCompatibleText(credits.join('  ·  ')), textAlign: pw.TextAlign.center, style: creditStyle)));
    }

    if ((hymn.referenceBiblique ?? '').trim().isNotEmpty) {
      children.add(pw.SizedBox(height: 6));
      children.add(pw.Center(child: pw.Text(_pdfCompatibleText(hymn.referenceBiblique!.trim()), textAlign: pw.TextAlign.center, style: pw.TextStyle(font: pw.Font.timesItalic(), fontSize: 9.5, color: _midGrey))));
    }

    children.add(pw.SizedBox(height: 24));

    if (stanzas.isEmpty) {
      children.add(pw.Text('Aucune parole disponible.', style: bodyStyle));
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children);
    }

    for (var i = 0; i < stanzas.length; i++) {
      children.add(_buildStanza(stanzas[i], numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle));
      if (i < stanzas.length - 1) children.add(pw.SizedBox(height: 12));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children);
  }

  static pw.Widget _buildHymnBlockTwoCols(Hymn hymn, List<_StanzaData> left, List<_StanzaData> right, {required pw.TextStyle hymnTitleStyle, required pw.TextStyle creditStyle, required pw.TextStyle numberStyle, required pw.TextStyle bodyStyle, required pw.TextStyle sectionLabelStyle, required pw.TextStyle repeatStyle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(child: pw.Text(_pdfCompatibleText('${hymn.number}. ${hymn.title}'), textAlign: pw.TextAlign.center, style: hymnTitleStyle)),
        pw.SizedBox(height: 10),
        pw.Center(child: pw.Container(width: 60, height: 2, color: _brandGold)),
        pw.SizedBox(height: 8),
        if ((hymn.auteur ?? '').trim().isNotEmpty || (hymn.annee ?? '').trim().isNotEmpty)
          pw.Center(
            child: pw.Text(
              _pdfCompatibleText([
                if ((hymn.auteur ?? '').trim().isNotEmpty) _clip(hymn.auteur, 60),
                if ((hymn.annee ?? '').trim().isNotEmpty) _clip(hymn.annee, 30),
              ].join('  ·  ')),
              textAlign: pw.TextAlign.center,
              style: creditStyle,
            ),
          ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: left.map((s) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: _buildStanza(s, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle))).toList(),
              ),
            ),
            pw.SizedBox(width: 40),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: right.map((s) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: _buildStanza(s, numberStyle: numberStyle, bodyStyle: bodyStyle, sectionLabelStyle: sectionLabelStyle, repeatStyle: repeatStyle))).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildStanza(_StanzaData stanza, {required pw.TextStyle numberStyle, required pw.TextStyle bodyStyle, required pw.TextStyle sectionLabelStyle, required pw.TextStyle repeatStyle}) {
    final children = <pw.Widget>[];

    if (stanza.sectionLabel != null) {
      children.add(pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(stanza.sectionLabel!.toUpperCase(), style: sectionLabelStyle)));
    }

    final textStyle = stanza.isRefrain ? pw.TextStyle(font: pw.Font.timesItalic(), fontSize: 12, color: _darkText, lineSpacing: 4) : bodyStyle;

    if (stanza.number != null && stanza.lines.isNotEmpty) {
      children.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 22, child: pw.Text('${stanza.number}.', style: numberStyle)),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stanza.lines.length; i++)
                  pw.Padding(
                    padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 3),
                    child: pw.Text(_pdfCompatibleText(stanza.lines[i]), style: textStyle),
                  ),
              ],
            ),
          ),
        ],
      ));
    } else {
      for (final line in stanza.lines) {
        children.add(pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(_pdfCompatibleText(line), style: textStyle)));
      }
    }

    if (stanza.repeatCount > 0) {
      final label = stanza.repeatCount == 2 ? '(bis)' : (stanza.repeatCount == 3 ? '(ter)' : '(×${stanza.repeatCount})');
      children.add(pw.Padding(padding: pw.EdgeInsets.only(top: 4, left: stanza.number != null ? 22 : 0), child: pw.Text(label, style: repeatStyle)));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
  }

  static List<_StanzaData> _parseStanzas(String lyrics) {
    final normalized = lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');

    final stanzas = <_StanzaData>[];
    String? currentNumber;
    String? currentSection;
    var currentLines = <String>[];
    var currentRepeat = 0;
    var isRefrain = false;

    void flush() {
      if (currentSection == null && currentLines.isEmpty && currentRepeat == 0) return;
      stanzas.add(_StanzaData(number: currentNumber, sectionLabel: currentSection, lines: List<String>.from(currentLines), repeatCount: currentRepeat, isRefrain: isRefrain));
      currentNumber = null;
      currentSection = null;
      currentLines = <String>[];
      currentRepeat = 0;
      isRefrain = false;
    }

    final numberRe = RegExp(r'^(\d+)\.\s+(.*)$');
    final repeatRe = RegExp(r'^\*+\s*\{\s*(\d+)\s*\}$');
    final sectionRe = RegExp(r'^(Refrain|Couplet|Pont|Chœur|Chorus)\s*:?\s*$', caseSensitive: false);

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) { flush(); continue; }

      final repeatMatch = repeatRe.firstMatch(trimmed);
      if (repeatMatch != null) {
        currentRepeat = int.tryParse(repeatMatch.group(1) ?? '2') ?? 2;
        continue;
      }

      final numMatch = numberRe.firstMatch(trimmed);
      if (numMatch != null) {
        flush();
        currentNumber = numMatch.group(1)!;
        final content = (numMatch.group(2) ?? '').trim();
        if (content.isNotEmpty) currentLines.add(_cleanInlineMarkers(content));
        continue;
      }

      if (sectionRe.hasMatch(trimmed)) {
        flush();
        final section = trimmed.replaceAll(':', '').trim();
        currentSection = section;
        isRefrain = section.toLowerCase().startsWith('refrain');
        continue;
      }

      final cleaned = _cleanInlineMarkers(trimmed.replaceFirst(RegExp(r'^\*\s*'), ''));
      if (cleaned.isNotEmpty) currentLines.add(cleaned);
    }
    flush();

    return stanzas;
  }

  static String _cleanInlineMarkers(String text) {
    var s = text;
    s = s.replaceAll(RegExp(r'\*\*\s*\{\s*2\s*\}'), '');
    s = s.replaceAll(RegExp(r'\*\*\s*\{\s*3\s*\}'), '');
    s = s.replaceAllMapped(RegExp(r'\*\*\s*\{\s*(\d+)\s*\}'), (m) => '');
    s = s.replaceAll(RegExp(r'\*\s*\{\s*2\s*\}'), '');
    s = s.replaceAll(RegExp(r'\*\s*\{\s*3\s*\}'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  static String _formatDate(DateTime date) {
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _clip(String? value, int maxChars) {
    if (value == null) return '';
    final t = value.trim();
    if (t.isEmpty) return '';
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 3).trimRight()}...';
  }

  static String _pdfCompatibleText(String value) {
    final normalized = value
        .replaceAll('\u0153', 'oe') // Fixes the Cœur (œ) box bug!
        .replaceAll('\u0152', 'OE')
        .replaceAll('\u2011', '-')
        .replaceAll('\u202f', ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201A', "'")
        .replaceAll('\u201B', "'")
        .replaceAll('\u2032', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u201E', '"')
        .replaceAll('\u2033', '"')
        .replaceAll('\t', '    ');

    const winAnsiExtra = <int>{
      0x20AC, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6,
      0x2030, 0x0160, 0x2039, 0x0152, 0x017D, 0x2018, 0x2019, 0x201C,
      0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A,
      0x0153, 0x017E, 0x0178,
    };

    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      if (rune == 0x0A || rune == 0x0D) {
        buffer.writeCharCode(rune);
      } else if (rune >= 0x20 && rune <= 0x7E) {
        buffer.writeCharCode(rune);
      } else if ((rune >= 0xA0 && rune <= 0xFF) || winAnsiExtra.contains(rune)) {
        buffer.writeCharCode(rune);
      } else if (rune < 0x20) {
        // skip
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  static String _safeFileName(String value) {
    var name = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^\.+|\.+$'), '').trim();
    if (name.isEmpty) name = 'Chant';
    if (name.length > 80) name = name.substring(0, 80);
    return name;
  }
}

class _StanzaData {
  final String? number;
  final String? sectionLabel;
  final List<String> lines;
  final int repeatCount;
  final bool isRefrain;

  _StanzaData({this.number, this.sectionLabel, required this.lines, this.repeatCount = 0, this.isRefrain = false});
}


// ======================== MODEL ========================
class Hymn {
  final String number;
  final String title;
  final String lyrics;
  final bool isCustom;
  final String? auteur;
  final String? annee;
  final String? histoire;
  final String? compositeur;
  final String? traducteur;
  final String? source;
  final String? referenceBiblique;
  final String? themes;
  final String? metadataReviewNote;

  const Hymn({
    required this.number,
    required this.title,
    required this.lyrics,
    this.isCustom = false,
    this.auteur,
    this.annee,
    this.histoire,
    this.compositeur,
    this.traducteur,
    this.source,
    this.referenceBiblique,
    this.themes,
    this.metadataReviewNote,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'number': number,
        'title': title,
        'lyrics': lyrics,
        'isCustom': isCustom,
        'auteur': auteur,
        'annee': annee,
        'histoire': histoire,
        'compositeur': compositeur,
        'traducteur': traducteur,
        'source': source,
        'referenceBiblique': referenceBiblique,
        'themes': themes,
        if (metadataReviewNote != null) 'metadataReviewNote': metadataReviewNote,
      };

  factory Hymn.fromJson(Map<String, dynamic> json) {
    final numberRaw = json['number'];
    final title = json['title'];
    final lyrics = json['lyrics'];
    if (numberRaw == null || numberRaw.toString().trim().isEmpty) {
      throw const FormatException('Un cantique ne contient pas de numéro.');
    }
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Un cantique ne contient pas de titre valide.');
    }
    if (lyrics is! String || lyrics.trim().isEmpty) {
      throw FormatException('Le cantique "$title" ne contient pas de paroles.');
    }

    String? optionalString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    final isCustomRaw = json['isCustom'];
    if (isCustomRaw != null && isCustomRaw is! bool) {
      throw FormatException(
          'Le champ isCustom de "$title" doit être vrai ou faux.');
    }

    return Hymn(
      number: numberRaw.toString(),
      title: title,
      lyrics: lyrics,
      isCustom: isCustomRaw == true,
      auteur: optionalString('auteur'),
      annee: optionalString('annee'),
      histoire: optionalString('histoire'),
      compositeur: optionalString('compositeur'),
      traducteur: optionalString('traducteur'),
      source: optionalString('source'),
      referenceBiblique: optionalString('referenceBiblique'),
      themes: optionalString('themes'),
      metadataReviewNote: optionalString('metadataReviewNote'),
    );
  }
}

// ======================== DATA LOADING ========================
final List<Hymn> allHymns = <Hymn>[];
final Map<String, _HymnSearchIndex> _searchIndex =
    <String, _HymnSearchIndex>{};
bool _hymnsLoaded = false;

void _rebuildSearchIndex() {
  _searchIndex.clear();
  for (final h in allHymns) {
    _searchIndex[h.number] = _HymnSearchIndex(h);
  }
}

Future<void> loadHymnsFromAssets() async {
  if (_hymnsLoaded && allHymns.isNotEmpty) {
    if (_searchIndex.isEmpty) _rebuildSearchIndex();
    return;
  }

  const assetPath = 'assets/data/chants_de_victoire_hymns.json';
  final String rawJson;
  try {
    rawJson = await rootBundle.loadString(assetPath);
  } catch (error) {
    throw FormatException('Impossible de lire $assetPath : $error');
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(rawJson);
  } on FormatException catch (error) {
    throw FormatException('Le catalogue JSON est invalide : $error');
  }
  if (decoded is! List) {
    throw const FormatException(
        'Le catalogue JSON doit être une liste de cantique.');
  }

  final loaded = <Hymn>[];
  final seenNumbers = <String>{};
  for (var i = 0; i < decoded.length; i++) {
    final item = decoded[i];
    if (item is! Map) {
      throw FormatException(
          'L’entrée ${i + 1} du catalogue n’est pas un objet JSON.');
    }
    final hymn = Hymn.fromJson(Map<String, dynamic>.from(item));
    if (!seenNumbers.add(hymn.number)) {
      throw FormatException(
          'Le numéro de cantique "${hymn.number}" apparaît plusieurs fois.');
    }
    loaded.add(hymn);
  }
  if (loaded.isEmpty) {
    throw const FormatException('Le catalogue JSON ne contient aucun cantique.');
  }

  allHymns
    ..clear()
    ..addAll(loaded);
  _rebuildSearchIndex();
  _hymnsLoaded = true;
}

// ======================== SPLASH SCREEN ========================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _loadAndGo();
  }

  Future<void> _loadAndGo() async {
    try {
      await loadHymnsFromAssets();
      await SharedPreferences.getInstance();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Impossible de charger les cantiques')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Le catalogue JSON n\'a pas pu être chargé. Vérifiez :'),
                const SizedBox(height: 10),
                const Text(
                    '• Fichier présent :\n  assets/data/chants_de_victoire_hymns.json'),
                const Text('• Déclaré dans pubspec.yaml (rubrique assets)'),
                const Text('• uses-material-design: true'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    'Détail :\n$error',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _loadAndGo();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = AppTheme.responsiveFontSize(context, 28);
    final badgeSize = screenWidth * 0.34;

    return Scaffold(
      backgroundColor: AppTheme.splashRed,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.library_music_rounded,
                      size: badgeSize * 0.55,
                      color: AppTheme.splashRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Chants de Victoire\nComplete",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Digital Hymns. Spiritual Focus.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: fontSize * 0.55,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================== HOME ========================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  double _fontSize = 20;
  double _scrollSpeed = 20;
  Set<String> _favorites = <String>{};
  List<Hymn> _customSongs = <Hymn>[];

  late List<Widget> _screens;
  final Set<int> _visitedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _screens = _buildScreens();
  }

  List<Widget> _buildScreens() {
    return [
      HymnListScreen(
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
      ),
      FavoritesListScreen(
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
      ),
      PlaylistsScreen(
        customSongs: _customSongs,
        onSaveSong: _saveCustomSong,
        onUpdateSong: _updateCustomSong,
        onDeleteSong: _deleteCustomSong,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
      ),
      const LearnScreen(),
      MoreScreen(
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
        onFontSizeChanged: _updateFontSize,
        onScrollSpeedChanged: _updateScrollSpeed,
      ),
    ];
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCustomJson = prefs.getString('customSongs');
    final restoredSongs = <Hymn>[];
    if (rawCustomJson != null && rawCustomJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCustomJson);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map) {
              try {
                restoredSongs
                    .add(Hymn.fromJson(Map<String, dynamic>.from(entry)));
              } catch (error) {
                debugPrint('Custom song skipped: $error');
              }
            }
          }
        }
      } catch (error) {
        debugPrint('Saved custom songs could not be decoded: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 20;
      _scrollSpeed = prefs.getDouble('scrollSpeed') ?? 20;
      _favorites = prefs.getStringList('favorites')?.toSet() ?? <String>{};
      _customSongs = restoredSongs;
      _screens = _buildScreens();
    });
  }

  Future<void> _toggleFavorite(String hymnNumber) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(hymnNumber)) {
        _favorites.remove(hymnNumber);
      } else {
        _favorites.add(hymnNumber);
      }
      _rebuildFavoriteDependentScreens();
    });
    await prefs.setStringList('favorites', _favorites.toList());
  }

  void _rebuildFavoriteDependentScreens() {
    final updated = List<Widget>.from(_screens);
    if (updated.isNotEmpty) {
      updated[0] = HymnListScreen(
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
      );
    }
    if (updated.length > 1) {
      updated[1] = FavoritesListScreen(
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
        fontSize: _fontSize,
        scrollSpeed: _scrollSpeed,
      );
    }
    _screens = updated;
  }

  Future<void> _updateFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    setState(() {
      _fontSize = size;
      _screens = _buildScreens();
    });
  }

  Future<void> _updateScrollSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scrollSpeed', speed);
    setState(() {
      _scrollSpeed = speed;
      _screens = _buildScreens();
    });
  }

  Future<void> _saveCustomSong(Hymn song) async {
    final updated = <Hymn>[..._customSongs, song];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customSongs',
      jsonEncode(updated.map((entry) => entry.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _customSongs = updated;
      _screens = _buildScreens();
    });
  }

  Future<void> _updateCustomSong(int index, Hymn song) async {
    if (index < 0 || index >= _customSongs.length) {
      throw RangeError.index(index, _customSongs, 'index');
    }
    final updated = List<Hymn>.from(_customSongs);
    updated[index] = song;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customSongs',
      jsonEncode(updated.map((entry) => entry.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _customSongs = updated;
      _screens = _buildScreens();
    });
  }

  Future<void> _deleteCustomSong(int index) async {
    if (index < 0 || index >= _customSongs.length) {
      throw RangeError.index(index, _customSongs, 'index');
    }
    final updated = List<Hymn>.from(_customSongs)..removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customSongs',
      jsonEncode(updated.map((entry) => entry.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _customSongs = updated;
      _screens = _buildScreens();
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(_screens.length, (i) {
      if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
      return _screens[i];
    });
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: children,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          _visitedTabs.add(index);
        }),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.cardBackground,
        selectedItemColor: AppTheme.gold,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: "Chants"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "Favoris"),
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_note), label: "Écrire"),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: "Apprendre"),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz), label: "Plus"),
        ],
      ),
    );
  }
}

// ======================== HYMN LIST ========================
class HymnListScreen extends StatefulWidget {
  final Set<String> favorites;
  final Function(String) onToggleFavorite;
  final double fontSize;
  final double scrollSpeed;

  const HymnListScreen({
    super.key,
    required this.favorites,
    required this.onToggleFavorite,
    required this.fontSize,
    required this.scrollSpeed,
  });

  @override
  State<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends State<HymnListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<Hymn> _filtered = <Hymn>[];

  @override
  void initState() {
    super.initState();
    if (_searchIndex.isEmpty && allHymns.isNotEmpty) {
      _rebuildSearchIndex();
    }
    _filtered = allHymns;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    if (q == _query) return;
    setState(() {
      _query = q;
      _filtered = _computeFiltered(q);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filtered = allHymns;
    });
  }

  List<Hymn> _computeFiltered(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return allHymns;
    final q = _foldForSearch(trimmed);
    if (q.isEmpty) return allHymns;

    if (_searchIndex.isEmpty && allHymns.isNotEmpty) {
      _rebuildSearchIndex();
    }

    final scored = <MapEntry<Hymn, int>>[];
    for (final h in allHymns) {
      final idx = _searchIndex[h.number];
      if (idx == null) continue;
      final score = _scoreMatch(idx, q);
      if (score > 0) scored.add(MapEntry(h, score));
    }

    if (scored.isEmpty) return const <Hymn>[];

    scored.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      if (cmp != 0) return cmp;
      return _compareHymnNumber(a.key.number, b.key.number);
    });

    return scored.map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final padding = AppTheme.responsivePadding(context);
    final rowFontSize = widget.fontSize.clamp(14.0, 22.0);

    return Column(
      children: [
        SizedBox(height: topPadding + 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "Rechercher un cantique…",
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFF1A1D24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: padding),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.trim().isEmpty
                              ? 'Aucun cantique chargé'
                              : 'Aucun résultat pour « $_query »',
                          style: const TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final hymn = _filtered[i];
                    final isFav = widget.favorites.contains(hymn.number);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "${hymn.number}. ${hymn.title}",
                        style: TextStyle(fontSize: rowFontSize),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () =>
                            widget.onToggleFavorite(hymn.number),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HymnReaderScreen(
                              hymn: hymn,
                              isFavorite: isFav,
                              onToggleFavorite: () =>
                                  widget.onToggleFavorite(hymn.number),
                              fontSize: widget.fontSize,
                              scrollSpeed: widget.scrollSpeed,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ======================== FAVORITES ========================
class FavoritesListScreen extends StatelessWidget {
  final Set<String> favorites;
  final Function(String) onToggleFavorite;
  final double fontSize;
  final double scrollSpeed;

  const FavoritesListScreen({
    super.key,
    required this.favorites,
    required this.onToggleFavorite,
    required this.fontSize,
    required this.scrollSpeed,
  });

  Future<void> _exportFavoritesPdf(
      BuildContext context, List<Hymn> hymns) async {
    if (hymns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun cantique favori à exporter.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final file = await PdfGenerator.generateFavoritesPdf(hymns);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Mes favoris — Chants de Victoire (PDF)');
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export des favoris impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final padding = AppTheme.responsivePadding(context);
    final favHymns =
        allHymns.where((h) => favorites.contains(h.number)).toList();

    return Column(
      children: [
        SizedBox(height: topPadding + 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            children: [
              const Expanded(
                child: Text('Mes favoris',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Exporter les favoris en PDF',
                onPressed: favHymns.isEmpty
                    ? null
                    : () => _exportFavoritesPdf(context, favHymns),
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppTheme.gold),
              ),
            ],
          ),
        ),
        if (favHymns.isEmpty)
          const Expanded(
            child: Center(
              child: Text("Aucun favori pour l'instant",
                  style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: padding),
              itemCount: favHymns.length,
              itemBuilder: (_, i) {
                final hymn = favHymns[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${hymn.number}. ${hymn.title}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () => onToggleFavorite(hymn.number),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HymnReaderScreen(
                          hymn: hymn,
                          isFavorite: true,
                          onToggleFavorite: () =>
                              onToggleFavorite(hymn.number),
                          fontSize: fontSize,
                          scrollSpeed: scrollSpeed,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

// ======================== WRITE / PLAYLISTS ========================
class PlaylistsScreen extends StatefulWidget {
  final List<Hymn> customSongs;
  final Future<void> Function(Hymn) onSaveSong;
  final Future<void> Function(int, Hymn) onUpdateSong;
  final Future<void> Function(int) onDeleteSong;
  final double fontSize;
  final double scrollSpeed;

  const PlaylistsScreen({
    super.key,
    required this.customSongs,
    required this.onSaveSong,
    required this.onUpdateSong,
    required this.onDeleteSong,
    required this.fontSize,
    required this.scrollSpeed,
  });

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  static const String _draftKey = 'chantWriterDraftV2';
  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _authorController = TextEditingController();
  final _yearController = TextEditingController();
  final _composerController = TextEditingController();
  final _translatorController = TextEditingController();
  final _sourceController = TextEditingController();
  final _historyController = TextEditingController();
  final _referenceController = TextEditingController();
  final _themesController = TextEditingController();
  final _searchController = TextEditingController();
  final _pageScrollController = ScrollController();

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _lyricsFocus = FocusNode();

  String _searchQuery = '';
  int? _editingIndex;
  Timer? _draftTimer;
  bool _hasRestoredDraft = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _metadataExpanded = false;
  DateTime? _lastDraftSavedAt;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void didUpdateWidget(covariant PlaylistsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editingIndex != null &&
        _editingIndex! >= widget.customSongs.length) {
      _editingIndex = null;
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _titleFocus.dispose();
    _lyricsFocus.dispose();
    _titleController.dispose();
    _lyricsController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _composerController.dispose();
    _translatorController.dispose();
    _sourceController.dispose();
    _historyController.dispose();
    _referenceController.dispose();
    _themesController.dispose();
    _searchController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  List<Hymn> get _filteredSongs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.customSongs;
    final folded = _foldForSearch(query);
    return widget.customSongs.where((song) {
      return _foldForSearch(song.title).contains(folded) ||
          _foldForSearch(song.lyrics).contains(folded) ||
          _foldForSearch(song.number).contains(folded) ||
          _foldForSearch(song.auteur ?? '').contains(folded) ||
          _foldForSearch(song.themes ?? '').contains(folded);
    }).toList();
  }

  int get _wordCount {
    final text = _lyricsController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (!mounted || raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      if (_hasUnsavedChanges) return;
      void restore(TextEditingController controller, String key) {
        final value = decoded[key];
        if (value is String) controller.text = value;
      }

      restore(_titleController, 'title');
      restore(_lyricsController, 'lyrics');
      restore(_authorController, 'auteur');
      restore(_yearController, 'annee');
      restore(_composerController, 'compositeur');
      restore(_translatorController, 'traducteur');
      restore(_sourceController, 'source');
      restore(_historyController, 'histoire');
      restore(_referenceController, 'referenceBiblique');
      restore(_themesController, 'themes');
      _hasRestoredDraft = true;
      if (_titleController.text.isNotEmpty ||
          _lyricsController.text.isNotEmpty) {
        if (mounted) setState(() {});
      }
    } catch (error) {
      debugPrint('Writer draft could not be restored: $error');
    }
  }

  void _onEditorChanged() {
    _hasUnsavedChanges = true;
    setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), _saveDraftQuietly);
  }

  Future<void> _saveDraftQuietly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(<String, String>{
        'title': _titleController.text,
        'lyrics': _lyricsController.text,
        'auteur': _authorController.text,
        'annee': _yearController.text,
        'compositeur': _composerController.text,
        'traducteur': _translatorController.text,
        'source': _sourceController.text,
        'histoire': _historyController.text,
        'referenceBiblique': _referenceController.text,
        'themes': _themesController.text,
      }));
      if (mounted) setState(() => _lastDraftSavedAt = DateTime.now());
    } catch (error) {
      debugPrint('Writer draft could not be saved: $error');
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (error) {
      debugPrint('Writer draft could not be cleared: $error');
    }
    _hasRestoredDraft = false;
    _hasUnsavedChanges = false;
    _lastDraftSavedAt = null;
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String _nextCustomNumber() {
    var maxNumber = 0;
    for (final song in widget.customSongs) {
      final parsed = int.tryParse(song.number);
      if (parsed != null && parsed > maxNumber) maxNumber = parsed;
    }
    return (maxNumber + 1).toString();
  }

  Future<void> _saveSong() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final lyrics = _lyricsController.text.trim();

    if (title.isEmpty) {
      _showSnack('Veuillez saisir un titre.', isError: true);
      _titleFocus.requestFocus();
      return;
    }
    if (lyrics.isEmpty) {
      _showSnack('Veuillez saisir les paroles.', isError: true);
      _lyricsFocus.requestFocus();
      return;
    }

    final editIndex = _editingIndex;
    if (editIndex != null &&
        (editIndex < 0 || editIndex >= widget.customSongs.length)) {
      setState(() => _editingIndex = null);
      _showSnack('Ce chant n\'existe plus. Enregistrez-le comme nouveau.',
          isError: true);
      return;
    }

    final song = Hymn(
      number: editIndex == null
          ? _nextCustomNumber()
          : widget.customSongs[editIndex].number,
      title: title,
      lyrics: lyrics.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      isCustom: true,
      auteur: _optional(_authorController),
      annee: _optional(_yearController),
      compositeur: _optional(_composerController),
      traducteur: _optional(_translatorController),
      source: _optional(_sourceController),
      histoire: _optional(_historyController),
      referenceBiblique: _optional(_referenceController),
      themes: _optional(_themesController),
    );

    setState(() => _isSaving = true);
    try {
      if (editIndex == null) {
        await widget.onSaveSong(song);
      } else {
        await widget.onUpdateSong(editIndex, song);
      }
      if (!mounted) return;
      await _clearDraft();
      _resetEditor(clearFields: true, clearDraftState: false);
      _showSnack(editIndex == null
          ? '✓ Chant enregistré.'
          : '✓ Modifications enregistrées.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Enregistrement impossible : $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleReset() async {
    final hasContent = _titleController.text.isNotEmpty ||
        _lyricsController.text.isNotEmpty ||
        _authorController.text.isNotEmpty ||
        _historyController.text.isNotEmpty;

    if (hasContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Abandonner le brouillon ?'),
          content:
              const Text('Les modifications non enregistrées seront perdues.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abandonner'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _clearDraft();
    _resetEditor(clearDraftState: false);
  }

  void _resetEditor({bool clearFields = true, bool clearDraftState = true}) {
    if (clearFields) {
      for (final controller in <TextEditingController>[
        _titleController,
        _lyricsController,
        _authorController,
        _yearController,
        _composerController,
        _translatorController,
        _sourceController,
        _historyController,
        _referenceController,
        _themesController,
      ]) {
        controller.clear();
      }
    }
    setState(() {
      _editingIndex = null;
      if (clearDraftState) {
        _hasUnsavedChanges = false;
        _hasRestoredDraft = false;
        _lastDraftSavedAt = null;
      }
    });
    if (clearDraftState) {
      _clearDraft();
    }
  }

  void _beginEdit(Hymn song) {
    final index = widget.customSongs.indexOf(song);
    if (index < 0) return;
    _draftTimer?.cancel();
    setState(() {
      _editingIndex = index;
      _hasUnsavedChanges = false;
      _hasRestoredDraft = false;
      _lastDraftSavedAt = null;
      _metadataExpanded = true;
      _titleController.text = song.title;
      _lyricsController.text = song.lyrics;
      _authorController.text = song.auteur ?? '';
      _yearController.text = song.annee ?? '';
      _composerController.text = song.compositeur ?? '';
      _translatorController.text = song.traducteur ?? '';
      _sourceController.text = song.source ?? '';
      _historyController.text = song.histoire ?? '';
      _referenceController.text = song.referenceBiblique ?? '';
      _themesController.text = song.themes ?? '';
    });
    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  void _insertAtCursor(String insertion) {
    final value = _lyricsController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final updated = value.text.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    _lyricsController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _lyricsFocus.requestFocus();
    _onEditorChanged();
  }

  void _showPreview() {
    final title = _titleController.text.trim().isEmpty
        ? 'Aperçu du cantique'
        : _titleController.text.trim();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _lyricsController.text.isEmpty
                  ? 'Les paroles apparaîtront ici.'
                  : _lyricsController.text,
              style: TextStyle(fontSize: widget.fontSize, height: 1.55),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _plainText(Hymn song) {
    final parts = <String>['${song.number}. ${song.title}', '', song.lyrics];
    if ((song.auteur ?? '').trim().isNotEmpty) {
      parts.add('\nAuteur : ${song.auteur}');
    }
    if ((song.compositeur ?? '').trim().isNotEmpty) {
      parts.add('Compositeur : ${song.compositeur}');
    }
    if ((song.traducteur ?? '').trim().isNotEmpty) {
      parts.add('Traducteur / adaptateur : ${song.traducteur}');
    }
    if ((song.annee ?? '').trim().isNotEmpty) {
      parts.add('Année : ${song.annee}');
    }
    if ((song.source ?? '').trim().isNotEmpty) {
      parts.add('Source : ${song.source}');
    }
    if ((song.referenceBiblique ?? '').trim().isNotEmpty) {
      parts.add('Référence biblique : ${song.referenceBiblique}');
    }
    if ((song.themes ?? '').trim().isNotEmpty) {
      parts.add('Thèmes : ${song.themes}');
    }
    if ((song.histoire ?? '').trim().isNotEmpty) {
      parts.add('\nHistoire : ${song.histoire}');
    }
    if ((song.metadataReviewNote ?? '').trim().isNotEmpty) {
      parts.add('\nNote de vérification : ${song.metadataReviewNote}');
    }
    return parts.join('\n');
  }

  Future<void> _exportSong(Hymn song, {required bool asPdf}) async {
    try {
      if (!asPdf) {
        await Share.share(_plainText(song),
            subject: '${song.title} — Chants de Victoire');
        return;
      }
      final file = await PdfGenerator.generateHymnPdf(song);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)],
          subject: '${song.title} — PDF');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Export impossible : $error', isError: true);
    }
  }

  Future<void> _exportAllSongs() async {
    if (widget.customSongs.isEmpty) {
      _showSnack('Aucun chant personnel à exporter.', isError: true);
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final file = await PdfGenerator.generateSongsPdf(widget.customSongs);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Share.shareXFiles([XFile(file.path)], subject: 'Mes chants — PDF');
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showSnack('Export PDF impossible : $error', isError: true);
    }
  }

  Future<bool> _askDeleteConfirmation(Hymn song) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce chant ?'),
        content:
            Text('« ${song.title} » sera supprimé de vos chants personnels.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _deleteSongNow(Hymn song) async {
    final index = widget.customSongs.indexOf(song);
    if (index < 0) return;
    try {
      await widget.onDeleteSong(index);
      if (!mounted) return;
      if (_editingIndex == index) {
        await _clearDraft();
        _resetEditor(clearDraftState: false);
      }
      _showSnack('Chant supprimé.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Suppression impossible : $error', isError: true);
    }
  }

  Future<void> _confirmDelete(Hymn song) async {
    final approved = await _askDeleteConfirmation(song);
    if (!approved || !mounted) return;
    await _deleteSongNow(song);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int minLines = 1,
    int? maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool multiline = false,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          multiline ? TextInputAction.newline : TextInputAction.next,
      textCapitalization: capitalization,
      onChanged: (_) => _onEditorChanged(),
      style: const TextStyle(height: 1.4),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppTheme.responsivePadding(context);
    final songs = _filteredSongs;
    final editing = _editingIndex != null;

    return SafeArea(
      child: CustomScrollView(
        controller: _pageScrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      color: AppTheme.gold, size: 30),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Écrire un chant',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Composez, organisez et gardez vos paroles.',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Exporter tous mes chants en PDF',
                    onPressed: _exportAllSongs,
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: AppTheme.gold),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 2,
                color: AppTheme.cardBackground,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              editing ? 'Modifier le chant' : 'Nouveau chant',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_hasRestoredDraft && !editing)
                            const Tooltip(
                              message: 'Un brouillon a été restauré',
                              child: Chip(
                                  avatar: Icon(Icons.restore_rounded, size: 16),
                                  label: Text('Brouillon')),
                            ),
                          if (_lastDraftSavedAt != null && _hasUnsavedChanges)
                            const Tooltip(
                              message:
                                  'Le brouillon est sauvegardé sur cet appareil',
                              child: Icon(Icons.cloud_done_rounded,
                                  color: Colors.greenAccent, size: 19),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        label: 'Titre du chant *',
                        hint: 'Donnez un titre clair',
                        icon: Icons.title_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _lyricsController,
                        focusNode: _lyricsFocus,
                        label: 'Paroles *',
                        hint:
                            'Écrivez les couplets en gardant vos sauts de ligne…',
                        icon: Icons.lyrics_rounded,
                        minLines: 8,
                        maxLines: null,
                        multiline: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$_wordCount mots',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('${_lyricsController.text.length} caractères',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showPreview,
                            icon:
                                const Icon(Icons.visibility_outlined, size: 17),
                            label: const Text('Aperçu'),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 4,
                          children: [
                            ActionChip(
                              avatar: const Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 16),
                              label: const Text('Couplet'),
                              onPressed: () => _insertAtCursor(
                                  '\n\nCouplet ${_guessNextVerseNumber()}\n'),
                            ),
                            ActionChip(
                              avatar:
                                  const Icon(Icons.repeat_rounded, size: 16),
                              label: const Text('Refrain'),
                              onPressed: () =>
                                  _insertAtCursor('\n\nRefrain\n'),
                            ),
                            ActionChip(
                              avatar:
                                  const Icon(Icons.alt_route_rounded, size: 16),
                              label: const Text('Pont'),
                              onPressed: () => _insertAtCursor('\n\nPont\n'),
                            ),
                            ActionChip(
                              avatar:
                                  const Icon(Icons.space_bar_rounded, size: 16),
                              label: const Text('Séparer une strophe'),
                              onPressed: () => _insertAtCursor('\n\n'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ExpansionTile(
                        key: ValueKey('meta-$_editingIndex'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding:
                            const EdgeInsets.only(top: 8, bottom: 4),
                        initiallyExpanded: _metadataExpanded,
                        onExpansionChanged: (v) =>
                            setState(() => _metadataExpanded = v),
                        leading: const Icon(Icons.info_outline_rounded,
                            color: AppTheme.gold),
                        title: const Text(
                          'Informations du chant (facultatif)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gold),
                        ),
                        subtitle: const Text(
                          'Auteur, compositeur, source, histoire…',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        children: [
                          _field(
                              controller: _authorController,
                              label: 'Auteur / parolier',
                              icon: Icons.person_outline_rounded),
                          const SizedBox(height: 9),
                          _field(
                              controller: _composerController,
                              label: 'Compositeur / musique',
                              icon: Icons.music_note_rounded),
                          const SizedBox(height: 9),
                          _field(
                              controller: _translatorController,
                              label: 'Traducteur / adaptateur',
                              icon: Icons.translate_rounded),
                          const SizedBox(height: 9),
                          _field(
                              controller: _yearController,
                              label: 'Année',
                              hint: 'Ex. 2026 ou époque estimée',
                              icon: Icons.event_outlined),
                          const SizedBox(height: 9),
                          _field(
                              controller: _sourceController,
                              label: 'Source / recueil',
                              icon: Icons.menu_book_rounded),
                          const SizedBox(height: 9),
                          _field(
                              controller: _referenceController,
                              label: 'Référence biblique',
                              icon: Icons.auto_stories_rounded),
                          const SizedBox(height: 9),
                          _field(
                              controller: _themesController,
                              label: 'Thèmes',
                              hint: 'Louange, consécration…',
                              icon: Icons.sell_outlined),
                          const SizedBox(height: 9),
                          _field(
                            controller: _historyController,
                            label: 'Histoire / notes personnelles',
                            hint:
                                'Contexte, inspiration, verset ou notes de répétition…',
                            icon: Icons.history_edu_rounded,
                            minLines: 3,
                            maxLines: 6,
                            multiline: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : _handleReset,
                              icon: Icon(editing
                                  ? Icons.close_rounded
                                  : Icons.note_add_rounded),
                              label: Text(editing ? 'Annuler' : 'Effacer'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveSong,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : Icon(editing
                                      ? Icons.save_as_rounded
                                      : Icons.save_rounded),
                              label: Text(_isSaving
                                  ? 'Enregistrement…'
                                  : (editing
                                      ? 'Enregistrer les modifications'
                                      : 'Enregistrer le chant')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mes chants',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  Text('${widget.customSongs.length}',
                      style: const TextStyle(
                          color: AppTheme.gold, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText:
                      'Rechercher un titre, des paroles ou un auteur…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppTheme.cardBackground,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (songs.isEmpty)
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.library_music_outlined,
                          size: 38,
                          color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      Text(_searchQuery.isEmpty
                          ? 'Aucun chant enregistré'
                          : 'Aucun résultat'),
                      const SizedBox(height: 5),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Vos chants sauvegardés apparaîtront ici.'
                            : 'Essayez un autre mot-clé.',
                        style: const TextStyle(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    return Dismissible(
                      key: ValueKey('custom-${song.number}-${song.title}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _askDeleteConfirmation(song),
                      onDismissed: (_) => _deleteSongNow(song),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.only(right: 22),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                            const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      child: Card(
                        color: AppTheme.cardBackground,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(14, 7, 6, 7),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen,
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              song.lyrics.replaceAll('\n', ' ').trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white60, height: 1.3),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Actions du chant',
                            onSelected: (action) {
                              if (action == 'edit') _beginEdit(song);
                              if (action == 'txt') {
                                _exportSong(song, asPdf: false);
                              }
                              if (action == 'pdf') {
                                _exportSong(song, asPdf: true);
                              }
                              if (action == 'delete') _confirmDelete(song);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Modifier'),
                                      contentPadding: EdgeInsets.zero)),
                              PopupMenuItem(
                                  value: 'txt',
                                  child: ListTile(
                                      leading: Icon(
                                          Icons.text_snippet_outlined),
                                      title: Text('Partager en texte'),
                                      contentPadding: EdgeInsets.zero)),
                              PopupMenuItem(
                                  value: 'pdf',
                                  child: ListTile(
                                      leading: Icon(
                                          Icons.picture_as_pdf_outlined),
                                      title: Text('Exporter en PDF'),
                                      contentPadding: EdgeInsets.zero)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                      leading: Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                      title: Text('Supprimer'),
                                      contentPadding: EdgeInsets.zero)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HymnReaderScreen(
                                  hymn: song,
                                  isFavorite: false,
                                  onToggleFavorite: () {},
                                  fontSize: widget.fontSize,
                                  scrollSpeed: widget.scrollSpeed,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  childCount: songs.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  int _guessNextVerseNumber() {
    final matches =
        RegExp(r'(?:^|\n)\s*(\d+)\s*[.)]').allMatches(_lyricsController.text);
    var highest = 0;
    for (final match in matches) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > highest) highest = value;
    }
    return highest + 1;
  }
}

// ======================== LEARN SCREEN ========================
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  static const String _learnUrl =
      'https://cantiques.yapper.fr/player/?filter=CV';

  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.darkBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_learnUrl));
  }

  void _retry() {
    if (_controller == null) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _errorMessage = null;
    });
    _controller!.loadRequest(Uri.parse(_learnUrl));
  }

  Future<void> _goBack() async {
    final c = _controller;
    if (c == null) return;
    if (await c.canGoBack()) {
      await c.goBack();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déjà au début de la page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading && !_hasError)
            Container(
              color: AppTheme.darkBackground,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          if (_hasError)
            Container(
              color: AppTheme.darkBackground,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 56, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Impossible de charger la page',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Vérifiez votre connexion Internet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: topPadding + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _goBack,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== MORE ========================
class MoreScreen extends StatefulWidget {
  final double fontSize;
  final double scrollSpeed;
  final Function(double) onFontSizeChanged;
  final Function(double) onScrollSpeedChanged;

  const MoreScreen({
    super.key,
    required this.fontSize,
    required this.scrollSpeed,
    required this.onFontSizeChanged,
    required this.onScrollSpeedChanged,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late double _localFontSize;
  late double _localScrollSpeed;

  @override
  void initState() {
    super.initState();
    _localFontSize = widget.fontSize;
    _localScrollSpeed = widget.scrollSpeed;
  }

  @override
  void didUpdateWidget(covariant MoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      _localFontSize = widget.fontSize;
    }
    if (oldWidget.scrollSpeed != widget.scrollSpeed) {
      _localScrollSpeed = widget.scrollSpeed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
      children: [
        ListTile(
          leading: const Icon(Icons.text_fields, color: Colors.white),
          title: const Text("Taille du texte"),
          subtitle: Slider(
            value: _localFontSize,
            min: 14,
            max: 40,
            activeColor: AppTheme.primaryGreen,
            onChanged: (v) => setState(() => _localFontSize = v),
            onChangeEnd: widget.onFontSizeChanged,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.speed, color: Colors.white),
          title: const Text("Vitesse de défilement"),
          subtitle: Slider(
            value: _localScrollSpeed,
            min: 5,
            max: 50,
            activeColor: AppTheme.primaryGreen,
            onChanged: (v) => setState(() => _localScrollSpeed = v),
            onChangeEnd: widget.onScrollSpeedChanged,
          ),
        ),
        const Divider(color: Colors.white24),
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.white),
          title: const Text("Développeur"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeveloperScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.source, color: Colors.lightBlueAccent),
          title: const Text("Sources"),
          subtitle: const Text("Où j’ai trouvé les données historiques",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SourcesScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.apps, color: Colors.amber),
          title: const Text("Plus d'applications"),
          subtitle: const Text("Artist Notebook – bientôt disponible",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Artist Notebook — bientôt disponible.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.share, color: Colors.cyanAccent),
          title: const Text("Partager l'application"),
          subtitle: const Text("Parlez-en à vos amis",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () {
            const appLink =
                "https://play.google.com/store/search?q=Chants%20de%20Victoire&c=apps";
            Share.share(
              "Écoute et partage les cantiques 🎵\n$appLink",
              subject: "Chants de Victoire – Appli chrétienne",
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.church, color: AppTheme.gold),
          title: const Text(
            "Ministère Jésus-Christ Mon Premier Amour",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            "📍 Akak I, Yaoundé – Cameroun\n👆 Cliquez pour voir sur la carte",
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.map, color: AppTheme.gold),
          onTap: () async {
            final uri = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=3.98333,11.55');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.phone, color: AppTheme.primaryGreen),
          title: const Text(
            "Appeler l'assemblée",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            "📞 +237 677 17 26 14\n👆 Cliquez pour appeler",
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.call, color: AppTheme.primaryGreen),
          onTap: () async {
            final uri = Uri.parse('tel:+237677172614');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip, color: Colors.greenAccent),
          title: const Text("Politique de confidentialité"),
          subtitle: const Text("Vos données sont en sécurité",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () async {
            // Remember to replace this with your actual GitHub Pages URL!
            final uri = Uri.parse(
                'https://raw.githack.com/KellyGlennIT/chant_de_victoire/main/privacy.html');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

// ======================== DEVELOPER ========================
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Développeur")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryGreen,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "Br. Mbuna Kelly Glenn A.",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Founder / Developer",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Text(
              "Creator of Chants de Victoire Modern",
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 20,
              children: [
                _SocialIcon(FontAwesomeIcons.whatsapp,
                    "https://wa.me/qr/2BVUI7FWVMIPD1"),
                _SocialIcon(FontAwesomeIcons.facebook,
                    "https://www.facebook.com/share/1DVPifTtbV/"),
                _SocialIcon(FontAwesomeIcons.tiktok,
                    "https://www.tiktok.com/@kellyglenn237?_r=1&_t=ZS-95vJVDs6y9Y"),
                _SocialIcon(FontAwesomeIcons.instagram, "https://instagram.com"),
                _SocialIcon(FontAwesomeIcons.youtube, "https://youtube.com"),
                _SocialIcon(FontAwesomeIcons.linkedin, "https://linkedin.com"),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.cardBackground),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: AppTheme.primaryGreen),
              title: const Text("XXX XXX XXX"),
              onTap: () => _launch("mailto:XXX XXX XXX"),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: AppTheme.primaryGreen),
              title: const Text("+XXX XXX XXX"),
              onTap: () => _launch("tel:+XXX XXX XXX"),
            ),
            const SizedBox(height: 24),
            const Text(
              '"Built to preserve worship, strengthen spiritual discipline, and modernize sacred hymn access for believers everywhere."',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            Text("Version 1.0.0+1", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final FaIconData icon;
  final String url;

  const _SocialIcon(this.icon, this.url);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: FaIcon(icon, color: Colors.white, size: 28),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
    );
  }
}

String _hymnShareText(Hymn hymn) {
  final parts = <String>['${hymn.number}. ${hymn.title}', '', hymn.lyrics];
  if ((hymn.auteur ?? '').trim().isNotEmpty) {
    parts.add('\nAuteur : ${hymn.auteur}');
  }
  if ((hymn.compositeur ?? '').trim().isNotEmpty) {
    parts.add('Compositeur : ${hymn.compositeur}');
  }
  if ((hymn.traducteur ?? '').trim().isNotEmpty) {
    parts.add('Traducteur / adaptateur : ${hymn.traducteur}');
  }
  if ((hymn.annee ?? '').trim().isNotEmpty) {
    parts.add('Année : ${hymn.annee}');
  }
  if ((hymn.source ?? '').trim().isNotEmpty) {
    parts.add('Source : ${hymn.source}');
  }
  if ((hymn.referenceBiblique ?? '').trim().isNotEmpty) {
    parts.add('Référence biblique : ${hymn.referenceBiblique}');
  }
  if ((hymn.themes ?? '').trim().isNotEmpty) {
    parts.add('Thèmes : ${hymn.themes}');
  }
  if ((hymn.histoire ?? '').trim().isNotEmpty) {
    parts.add('\nHistoire : ${hymn.histoire}');
  }
  if ((hymn.metadataReviewNote ?? '').trim().isNotEmpty) {
    parts.add('\nNote de vérification : ${hymn.metadataReviewNote}');
  }
  return parts.join('\n');
}

// ======================== WORSHIP MODE ========================
class WorshipModeScreen extends StatefulWidget {
  final Hymn hymn;
  final double scrollSpeed;
  final double fontSize;

  const WorshipModeScreen({
    super.key,
    required this.hymn,
    required this.scrollSpeed,
    this.fontSize = 28,
  });

  @override
  State<WorshipModeScreen> createState() => _WorshipModeScreenState();
}

class _WorshipModeScreenState extends State<WorshipModeScreen> {
  final ScrollController _scrollController = ScrollController();
  late double _speed;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _speed = widget.scrollSpeed;
  }

  void _toggleScroll() {
    if (_playing) {
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    _startScroll();
  }

  Future<void> _startScroll() async {
    while (_playing && mounted) {
      if (!_scrollController.hasClients) break;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 0.5) {
        if (mounted) setState(() => _playing = false);
        break;
      }
      final target =
          (pos.pixels + _speed * 0.1).clamp(0.0, pos.maxScrollExtent);
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _playing = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(20, topPadding + 60, 20, 20),
                  children: [
                    Text(
                      widget.hymn.lyrics,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        height: 1.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.white54),
                    Expanded(
                      child: Slider(
                        value: _speed,
                        min: 5,
                        max: 50,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _speed = v),
                      ),
                    ),
                    Text("${_speed.toStringAsFixed(0)} px/s",
                        style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30, top: 10),
                child: ElevatedButton.icon(
                  onPressed: _toggleScroll,
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(_playing ? "Stop Scroll" : "Start Scroll"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: topPadding + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== SOURCES ========================
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sources")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Les informations historiques (auteurs, années, histoires) présentées dans cette application sont issues des sources suivantes :",
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          _SourceTile(
            title: "Chants de Victoire – texte intégral (1915)",
            url:
                "https://archive.org/details/chantsdevictoire00unse/page/n5/mode/2up",
            onTap: _launch,
          ),
          _SourceTile(
            title: "Hymnary.org – base de données hymnologique",
            url: "https://hymnary.org",
            onTap: _launch,
          ),
          _SourceTile(
            title: "Cantiquest – recueil de cantiques",
            url: "https://cantiquest.com",
            onTap: _launch,
          ),
          _SourceTile(
            title: "JEMAF – chant et musique",
            url: "https://jemaf.fr",
            onTap: _launch,
          ),
          _SourceTile(
            title: "Chants et Hymnes Chrétiens – blog",
            url: "https://chantsethymneschretiens.blogspot.com",
            onTap: _launch,
          ),
          const SizedBox(height: 32),
          const Text(
            "Ces ressources ont permis de vérifier et de documenter chaque cantique avec une rigueur historique.",
            style: TextStyle(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String url;
  final void Function(String) onTap;

  const _SourceTile({
    required this.title,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppTheme.cardBackground,
      child: ListTile(
        leading: const Icon(Icons.link, color: AppTheme.primaryGreen),
        title: Text(title),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => onTap(url),
      ),
    );
  }
}
