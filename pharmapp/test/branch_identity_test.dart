import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/shared/models/branch.dart';

/// Regression guard for the once-a-minute app-wide reload.
///
/// The 60-second profile poll re-assigns the active branch. Before Branch had
/// value equality, every assignment emitted a new value, which invalidated all
/// branch-scoped providers (inventory, customers, POS, reports) and dropped the
/// UI back to loading spinners while they refetched.
void main() {
  test('equal Branch values do not re-notify activeBranchProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var notifications = 0;
    container.listen(activeBranchProvider, (_, __) => notifications++);

    container.read(activeBranchProvider.notifier).state =
        const Branch(id: 1, name: 'Main');
    expect(notifications, 1);

    // Same value, fresh instance — what the profile poll produces.
    container.read(activeBranchProvider.notifier).state =
        const Branch(id: 1, name: 'Main');
    expect(notifications, 1, reason: 'identical branch must not notify');

    container.read(activeBranchProvider.notifier).state =
        const Branch(id: 2, name: 'Ikeja');
    expect(notifications, 2, reason: 'a real branch change must notify');
  });
}
