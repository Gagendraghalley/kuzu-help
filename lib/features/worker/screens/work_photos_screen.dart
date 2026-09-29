import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/work_photo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../auth/data/auth_repository.dart';
import '../data/work_photo_repository.dart';
import '../providers/worker_providers.dart';

/// Photos of your work (from B5 or Settings)
/// Purpose: Show customers finished jobs, which persuades more than a bio.
/// Backend: work-photos bucket (public) and work_photos, up to 12.
/// Done when: New photos show on the worker's page (C3).
class WorkPhotosScreen extends ConsumerStatefulWidget {
  const WorkPhotosScreen({super.key});

  @override
  ConsumerState<WorkPhotosScreen> createState() => _WorkPhotosScreenState();
}

class _WorkPhotosScreenState extends ConsumerState<WorkPhotosScreen> {
  bool _busy = false;

  String get _myId => ref.read(authRepositoryProvider).userId ?? '';

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(workPhotosProvider(_myId));
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final photo = await pickPhoto(context);
    if (photo == null || !mounted) return;
    await _run(() => ref.read(workPhotoRepositoryProvider).addPhoto(photo), done: AppStrings.photoAdded);
  }

  Future<void> _remove(WorkPhoto photo) async {
    final ok = await confirm(
      context,
      title: AppStrings.removePhotoTitle,
      confirmLabel: AppStrings.remove,
      destructive: true,
    );
    if (ok) await _run(() => ref.read(workPhotoRepositoryProvider).deletePhoto(photo));
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(workPhotosProvider(ref.watch(authRepositoryProvider).userId ?? ''));
    final full = (photos.valueOrNull?.length ?? 0) >= AppConstants.maxWorkPhotos;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.yourWorkPhotos)),
      floatingActionButton: photos.hasValue
          ? FloatingActionButton.extended(
              icon: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined),
              label: const Text(AppStrings.addPhoto),
              onPressed: _busy || full ? null : _add,
            )
          : null,
      body: SafeArea(
        child: AsyncView(
          value: photos,
          onRetry: () => ref.invalidate(workPhotosProvider(_myId)),
          data: (photos) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              InfoNote(
                icon: Icons.photo_library_outlined,
                text: full
                    ? AppStrings.workPhotosFull(AppConstants.maxWorkPhotos)
                    : AppStrings.workPhotosHint(AppConstants.maxWorkPhotos),
              ),
              const SizedBox(height: 16),
              if (photos.isEmpty)
                const EmptyState(icon: Icons.photo_camera_outlined, message: AppStrings.noWorkPhotos)
              else
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final photo in photos)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          LayoutBuilder(
                            builder: (context, box) => PhotoThumb(url: photo.url, size: box.maxWidth),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              iconSize: 20,
                              tooltip: AppStrings.remove,
                              icon: const Icon(Icons.delete_outline, color: Colors.white),
                              onPressed: _busy ? null : () => _remove(photo),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
