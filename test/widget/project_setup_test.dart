import 'package:cosplayers_diary/app/app.dart';
import 'package:cosplayers_diary/core/database/project_sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/project_storage_fake.dart';

void main() {
  testWidgets('first launch requires choosing a mode and Safari can start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = MemorySettingsStore();
    final storage = FakeProjectStorage()..supported = false;
    await tester.pumpWidget(
      CosplayDiaryApp(settingsStore: settings, projectStorage: storage),
    );
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトの保存方法'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトの保存方法'), findsOneWidget);
    await tester.ensureVisible(find.text('ブラウザ保存モードで開始'));
    await tester.tap(find.text('ブラウザ保存モードで開始'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(settings.values[ProjectSyncController.preferenceKey], 'browser');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'cancel keeps startup blocked and creating a file enables editing',
    (tester) async {
      final storage = FakeProjectStorage()..cancel = true;
      await tester.pumpWidget(
        CosplayDiaryApp(
          settingsStore: MemorySettingsStore(),
          projectStorage: storage,
        ),
      );
      await tester.pumpAndSettle();
      final create = find.text('保存場所を指定してプロジェクトを作成');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      storage.cancel = false;
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(storage.content, contains('"diary":[]'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('file loss opens mandatory recovery above an existing route', (
    tester,
  ) async {
    final storage = FakeProjectStorage();
    final settings = MemorySettingsStore();
    await tester.pumpWidget(
      CosplayDiaryApp(settingsStore: settings, projectStorage: storage),
    );
    await tester.pumpAndSettle();
    final create = find.text('保存場所を指定してプロジェクトを作成');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('編集中の画面')),
      ),
    );
    await tester.pumpAndSettle();
    storage.available = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトの保存方法'), findsOneWidget);
    expect(find.textContaining('読み込めません'), findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('編集中の画面'), findsOneWidget);
    expect(find.text('プロジェクトの保存方法'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('loading different file contents closes the old project editor', (
    tester,
  ) async {
    final storage = FakeProjectStorage();
    await tester.pumpWidget(
      CosplayDiaryApp(
        settingsStore: MemorySettingsStore(),
        projectStorage: storage,
      ),
    );
    await tester.pumpAndSettle();
    final create = find.text('保存場所を指定してプロジェクトを作成');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('前のプロジェクトの編集')),
          ),
        );
    await tester.pumpAndSettle();
    storage.content = storage.revision = storage.content!.replaceFirst(
      '"genres":[]',
      '"genres":[{"id":"new","name":"新しい作品"}]',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final open = find.text('既存のプロジェクトフォルダを開く');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.text('フォルダの内容を読み込む'));
    await tester.pumpAndSettle();
    expect(find.text('前のプロジェクトの編集'), findsNothing);
    expect(find.text('プロジェクトの保存方法'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'corrupt browser cache requires recovery instead of silently opening an empty project',
    (tester) async {
      final settings = MemorySettingsStore()
        ..values[ProjectSyncController.preferenceKey] = 'browser'
        ..values['app_state_v1'] = '{broken json';
      await tester.pumpWidget(
        CosplayDiaryApp(
          settingsStore: settings,
          projectStorage: FakeProjectStorage()..supported = false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('プロジェクトの保存方法'), findsOneWidget);
      expect(find.textContaining('端末内の保存データを読み込めません'), findsOneWidget);
      expect(settings.values['app_state_v1'], '{broken json');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(settings.values['app_state_v1'], '{broken json');
    },
  );

  testWidgets('settings can switch browser and file modes', (tester) async {
    final storage = FakeProjectStorage();
    final settings = MemorySettingsStore()
      ..values[ProjectSyncController.preferenceKey] = 'browser';
    await tester.pumpWidget(
      CosplayDiaryApp(settingsStore: settings, projectStorage: storage),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存モード・プロジェクトフォルダを変更'));
    await tester.pumpAndSettle();
    expect(find.text('プロジェクトの保存方法'), findsOneWidget);
    final create = find.text('保存場所を指定してプロジェクトを作成');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.textContaining('指定フォルダへ自動保存:'), findsOneWidget);
    await tester.tap(find.text('保存モード・プロジェクトフォルダを変更'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ブラウザ保存モードで開始'));
    await tester.tap(find.text('ブラウザ保存モードで開始'));
    await tester.pumpAndSettle();
    expect(settings.values[ProjectSyncController.preferenceKey], 'browser');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
