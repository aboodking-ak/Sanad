import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _PdfTool { none, pen, highlighter, eraser }

class _PdfMark {
  const _PdfMark({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;

  Map<String, Object> toJson() => {
    'points': points.map((point) => [point.dx, point.dy]).toList(),
    'color': color.toARGB32(),
    'width': width,
  };

  factory _PdfMark.fromJson(Map<String, dynamic> json) => _PdfMark(
    points: (json['points'] as List)
        .map(
          (point) => Offset(
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ),
        )
        .toList(growable: false),
    color: Color(json['color'] as int),
    width: (json['width'] as num).toDouble(),
  );
}

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfPath;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfPath,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  static const _penColors = [
    Color(0xFF1A2238),
    Color(0xFF171717),
    Color(0xFF1976D2),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFF7B1FA2),
    Color(0xFFEF6C00),
    Color(0xFFEC407A),
  ];

  bool _isFullScreen = false;
  int _viewerReloadKey = 0;
  late String _resolvedPdfPath;
  bool _pdfSourceReady = true;
  int _downloadedBytes = 0;
  int? _totalDownloadBytes;
  Object? _pdfDownloadError;
  http.Client? _activePdfClient;
  bool _marksLoaded = false;
  bool _viewerReady = false;
  int _lastPage = 1;
  int _pageCount = 0;
  _PdfTool _activeTool = _PdfTool.none;
  Color _penColor = _navy;
  double _penWidth = 4;
  final Map<int, List<_PdfMark>> _marksByPage = {};
  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _pageInputController = TextEditingController();
  Timer? _saveDebounce;
  Timer? _toolPreferenceDebounce;
  int? _activePage;

