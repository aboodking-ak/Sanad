import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isFullScreen = false;
  final PdfViewerController _controller = PdfViewerController();

  @override
  void initState() {
    super.initState();
    // التحميل المسبق للصفحة الأخيرة عند فتح الكتاب
  }

  Future<void> _saveLastPage(int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.pdfPath}', pageNumber);
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page_${widget.pdfPath}');
    if (lastPage != null && lastPage > 0) {
      _controller.goToPage(pageNumber: lastPage);
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: SystemUiOverlay.values);
      }
    });
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
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
              "عذراً، الملف غير متوفر حالياً",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "نعمل على توفير جميع المناهج في أقرب وقت ممكن. شكراً لتفهمك.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text("العودة للخلف"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 25, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollThumb(BuildContext context) {
    return PdfViewerScrollThumb(
      controller: _controller,
      orientation: ScrollbarOrientation.right,
      thumbSize: const Size(40, 50),
      thumbBuilder: (context, thumbSize, pageNumber, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            pageNumber?.toString() ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _isFullScreen
            ? null
            : AppBar(
                title: Text(widget.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: _toggleFullScreen,
                  ),
                ],
              ),
        body: Stack(
          children: [
            widget.pdfPath.startsWith('http')
                ? PdfViewer.uri(
                    Uri.parse(widget.pdfPath),
                    controller: _controller,
                    params: PdfViewerParams(
                      onViewerReady: (document, controller) {
                        _loadLastPage();
                      },
                      onPageChanged: (pageNumber) {
                        if (pageNumber != null) {
                          _saveLastPage(pageNumber);
                        }
                      },
                      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 20),
                              Text(
                                totalBytes != null
                                    ? "جاري تحميل الكتاب: ${(bytesDownloaded / totalBytes * 100).toStringAsFixed(0)}%"
                                    : "جاري تحميل الكتاب...",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                      textSelectionParams: const PdfTextSelectionParams(
                        enabled: false,
                      ),
                      errorBannerBuilder: (context, error, stackTrace, documentRef) {
                        return _buildErrorView(context);
                      },
                      viewerOverlayBuilder: (context, size, handleLinkTap) => [
                        _buildScrollThumb(context),
                      ],
                    ),
                  )
                : PdfViewer.asset(
                    widget.pdfPath,
                    controller: _controller,
                    params: PdfViewerParams(
                      onViewerReady: (document, controller) {
                        _loadLastPage();
                      },
                      onPageChanged: (pageNumber) {
                        if (pageNumber != null) {
                          _saveLastPage(pageNumber);
                        }
                      },
                      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 20),
                              Text(
                                totalBytes != null
                                    ? "جاري تحميل الكتاب: ${(bytesDownloaded / totalBytes * 100).toStringAsFixed(0)}%"
                                    : "جاري تحميل الكتاب...",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                      textSelectionParams: const PdfTextSelectionParams(
                        enabled: false,
                      ),
                      errorBannerBuilder: (context, error, stackTrace, documentRef) {
                        return _buildErrorView(context);
                      },
                      viewerOverlayBuilder: (context, size, handleLinkTap) => [
                        _buildScrollThumb(context),
                      ],
                    ),
                  ),
            if (_isFullScreen)
              Positioned(
                top: 40,
                left: 20,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.black54,
                  onPressed: _toggleFullScreen,
                  child: const Icon(Icons.fullscreen_exit, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
