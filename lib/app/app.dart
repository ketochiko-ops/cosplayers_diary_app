import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'router.dart';
import 'theme.dart';
import '../features/master_data/application/master_data_store.dart';
import '../features/diary/application/diary_store.dart';
import '../features/diary/application/delete_diary.dart';
import '../features/diary/presentation/diary_pages.dart';
import '../features/contact_lenses/application/lens_store.dart';
import '../features/master_data/presentation/management_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../core/database/app_state_persistence.dart';
import '../core/database/project_storage.dart';
import '../core/database/project_sync_controller.dart';
import '../core/database/settings_store.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/project_setup.dart';
import '../features/calendar_sync/application/calendar_sync_controller.dart';
import '../features/calendar_sync/infrastructure/calendar_transport.dart';
import '../features/photos/application/photo_controller.dart';
import '../features/photos/infrastructure/default_photo_files.dart';
import '../features/settings/domain/calendar_week_start.dart';

class CosplayDiaryApp extends StatelessWidget {
  const CosplayDiaryApp({this.settingsStore, this.projectStorage, super.key});
  final SettingsStore? settingsStore;
  final ProjectStorage? projectStorage;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'コスプレ日記',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: AppShell(
      settingsStore: settingsStore,
      projectStorage: projectStorage,
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({this.settingsStore, this.projectStorage, super.key});
  final SettingsStore? settingsStore;
  final ProjectStorage? projectStorage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final _masterStore = MasterDataStore();
  final _diaryStore = DiaryStore();
  final _lensStore = LensStore();
  AppStatePersistence? _persistence;
  ProjectSyncController? _projectSync;
  CalendarSyncController? _calendarSync;
  PhotoController? _photos;
  CalendarWeekStart _weekStart = CalendarWeekStart.monday;
  int _projectVersion = 0;
  bool _loading = false;
  bool _setupOpen = false;
  bool _setupScheduled = false;
  Timer? _fileMonitor;
  bool get _requiresProject => kIsWeb || widget.projectStorage != null;

  void _deleteDiary(String id) =>
      deleteDiary(diary: _diaryStore, lenses: _lensStore, id: id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.settingsStore != null) {
      _loading = true;
      _persistence = AppStatePersistence(
        store: widget.settingsStore!,
        masters: _masterStore,
        diary: _diaryStore,
        lenses: _lensStore,
      );
      _projectSync = ProjectSyncController(
        persistence: _persistence!,
        settings: widget.settingsStore!,
        storage: widget.projectStorage ?? createProjectStorage(),
      );
      _calendarSync = CalendarSyncController(
        persistence: _persistence!,
        settings: widget.settingsStore!,
        transport: createCalendarTransport(),
        canSync: () =>
            mounted &&
            !_loading &&
            !_setupOpen &&
            (!_requiresProject || !_projectSync!.requiresSelection) &&
            !Navigator.of(context).canPop(),
        onRemoteChanged: () {
          if (mounted) setState(() {});
        },
      );
      _projectSync!.addListener(_projectChanged);
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    _weekStart = CalendarWeekStart.fromSetting(
      await widget.settingsStore!.readSetting(CalendarWeekStart.settingKey),
    );
    _photos = PhotoController(
      persistence: _persistence!,
      files: _requiresProject
          ? _projectSync!.storage.assets
          : await openPhotoFiles(),
    );
    Object? cacheError;
    try {
      await _persistence!.load();
    } catch (error) {
      if (!_requiresProject) rethrow;
      cacheError = error;
    }
    await _projectSync!.loadPreference();
    if (cacheError != null) {
      _projectSync!.reportCacheError(cacheError);
    } else if (_requiresProject) {
      await _projectSync!.tryResumeLocalFolder();
    }
    await _calendarSync!.load();
    _persistence!.attach();
    if (!mounted) return;
    setState(() => _loading = false);
    if (_requiresProject) {
      _fileMonitor = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(_projectSync!.checkFolder());
      });
      _projectChanged();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _requiresProject && !_loading) {
      unawaited(_projectSync?.checkFolder());
    }
  }

  void _projectChanged() {
    if (!mounted || _loading || !_requiresProject) return;
    if (_projectVersion != _projectSync!.loadedProjectVersion) {
      _projectVersion = _projectSync!.loadedProjectVersion;
      unawaited(_calendarSync?.disconnect(projectChanged: true));
    }
    setState(() {});
    if (!_projectSync!.requiresSelection || _setupOpen || _setupScheduled) {
      return;
    }
    _setupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _setupScheduled = false;
      if (!mounted || !_projectSync!.requiresSelection || _setupOpen) return;
      _setupOpen = true;
      final loadedVersion = _projectSync!.loadedProjectVersion;
      // Root navigator places recovery above an open diary editor as well.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('プロジェクトの保存方法'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: ProjectSetup(
                  sync: _projectSync!,
                  onReady: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
      _setupOpen = false;
      if (mounted && _projectSync!.loadedProjectVersion != loadedVersion) {
        // An editor for the previous project must not write into the new one.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      _projectChanged();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fileMonitor?.cancel();
    _projectSync?.removeListener(_projectChanged);
    _calendarSync?.dispose();
    if (_persistence != null) {
      unawaited(
        _persistence!.dispose().whenComplete(() => _projectSync?.dispose()),
      );
    }
    _masterStore.dispose();
    _diaryStore.dispose();
    _lensStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_requiresProject && (_projectSync?.requiresSelection ?? false)) {
      return const Scaffold(body: Center(child: Text('プロジェクトの保存方法を指定してください')));
    }
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final body = switch (_index) {
      0 => CalendarPage(
        store: _diaryStore,
        masterStore: _masterStore,
        photos: _photos,
        onDelete: _deleteDiary,
        weekStart: _weekStart,
      ),
      1 => DiaryListPage(
        store: _diaryStore,
        masterStore: _masterStore,
        photos: _photos,
        onDelete: _deleteDiary,
      ),
      2 => ManagementPage(masterStore: _masterStore, lensStore: _lensStore),
      3 => DashboardPage(
        diaryStore: _diaryStore,
        lensStore: _lensStore,
        masterStore: _masterStore,
      ),
      4 => SettingsPage(
        settingsStore: widget.settingsStore,
        persistence: _persistence,
        projectSync: _projectSync,
        calendarSync: _calendarSync,
        photoFiles: _photos?.files,
        weekStart: _weekStart,
        onWeekStartChanged: (value) => setState(() => _weekStart = value),
        onProjectLoaded: () {
          unawaited(_calendarSync?.disconnect(projectChanged: true));
          setState(() {});
        },
      ),
      _ => PlaceholderFeaturePage(title: pageTitles[_index]),
    };
    final content = wide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in appDestinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          )
        : body;

    return Scaffold(
      appBar: AppBar(title: Text(pageTitles[_index])),
      body: SafeArea(child: content),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: appDestinations,
            ),
    );
  }
}