  String get _documentId {
    var hash = 0xcbf29ce484222325;
    for (final unit in widget.pdfPath.codeUnits) {
      hash = ((hash ^ unit) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String get _pagePreferenceKey => 'last_page_${widget.pdfPath}';
  String get _marksPreferenceKey => 'pdf_marks_$_documentId';

  @override
  void initState() {
    super.initState();
    _resolvedPdfPath = widget.pdfPath;
    if (widget.pdfPath.startsWith('http')) {
      _pdfSourceReady = false;
      _downloadRemotePdf();
    }
    _setSystemBarStyle();
    _loadMarks();
    _loadToolPreferences();
  }

  Future<String> _resolveDownloadUrl() async {
    final uri = Uri.tryParse(widget.pdfPath);
    if (uri == null) throw const FormatException('رابط الكتاب غير صالح.');
    final segments = uri.pathSegments;
    final signIndex = segments.indexOf('sign');
    if (signIndex <= 0 ||
        segments[signIndex - 1] != 'object' ||
        signIndex + 2 >= segments.length) {
      return widget.pdfPath;
    }
    final bucket = segments[signIndex + 1];
    final path = segments.skip(signIndex + 2).join('/');
    return Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(path, 3600);
  }

  Future<void> _downloadRemotePdf({bool forceDownload = false}) async {
    if (!mounted) return;
    setState(() {
      _pdfSourceReady = false;
      _downloadedBytes = 0;
      _totalDownloadBytes = null;
      _pdfDownloadError = null;
    });

    final cacheFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sanad_book_$_documentId.pdf',
    );
    final partialFile = File('${cacheFile.path}.part');
    final client = http.Client();
    _activePdfClient = client;
    IOSink? sink;
    try {
      if (!forceDownload && await cacheFile.exists()) {
        final stat = await cacheFile.stat();
        if (stat.size > 0 &&
            DateTime.now().difference(stat.modified) <
                const Duration(hours: 12)) {
          if (mounted) {
            setState(() {
              _resolvedPdfPath = cacheFile.path;
              _pdfSourceReady = true;
            });
          }
          return;
        }
      }

      final url = await _resolveDownloadUrl();
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('تعذر تنزيل الملف (HTTP ${response.statusCode}).');
      }
      final contentLength = response.contentLength;
      _totalDownloadBytes = contentLength != null && contentLength > 0
          ? contentLength
          : null;
      sink = partialFile.openWrite();
      var lastProgressUpdate = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        sink.add(chunk);
        _downloadedBytes += chunk.length;
        if (_downloadedBytes - lastProgressUpdate >= 256 * 1024 && mounted) {
          lastProgressUpdate = _downloadedBytes;
          setState(() {});
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (!await partialFile.exists() || await partialFile.length() == 0) {
        throw const FormatException('الملف الذي تم تنزيله فارغ.');
      }
      if (await cacheFile.exists()) await cacheFile.delete();
      await partialFile.rename(cacheFile.path);
      if (!mounted) return;
      setState(() {
        _resolvedPdfPath = cacheFile.path;
        _pdfSourceReady = true;
        _viewerReloadKey++;
      });
    } catch (error) {
      debugPrint('فشل تنزيل ملف الكتاب (${widget.pdfPath}): $error');
      if (sink != null) await sink.close();
      if (await partialFile.exists()) await partialFile.delete();
      if (mounted) {
        setState(() {
          _pdfDownloadError = error;
          _pdfSourceReady = false;
        });
      }
    } finally {
      client.close();
      if (identical(_activePdfClient, client)) _activePdfClient = null;
    }
  }

  Future<void> _retryPdfLoad() => _downloadRemotePdf(forceDownload: true);

  Widget _buildRemoteLoadingView() {
    final progress = _totalDownloadBytes == null || _totalDownloadBytes! <= 0
        ? null
        : (_downloadedBytes / _totalDownloadBytes!).clamp(0.0, 1.0);
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: Center(
          child: Container(
            width: 258,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, color: _gold, size: 36),
                const SizedBox(height: 12),
                Text(
                  'جارٍ تحميل ${widget.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE8EAF0),
                    valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                  ),
                ),
                const SizedBox(height: 9),
                if (progress != null)
                  Text(
                    '${(progress * 100).round()}٪',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setSystemBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _navy,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _loadMarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_marksPreferenceKey);
    if (!mounted) return;
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final page = int.tryParse(entry.key);
          if (page == null || entry.value is! List) continue;
          _marksByPage[page] = (entry.value as List)
              .map((mark) => _PdfMark.fromJson(mark as Map<String, dynamic>))
              .toList();
        }
      } catch (error) {
        debugPrint('تعذر تحميل ملاحظات الكتاب: $error');
      }
    }
    setState(() => _marksLoaded = true);
  }

  Future<void> _loadToolPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _penColor = Color(prefs.getInt('pdf_pen_color') ?? _navy.toARGB32());
      _penWidth = (prefs.getDouble('pdf_pen_width') ?? 4).clamp(2, 16);
    });
  }

  Future<void> _choosePenColor() async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('لون القلم والتظليل'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _penColors.map((color) {
            final selected = color.toARGB32() == _penColor.toARGB32();
            return InkWell(
              onTap: () => Navigator.pop(dialogContext, color),
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 21,
                backgroundColor: color,
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (selectedColor == null || !mounted) return;
    setState(() => _penColor = selectedColor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pdf_pen_color', selectedColor.toARGB32());
  }

  void _setPenWidth(double width) {
    setState(() => _penWidth = width);
    _toolPreferenceDebounce?.cancel();
    _toolPreferenceDebounce = Timer(
      const Duration(milliseconds: 250),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('pdf_pen_width', width);
      },
    );
  }

  void _scheduleSaveMarks() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), _saveMarksNow);
  }

  Future<void> _saveMarksNow() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _marksByPage.map(
        (page, marks) => MapEntry(
          page.toString(),
          marks.map((mark) => mark.toJson()).toList(),
        ),
      ),
    );
    await prefs.setString(_marksPreferenceKey, encoded);
  }

  Future<void> _saveLastPage(int pageNumber) async {
    if (pageNumber < 1) return;
    _lastPage = pageNumber;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pagePreferenceKey, pageNumber);
  }

  void _onViewerReady() {
    _viewerReady = true;
    _pageCount = _controller.pageCount;
    _lastPage = _controller.pageNumber ?? 1;
    _pageInputController.text = '$_lastPage';
    if (mounted) setState(() {});
  }

  void _goToPageFromInput(String value) {
    if (!_viewerReady) return;
    final requestedPage = int.tryParse(value);
    if (requestedPage == null) {
      _pageInputController.text = '$_lastPage';
      return;
    }
    final page = requestedPage.clamp(1, _pageCount).toInt();
    _pageInputController.text = '$page';
    FocusScope.of(context).unfocus();
    _controller.goToPage(pageNumber: page);
  }

  void _changePage(int delta) {
    if (!_viewerReady) return;
    final currentPage = _controller.pageNumber ?? _lastPage;
    final page = currentPage + delta;
    if (page < 1 || page > _pageCount) return;
    _pageInputController.text = '$page';
    _controller.goToPage(pageNumber: page);
  }

  Widget _buildPageNavigation() {
    final enabled = _viewerReady && _pageCount > 0;
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'الصفحة السابقة',
            onPressed: enabled ? () => _changePage(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _navy,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(
            width: 112,
            height: 32,
            child: TextField(
                controller: _pageInputController,
                enabled: enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                onSubmitted: _goToPageFromInput,
                decoration: InputDecoration(
                  hintText: 'رقم الصفحة',
                  suffixText: _pageCount > 0 ? '/ $_pageCount' : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold, width: 1.5),
                  ),
                ),
            ),
          ),
          IconButton(
            tooltip: 'الصفحة التالية',
            onPressed: enabled ? () => _changePage(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _navy,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              maximumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _onMarkStart(int pageNumber, Offset position, Size pageSize) {
    if (_activeTool == _PdfTool.none || !_marksLoaded) return;
    _activePage = pageNumber;
    final point = Offset(
      (position.dx / pageSize.width).clamp(0.0, 1.0),
      (position.dy / pageSize.height).clamp(0.0, 1.0),
    );
    if (_activeTool == _PdfTool.eraser) {
      _eraseAt(pageNumber, point);
      return;
    }
    final marks = _marksByPage[pageNumber] ?? const <_PdfMark>[];
    final color = _activeTool == _PdfTool.highlighter
        ? _penColor.withValues(alpha: 0.38)
        : _penColor;
    final width =
        (_penWidth *
                (_activeTool == _PdfTool.highlighter ? 2.8 : 1) /
                pageSize.width)
            .clamp(0.001, 0.12);
    setState(
      () => _marksByPage[pageNumber] = [
        ...marks,
        _PdfMark(points: [point], color: color, width: width),
      ],
    );
    _scheduleSaveMarks();
  }

  void _onMarkUpdate(int pageNumber, Offset position, Size pageSize) {
    if (_activeTool == _PdfTool.none || !_marksLoaded) return;
    final point = Offset(
      (position.dx / pageSize.width).clamp(0.0, 1.0),
      (position.dy / pageSize.height).clamp(0.0, 1.0),
    );
    if (_activeTool == _PdfTool.eraser) {
      _eraseAt(pageNumber, point);
      return;
    }
    final marks = _marksByPage[pageNumber];
    if (marks == null || marks.isEmpty || _activePage != pageNumber) return;
    final activeMark = marks.last;
    setState(
      () => _marksByPage[pageNumber] = [
        ...marks.take(marks.length - 1),
        _PdfMark(
          points: [...activeMark.points, point],
          color: activeMark.color,
          width: activeMark.width,
        ),
      ],
    );
    _scheduleSaveMarks();
  }

  void _eraseAt(int pageNumber, Offset point) {
    final marks = _marksByPage[pageNumber];
    if (marks == null || marks.isEmpty) return;
    const eraseRadius = 0.025;
    final index = marks.lastIndexWhere(
      (mark) => mark.points.any(
        (candidate) => (candidate - point).distance <= eraseRadius,
      ),
    );
    if (index == -1) return;
    setState(
      () => _marksByPage[pageNumber] = [
        ...marks.take(index),
        ...marks.skip(index + 1),
      ],
    );
    _scheduleSaveMarks();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        _setSystemBarStyle();
      }
    });
  }

  Widget _buildErrorView(BuildContext context, {Object? error}) {
    if (error != null) {
      debugPrint('تعذر تحميل ملف الكتاب (${widget.pdfPath}): $error');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 100,
              color: Colors.grey.withAlpha(100),
            ),
            const SizedBox(height: 20),
            Text(
              'عذراً، الملف غير متوفر حالياً',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'قد يكون الاتصال بالإنترنت انقطع أو تعذر الوصول إلى الملف. تحقق من الاتصال ثم أعد المحاولة.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _retryPdfLoad,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة تحميل الكتاب'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkLayer(Rect pageRect, PdfPage page) {
    final marks = _marksByPage[page.pageNumber] ?? const <_PdfMark>[];
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _activeTool == _PdfTool.none || !_marksLoaded,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _onMarkStart(
            page.pageNumber,
            details.localPosition,
            pageRect.size,
          ),
          onPanUpdate: (details) => _onMarkUpdate(
            page.pageNumber,
            details.localPosition,
            pageRect.size,
          ),
          onPanEnd: (_) => _activePage = null,
          child: CustomPaint(
            painter: _PdfMarksPainter(marks),
            size: pageRect.size,
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (!_pdfSourceReady) {
      if (_pdfDownloadError != null) {
        return _buildErrorView(context, error: _pdfDownloadError);
      }
      return _buildRemoteLoadingView();
    }
    final params = PdfViewerParams(
      backgroundColor: Colors.white,
      pageAnchor: PdfPageAnchor.center,
      sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
        calculateInitialZoom: (_, _, fitZoom, _) => fitZoom,
      ),
      calculateInitialPageNumber: (document, controller) => 1,
      layoutPages: (pages, params) {
        final margin = params.margin;
        final contentHeight = pages.fold<double>(
          0,
          (height, page) => math.max(height, page.height).toDouble(),
        );
        final documentWidth = pages.fold<double>(
          margin,
          (width, page) => width + page.width + margin,
        );
        final pageLayouts = <Rect>[];
        var right = documentWidth - margin;
        for (final page in pages) {
          final left = right - page.width;
          final top = margin + (contentHeight - page.height) / 2;
          pageLayouts.add(Rect.fromLTWH(left, top, page.width, page.height));
          right = left - margin;
        }
        return PdfPageLayout(
          pageLayouts: pageLayouts,
          documentSize: Size(documentWidth, contentHeight + margin * 2),
        );
      },
      calculateCurrentPageNumber: (visibleRect, pageRects, controller) {
        var currentPage = 1;
        var largestVisibleArea = 0.0;
        for (var index = 0; index < pageRects.length; index++) {
          final pageRect = pageRects[index];
          final visiblePage = pageRect.intersect(visibleRect);
          if (visiblePage.isEmpty) continue;
          final visibleArea =
              visiblePage.width * visiblePage.height /
              (pageRect.width * pageRect.height);
          if (visibleArea > largestVisibleArea) {
            largestVisibleArea = visibleArea;
            currentPage = index + 1;
          }
        }
        return currentPage;
      },
      onViewerReady: (_, _) => _onViewerReady(),
      onPageChanged: (pageNumber) {
        if (pageNumber != null) {
          _lastPage = pageNumber;
          _pageInputController.text = '$pageNumber';
          _saveLastPage(pageNumber);
          if (mounted) setState(() {});
        }
      },
      onGeneralTap: (context, controller, details) => false,
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        final progress = totalBytes != null && totalBytes > 0
            ? (bytesDownloaded / totalBytes).clamp(0.0, 1.0)
            : null;
        return ColoredBox(
          color: Colors.white,
          child: SizedBox.expand(
            child: Center(
              child: Container(
                width: 250,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: _gold, size: 34),
                    const SizedBox(height: 12),
                    Text(
                      progress == null
                          ? 'جارٍ تحميل ${widget.title}'
                          : 'جارٍ تحميل ${widget.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE8EAF0),
                        valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      progress == null
                          ? 'يرجى الانتظار'
                          : '${(progress * 100).round()}٪',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        if (stackTrace != null) {
          debugPrintStack(
            label: 'فشل تحميل PDF: $error',
            stackTrace: stackTrace,
          );
        }
        return _buildErrorView(context, error: error);
      },
      pageOverlaysBuilder: (context, pageRect, page) => [
        _buildMarkLayer(pageRect, page),
      ],
    );

    if (widget.pdfPath.startsWith('http')) {
      return PdfViewer.file(
        _resolvedPdfPath,
        key: ValueKey('$_documentId-$_viewerReloadKey'),
        controller: _controller,
        params: params,
      );
    }
    return PdfViewer.asset(
      widget.pdfPath,
      key: ValueKey('$_documentId-$_viewerReloadKey'),
      controller: _controller,
      params: params,
    );
  }

  Widget _toolButton(_PdfTool tool, Widget icon, String tooltip) {
    final selected = _activeTool == tool;
    return IconButton(
      tooltip: tooltip,
      onPressed: () => setState(() {
        _activeTool = selected ? _PdfTool.none : tool;
      }),
      style: IconButton.styleFrom(
        foregroundColor: selected ? _navy : Colors.blueGrey.shade500,
        backgroundColor: selected ? _gold.withValues(alpha: 0.2) : null,
        minimumSize: const Size(38, 38),
        maximumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: icon,
    );
  }

  PreferredSizeWidget _buildAppBarTools() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'اختيار لون القلم والتظليل',
                onPressed: _choosePenColor,
                style: IconButton.styleFrom(
                  minimumSize: const Size(38, 38),
                  maximumSize: const Size(38, 38),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: _penColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withValues(alpha: 0.2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.line_weight_rounded,
                size: 16,
                color: Colors.blueGrey,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: _gold,
                      inactiveTrackColor: _navy.withValues(alpha: 0.14),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 11,
                      ),
                    ),
                    child: Slider(
                      value: _penWidth,
                      min: 2,
                      max: 16,
                      divisions: 14,
                      onChanged: _setPenWidth,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: _navy.withValues(alpha: 0.16),
              ),
              _toolButton(
                _PdfTool.pen,
                const Icon(Icons.edit_rounded, size: 21),
                'قلم',
              ),
              _toolButton(
                _PdfTool.highlighter,
                const Icon(Icons.border_color_rounded, size: 21),
                'قلم تظليل',
              ),
              _toolButton(
                _PdfTool.eraser,
                _EraserGlyph(
                  color: _activeTool == _PdfTool.eraser
                      ? _navy
                      : Colors.blueGrey.shade500,
                ),
                'ممحاة',
              ),
              IconButton(
                tooltip: 'ملء الشاشة',
                onPressed: _toggleFullScreen,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.blueGrey.shade500,
                  minimumSize: const Size(36, 36),
                  maximumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.fullscreen_rounded, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _activePdfClient?.close();
    if (_saveDebounce?.isActive ?? false) _saveMarksNow();
    _saveDebounce?.cancel();
    if (_toolPreferenceDebounce?.isActive ?? false) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setDouble('pdf_pen_width', _penWidth),
      );
    }
    _toolPreferenceDebounce?.cancel();
    _pageInputController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _setSystemBarStyle();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              if (!_isFullScreen)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 0,
                      child: AppBar(
                        title: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                        centerTitle: true,
                        backgroundColor: Colors.white,
                        foregroundColor: _navy,
                        systemOverlayStyle: const SystemUiOverlayStyle(
                          statusBarColor: _navy,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                        ),
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.white,
                        bottom: _buildAppBarTools(),
                      ),
                    ),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _navy.withValues(alpha: 0.14),
                            _navy.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.35, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildPdfViewer()),
                    if (_isFullScreen)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: _navy.withAlpha(220),
                          onPressed: _toggleFullScreen,
                          child: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildPageNavigation(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EraserGlyph extends StatelessWidget {
  const _EraserGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(22, 22),
    painter: _EraserGlyphPainter(color),
  );
}

class _EraserGlyphPainter extends CustomPainter {
  const _EraserGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = Path()
      ..moveTo(4, 15)
      ..lineTo(12.5, 6.5)
      ..quadraticBezierTo(14, 5, 15.5, 6.5)
      ..lineTo(21, 12)
      ..lineTo(13, 20)
      ..lineTo(8, 20)
      ..close();
    canvas.drawPath(body, outline);
    final darkHalf = Path()
      ..moveTo(12.5, 6.5)
      ..quadraticBezierTo(14, 5, 15.5, 6.5)
      ..lineTo(21, 12)
      ..lineTo(17, 16)
      ..close();
    canvas.drawPath(darkHalf, Paint()..color = color);
    final base = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(2, 21), const Offset(22, 21), base);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _PdfMarksPainter extends CustomPainter {
  const _PdfMarksPainter(this.marks);

  final List<_PdfMark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      if (mark.points.isEmpty) continue;
      final paint = Paint()
        ..color = mark.color
        ..strokeWidth = mark.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final points = mark.points
          .map((point) => Offset(point.dx * size.width, point.dy * size.height))
          .toList(growable: false);
      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          paint.strokeWidth / 2,
          Paint()
            ..color = mark.color
            ..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PdfMarksPainter oldDelegate) =>
      !identical(marks, oldDelegate.marks);
}
