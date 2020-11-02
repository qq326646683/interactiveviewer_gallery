library interactiveviewer_gallery;
import 'package:flutter/material.dart';
import './custom_dismissible.dart';
import './interactive_viewer_boundary.dart';

/// Builds a carousel controlled by a [PageView] for the tweet media sources.
///
/// Used for showing a full screen view of the [TweetMedia] sources.
///
/// The sources can be panned and zoomed interactively using an
/// [InteractiveViewer].
/// An [InteractiveViewerBoundary] is used to detect when the boundary of the
/// source is hit after zooming in to disable or enable the swiping gesture of
/// the [PageView].
///
typedef IndexedFocusedWidgetBuilder = Widget Function(BuildContext context, int index, bool isFocus);

typedef IndexedTagStringBuilder = String Function(int index);

class InteractiveviewerGallery<T> extends StatefulWidget {
  const InteractiveviewerGallery({
    @required this.sources,
    @required this.initIndex,
    @required this.itemBuilder,
    @required this.heroTagBuilder,
    this.maxScale = 2.5,
    this.minScale = 1.0,
  });

  /// The sources to show.
  final List<T> sources;

  /// The index of the first source in [sources] to show.
  final int initIndex;

  /// The item content
  final IndexedFocusedWidgetBuilder itemBuilder;

  /// return hero tag
  final IndexedTagStringBuilder heroTagBuilder;

  final double maxScale;

  final double minScale;

  @override
  _TweetSourceGalleryState createState() => _TweetSourceGalleryState();
}

class _TweetSourceGalleryState extends State<InteractiveviewerGallery> with SingleTickerProviderStateMixin {
  PageController _pageController;
  TransformationController _transformationController;

  /// The controller to animate the transformation value of the
  /// [InteractiveViewer] when it should reset.
  AnimationController _animationController;
  Animation<Matrix4> _animation;

  /// `true` when an source is zoomed in and not at the at a horizontal boundary
  /// to disable the [PageView].
  bool _enablePageView = true;

  /// `true` when an source is zoomed in to disable the [CustomDismissible].
  bool _enableDismiss = true;

  Offset _doubleTapLocalPosition;

  int currentIndex;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: widget.initIndex);

    _transformationController = TransformationController();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )
      ..addListener(() {
        _transformationController.value = _animation?.value ?? Matrix4.identity();
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && !_enableDismiss) {
          setState(() {
            _enableDismiss = true;
          });
        }
      });

    currentIndex = widget.initIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  /// When the source gets scaled up, the swipe up / down to dismiss gets
  /// disabled.
  ///
  /// When the scale resets, the dismiss and the page view swiping gets enabled.
  void _onScaleChanged(double scale) {
    final bool initialScale = scale <= widget.minScale;

    if (initialScale) {
      if (!_enableDismiss) {
        setState(() {
          _enableDismiss = true;
        });
      }

      if (!_enablePageView) {
        setState(() {
          _enablePageView = true;
        });
      }
    } else {
      if (_enableDismiss) {
        setState(() {
          _enableDismiss = false;
        });
      }

      if (_enablePageView) {
        setState(() {
          _enablePageView = false;
        });
      }
    }
  }

  /// When the left boundary has been hit after scaling up the source, the page
  /// view swiping gets enabled if it has a page to swipe to.
  void _onLeftBoundaryHit() {
    if (!_enablePageView && _pageController.page.floor() > 0) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// When the right boundary has been hit after scaling up the source, the page
  /// view swiping gets enabled if it has a page to swipe to.
  void _onRightBoundaryHit() {
    if (!_enablePageView && _pageController.page.floor() < widget.sources.length - 1) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// When the source has been scaled up and no horizontal boundary has been hit,
  /// the page view swiping gets disabled.
  void _onNoBoundaryHit() {
    if (_enablePageView) {
      setState(() {
        _enablePageView = false;
      });
    }
  }

  /// When the page view changed its page, the source will animate back into the
  /// original scale if it was scaled up.
  ///
  /// Additionally the swipe up / down to dismiss gets enabled.
  void _onPageChanged(int page) {
    setState(() {
      currentIndex = page;
    });
    if (_transformationController.value != Matrix4.identity()) {
      // animate the reset for the transformation of the interactive viewer

      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(
        CurveTween(curve: Curves.easeOut).animate(_animationController),
      );

      _animationController.forward(from: 0);
    }
  }

  /// The [FlightShuttleBuilder] for the hero widget.
  ///
  /// Since the source in the list can have a different box fit, this flight
  /// shuttle builder is used to make sure the hero transitions properly.

  @override
  Widget build(BuildContext context) {
    return InteractiveViewerBoundary(
      controller: _transformationController,
      boundaryWidth: MediaQuery.of(context).size.width,
      onScaleChanged: _onScaleChanged,
      onLeftBoundaryHit: _onLeftBoundaryHit,
      onRightBoundaryHit: _onRightBoundaryHit,
      onNoBoundaryHit: _onNoBoundaryHit,
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      child: CustomDismissible(
        onDismissed: () => Navigator.of(context).pop(),
        enabled: _enableDismiss,
        child: Hero(
          tag: widget.heroTagBuilder(currentIndex),
          child: PageView.builder(
            onPageChanged: _onPageChanged,
            controller: _pageController,
            physics: _enablePageView ? null : const NeverScrollableScrollPhysics(),
            itemCount: widget.sources.length,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                onDoubleTapDown: (TapDownDetails details) {
                  _doubleTapLocalPosition = details.localPosition;
                },
                onDoubleTap: onDoubleTap,
                child: widget.itemBuilder(context, index, index == currentIndex),
              );
            },
          ),
        ),
      ),
    );
  }

  onDoubleTap() {
    Matrix4 matrix = _transformationController.value.clone();
    double currentScale = matrix.row0.x;

    double targetScale = widget.minScale;

    if (currentScale <= widget.minScale) {
      targetScale = widget.maxScale;
    }

    double offSetX = targetScale == 1.0 ? 0.0 : -(_doubleTapLocalPosition.dx / MediaQuery.of(context).size.width) * (targetScale * 1.3 * MediaQuery.of(context).size.width) + MediaQuery.of(context).size.width;
    if (offSetX > 0) offSetX = 0.0;
    double offSetXBoundary = (1 - targetScale) * MediaQuery.of(context).size.width;
    if (offSetX < offSetXBoundary) offSetX = offSetXBoundary;

    double offSetY = targetScale == 1.0 ? 0.0 : -(_doubleTapLocalPosition.dy / MediaQuery.of(context).size.height) * (targetScale * 1.3 * MediaQuery.of(context).size.height) + MediaQuery.of(context).size.height;
    if (offSetY > 0) offSetY = 0.0;
    double offSetYBoundary = (1 - targetScale) * MediaQuery.of(context).size.height;
    if (offSetY < offSetYBoundary) offSetY = offSetYBoundary;

    matrix = Matrix4.fromList([targetScale, matrix.row1.x, matrix.row2.x, matrix.row3.x, matrix.row0.y, targetScale, matrix.row2.y, matrix.row3.y, matrix.row0.z, matrix.row1.z, targetScale, matrix.row3.z, offSetX, offSetY, matrix.row2.w, matrix.row3.w]);
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: matrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0).whenComplete(() => _onScaleChanged(targetScale));
  }
}

