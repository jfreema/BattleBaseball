// Merch: Battle Baseball shirts, coming soon. A section on Home and its own
// page (/merch), linked from Account. Nothing is sold yet.
import 'package:battle_baseball/design/bb.dart';
import 'package:battle_baseball/screens/common.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The shirts on the way, each a photo and a name.
const merchItems = <({String name, String image})>[
  (name: 'Military Green Tee', image: 'assets/merch/military-green-tee.jpg'),
  (name: 'Royal Blue Tee', image: 'assets/merch/royal-blue-tee.jpg'),
];

/// Home's Merch section: the title with a Coming soon pill, then the shirts.
class MerchSection extends StatelessWidget {
  const MerchSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Merch', trailing: Pill('Coming soon')),
          _ShirtRow(onTap: () => context.go('/merch')),
        ],
      );
}

class MerchScreen extends StatelessWidget {
  const MerchScreen({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
        column: 640,
        children: [
          const BackHeader('Account'),
          const PageTitle('Merch', trailing: Pill('Coming soon')),
          Text(
            "Battle Baseball tees are on the way. They aren't for sale yet; check back soon.",
            style: BB.bodyStyle(16, height: 1.45),
          ),
          const SizedBox(height: 18),
          const _ShirtRow(),
        ],
      );
}

/// The shirts side by side, each on paper with its name.
class _ShirtRow extends StatelessWidget {
  const _ShirtRow({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, item) in merchItems.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Paper(
                onTap: onTap,
                padding: const EdgeInsets.all(8),
                semanticLabel: '${item.name}, coming soon',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(item.image, fit: BoxFit.cover),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                      child: Text(
                        item.name,
                        maxLines: 2,
                        style: BB.labelStyle(15, color: BB.ink, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}
