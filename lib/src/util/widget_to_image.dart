import "dart:typed_data" show Uint8List;
import "dart:ui" show FlutterView, ImageByteFormat;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart"
    show
        PipelineOwner,
        RenderPositionedBox,
        RenderRepaintBoundary,
        RenderView,
        ViewConfiguration;

class WidgetToImageUtil {
  static Widget _setSizeAndTextDirection(
      Widget widget, Size size, BuildContext context, FlutterView view) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: MediaQuery(
          data: MediaQueryData.fromView(view),
          child: Theme(
              data: Theme.of(context),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: widget,
              ))),
    );
  }

  static Future<Uint8List> widgetToImageByte(
    Widget widget, {
    required Size size,
    required BuildContext context,
  }) async {
    final renderBox = RenderRepaintBoundary();
    final view = View.of(context);

    final renderPositionedBox =
        RenderPositionedBox(alignment: Alignment.center, child: renderBox);
    final renderView = RenderView(
        view: view,
      configuration: ViewConfiguration(
        physicalConstraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
        logicalConstraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
        devicePixelRatio: view.devicePixelRatio,
      ),
        child: renderPositionedBox);

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter(
            container: renderBox,
            child: _setSizeAndTextDirection(widget, size, context, view))
        .attachToRenderTree(buildOwner);
    buildOwner
      ..buildScope(rootElement)
      ..finalizeTree();

    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    try {
      final image = await renderBox.toImage(pixelRatio: view.devicePixelRatio);

      final rawImage = await image
          .toByteData(format: ImageByteFormat.png)
          .then((b) => b!.buffer.asUint8List());

      return rawImage;
    } finally {
      final emptyRenderToWidgetAdapter =
          RenderObjectToWidgetAdapter(container: renderBox);
      rootElement.update(emptyRenderToWidgetAdapter); // renderbox child = null
      buildOwner.finalizeTree();
      renderView
        ..detach()
        ..dispose();
      rootElement
        ..detachRenderObject()
        ..deactivate();
      buildOwner.finalizeTree();
    }
  }

  WidgetToImageUtil._();
}
