import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class SplitTable extends StatelessWidget {
  final List<ActivitySplit> splits;

  const SplitTable({super.key, required this.splits});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        alignment: Alignment.center,
        child: const Text(
          'Start recording to see kilometre splits…',
          style: TextStyle(color: RuchaTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: RuchaTheme.border)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 1,
                child: Text('KM', style: TextStyle(color: RuchaTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
              Expanded(
                flex: 2,
                child: Text('PACE', style: TextStyle(color: RuchaTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
              Expanded(
                flex: 2,
                child: Text('ELEVATION', textAlign: TextAlign.right, style: TextStyle(color: RuchaTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: splits.length,
          itemBuilder: (context, index) {
            final s = splits[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.transparent : RuchaTheme.surface2.withOpacity(0.3),
                border: const Border(bottom: BorderSide(color: RuchaTheme.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text('${s.km}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${RuchaConstants.formatPace(s.paceSeconds)} /km', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('+${s.eleGain.round()} m', textAlign: TextAlign.right, style: const TextStyle(color: RuchaTheme.accentGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
