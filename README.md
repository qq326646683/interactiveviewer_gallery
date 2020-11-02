# interactiveviewer_gallery
[![pub package](https://img.shields.io/pub/v/interactiveviewer_gallery.svg)](https://pub.dartlang.org/packages/interactiveviewer_gallery)

A flutter library to show picture and video preview gallery, support two-finger gesture zoom, double-click to zoom, switch left and right

## How to use

1. Wrap Hero in your image gridview item:
```dart
Hero(
    tag: source.url,
    child: ${gridview item}
)
 ```

2. gridview item's GestureDetector add jumping to interactiveviewer_gallery:
```dart
// DemoSourceEntity is your data model
// itemBuilder is gallery page item
// heroTagBuilder accordding to gridview item's hero tag
void _openGallery(DemoSourceEntity source) {
    Navigator.of(context).push(
      HeroDialogRoute<void>(
        builder: (BuildContext context) => InteractiveviewerGallery<DemoSourceEntity>(
          sources: sourceList,
          initIndex: sourceList.indexOf(source),
          itemBuilder: itemBuilder,
          heroTagBuilder: (int index) => sourceList[index].url,
        ),
      ),
    );
}
```

3. edit itemBuilder: you can copy the example/lib/main.dart or customize
