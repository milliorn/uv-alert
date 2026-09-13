import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/widgets/periodic_rebuild.dart';

class _DefaultRebuildWidget extends StatefulWidget {
  const _DefaultRebuildWidget({required this.onBuild});

  final VoidCallback onBuild;

  @override
  State<_DefaultRebuildWidget> createState() => _DefaultRebuildWidgetState();
}

class _DefaultRebuildWidgetState extends State<_DefaultRebuildWidget>
    with PeriodicRebuildMixin<_DefaultRebuildWidget> {
  @override
  Duration get rebuildInterval => const Duration(minutes: 1);

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('default shouldRebuild always rebuilds on the periodic timer', (
    WidgetTester tester,
  ) async {
    int buildCount = 0;

    await tester.pumpWidget(_DefaultRebuildWidget(onBuild: () => buildCount++));
    final int buildsBeforeTick = buildCount;

    await tester.pump(const Duration(minutes: 1));
    expect(buildCount, greaterThan(buildsBeforeTick));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
