import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/app_lock_notifier.dart';
import '../screens/lock/lock_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/editor/note_editor_screen.dart';
import '../screens/book/book_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tags/tag_management_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/activity/activity_logs_screen.dart';
import '../screens/shared/invites_screen.dart';
import '../screens/shared/manage_collaborators_screen.dart';
import '../screens/shared/shared_note_editor_screen.dart';
import '../screens/viewer/note_viewer_screen.dart';

// Overridden at startup in main.dart once SharedPreferences is read.
// Defaults to true so hot-restart skips onboarding after first run.
final onboardingCompleteProvider = Provider<bool>((_) => true);

// Smooth fade transition used on every route — 180 ms feels instant but
// still gives the eye a moment to register the screen change.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

GoRouter createRouter(Ref ref) {
  final onboardingDone = ref.read(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: onboardingDone ? '/lock' : '/onboarding',
    redirect: (context, state) {
      // Never redirect away from onboarding — it manages its own exit.
      if (state.matchedLocation == '/onboarding') return null;

      final isLocked = ref.read(appLockProvider).isLocked;
      if (isLocked && state.matchedLocation != '/lock') return '/lock';
      if (!isLocked && state.matchedLocation == '/lock') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) => _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/lock',
        pageBuilder: (_, state) => _fadePage(state, const LockScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/viewer',
        pageBuilder: (_, state) {
          final noteId =
              int.tryParse(state.uri.queryParameters['noteId'] ?? '') ?? 0;
          final folderId =
              int.tryParse(state.uri.queryParameters['folderId'] ?? '0') ?? 0;
          return _fadePage(state, NoteViewerScreen(noteId: noteId, folderId: folderId));
        },
      ),
      GoRoute(
        path: '/editor',
        pageBuilder: (_, state) {
          final noteId =
              int.tryParse(state.uri.queryParameters['noteId'] ?? '');
          final folderId =
              int.tryParse(state.uri.queryParameters['folderId'] ?? '0') ?? 0;
          return _fadePage(state, NoteEditorScreen(noteId: noteId, folderId: folderId));
        },
      ),
      GoRoute(
        path: '/book',
        pageBuilder: (_, state) {
          final folderId =
              int.tryParse(state.uri.queryParameters['folderId'] ?? '');
          return _fadePage(state, BookScreen(folderId: folderId));
        },
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _fadePage(state, const SearchScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _fadePage(state, const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'tags',
            pageBuilder: (_, state) =>
                _fadePage(state, const TagManagementScreen()),
          ),
          GoRoute(
            path: 'activity',
            pageBuilder: (_, state) =>
                _fadePage(state, const ActivityLogsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/shared/editor',
        pageBuilder: (_, state) {
          final noteId = state.uri.queryParameters['noteId'];
          return _fadePage(state, SharedNoteEditorScreen(noteId: noteId));
        },
      ),
      GoRoute(
        path: '/shared/manage',
        pageBuilder: (_, state) {
          final noteId = state.uri.queryParameters['noteId'] ?? '';
          return _fadePage(state, ManageCollaboratorsScreen(noteId: noteId));
        },
      ),
      GoRoute(
        path: '/shared/invites',
        pageBuilder: (_, state) => _fadePage(state, const InvitesScreen()),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));
