// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';
import 'package:zefyr/src/registry.dart';

import 'editable_box.dart';
import 'horizontal_rule.dart';
import 'image.dart';
import 'rich_text.dart';
import 'scope.dart';
import 'theme.dart';

/// Raw widget representing a single line of rich text document in Zefyr editor.
///
/// See [ZefyrParagraph] and [ZefyrHeading] which wrap this widget and
/// integrate it with current [ZefyrTheme].
class RawZefyrLine extends StatefulWidget {
  const RawZefyrLine({
    Key key,
    @required this.node,
    this.style,
    this.padding,
  }) : super(key: key);

  /// Line in the document represented by this widget.
  final LineNode node;

  /// Style to apply to this line. Required for lines with text contents,
  /// ignored for lines containing embeds.
  final TextStyle style;

  /// Padding to add around this paragraph.
  final EdgeInsets padding;

  @override
  _RawZefyrLineState createState() => _RawZefyrLineState();
}

class _RawZefyrLineState extends State<RawZefyrLine> {
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final scope = ZefyrScope.of(context);
    if (scope.isEditable) {
      ensureVisible(context, scope);
    }
    final theme = ZefyrTheme.of(context);

    Widget content;
    if (widget.node.hasEmbed) {
      content = buildEmbed(context, scope);
    } else {
      assert(widget.style != null);
      content = ZefyrRichText(
        node: widget.node,
        text: buildText(context),
      );
    }

    if (scope.isEditable) {
      content = EditableBox(
        child: content,
        node: widget.node,
        layerLink: _link,
        renderContext: scope.renderContext,
        showCursor: scope.showCursor,
        selection: scope.selection,
        selectionColor: theme.selectionColor,
        cursorColor: theme.cursorColor,
      );
      content = CompositedTransformTarget(link: _link, child: content);
    }

    if (widget.padding != null) {
      return Padding(padding: widget.padding, child: content);
    }
    return content;
  }

  void ensureVisible(BuildContext context, ZefyrScope scope) {
    if (scope.selection.isCollapsed &&
        widget.node.containsOffset(scope.selection.extentOffset)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bringIntoView(context);
      });
    }
  }

  void bringIntoView(BuildContext context) {
    ScrollableState scrollable = Scrollable.of(context);
    final object = context.findRenderObject();
    assert(object.attached);
    final RenderAbstractViewport viewport = RenderAbstractViewport.of(object);
    assert(viewport != null);

    final double offset = scrollable.position.pixels;
    double target = viewport.getOffsetToReveal(object, 0.0).offset;
    if (target - offset < 0.0) {
      scrollable.position.jumpTo(target);
      return;
    }
    target = viewport.getOffsetToReveal(object, 1.0).offset;
    if (target - offset > 0.0) {
      scrollable.position.jumpTo(target);
    }
  }

  TextSpan buildText(BuildContext context) {
    final List<TextSpan> children = widget.node.children
        .map((node) => _segmentToTextSpan(context, node))
        .toList(growable: false);
    return TextSpan(style: widget.style, children: children);
  }

  TextSpan _segmentToTextSpan(BuildContext context, Node node) {
    final ZefyrRegistry registry = ZefyrScope.of(context).registry;
    final TextNode segment = node;
    return TextSpan(
      text: segment.value,
      style: registry.buildTextStyle(context, node),
    );
  }

  Widget buildEmbed(BuildContext context, ZefyrScope scope) {
    EmbedNode node = widget.node.children.single;
    EmbedAttribute embed = node.style.get(NotusAttribute.embed);

    if (embed.type == EmbedType.horizontalRule) {
      return ZefyrHorizontalRule(node: node);
    } else if (embed.type == EmbedType.image) {
      return ZefyrImage(node: node, delegate: scope.imageDelegate);
    } else {
      throw UnimplementedError('Unimplemented embed type ${embed.type}');
    }
  }
}
