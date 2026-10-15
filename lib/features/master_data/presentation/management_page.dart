import 'package:flutter/material.dart';

import '../../contact_lenses/application/lens_store.dart';
import '../../contact_lenses/presentation/lens_page.dart';
import '../../diary/application/diary_store.dart';
import '../application/master_data_store.dart';
import 'master_data_page.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({
    required this.masterStore,
    required this.lensStore,
    required this.diaryStore,
    super.key,
  });
  final MasterDataStore masterStore;
  final LensStore lensStore;
  final DiaryStore diaryStore;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'マスター'),
            Tab(text: 'カラコン'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              MasterDataPage(store: masterStore, diaryStore: diaryStore),
              LensPage(store: lensStore),
            ],
          ),
        ),
      ],
    ),
  );
}
