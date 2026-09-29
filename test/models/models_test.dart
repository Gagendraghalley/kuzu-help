import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/shared/models/app_notification.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:bhutan_services/shared/models/worker_listing.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:bhutan_services/shared/models/worker_progress.dart';
import 'package:bhutan_services/shared/models/worker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WorkerListing.fromJson reads a worker_directory row', () {
    final worker = WorkerListing.fromJson({
      'id': 'w1',
      'full_name': 'Pema Dorji',
      'avatar_url': null,
      'dzongkhag': 'Thimphu',
      'town': 'Changzamtog',
      'bio': null,
      'years_experience': 8,
      'whatsapp_number': '+97517123456',
      'is_available': false,
      'avg_rating': 4, // whole numbers come back without a decimal point
      'review_count': 3,
    });
    expect(worker.avgRating, 4.0);
    expect(worker.isAvailable, isFalse);
    expect(worker.location, 'Changzamtog, Thimphu');
  });

  test('WorkerListing.location skips a missing town', () {
    final worker = WorkerListing.fromJson({'id': 'w1', 'dzongkhag': 'Paro', 'town': ' '});
    expect(worker.location, 'Paro');
  });

  test('WorkerService.fromJson reads the embedded category', () {
    final service = WorkerService.fromJson({
      'worker_id': 'w1',
      'category_id': 'c1',
      'price_note': 'Nu 500 per visit',
      'service_categories': {'name': 'Plumber', 'icon': 'plumber'},
    });
    expect(service.categoryName, 'Plumber');
    expect(service.categoryIcon, 'plumber');
    expect(service.priceNote, 'Nu 500 per visit');
  });

  test('AppNotification.fromJson reads a notifications row', () {
    final unread = AppNotification.fromJson({
      'id': 'n1',
      'user_id': 'w1',
      'type': 'review_new',
      'data': {'worker_id': 'w1', 'rating': 5},
      'actor_id': 'c1',
      'read_at': null,
      'created_at': '2026-09-01T10:00:00+00:00',
    });
    expect(unread.isRead, isFalse);
    expect(unread.workerId, 'w1');
    expect(unread.data['rating'], 5);
    expect(unread.createdAt, DateTime.utc(2026, 9, 1, 10));

    final read = AppNotification.fromJson({
      'id': 'n2',
      'type': 'welcome',
      'data': null,
      'read_at': '2026-09-02T08:00:00+00:00',
      'created_at': '2026-09-01T10:00:00+00:00',
    });
    expect(read.isRead, isTrue);
    expect(read.data, isEmpty);
  });

  test('Review.fromJson reads a reviews row', () {
    final review = Review.fromJson({
      'id': 'r1',
      'worker_id': 'w1',
      'customer_id': 'c1',
      'rating': 5,
      'comment': null,
      'created_at': '2026-09-01T10:00:00+00:00',
    });
    expect(review.rating, 5);
    expect(review.createdAt, DateTime.utc(2026, 9, 1, 10));
  });

  test('WorkerProfile.fromJson reads status and the admin note', () {
    final worker = WorkerProfile.fromJson({
      'id': 'w1',
      'years_experience': 2,
      'is_available': true,
      'verification_status': 'rejected',
      'admin_notes': 'Your CID photo is blurry.',
    });
    expect(worker.verificationStatus, VerificationStatus.rejected);
    expect(worker.adminNotes, 'Your CID photo is blurry.');
  });

  test('Profile.fromJson reads a profiles row', () {
    final profile = Profile.fromJson({
      'id': 'user-1',
      'full_name': 'Pema Dorji',
      'role': 'worker',
      'email': 'pema@example.com',
      'phone': null,
      'avatar_url': null,
      'dzongkhag': 'Thimphu',
      'town': null,
    });
    expect(profile.fullName, 'Pema Dorji');
    expect(profile.role, UserRole.worker);
    expect(profile.dzongkhag, 'Thimphu');
    expect(profile.phone, isNull);
  });

  group('WorkerProgress.fromJson', () {
    test('no worker_profiles row means setup has not started', () {
      expect(WorkerProgress.fromJson(null).hasProfile, isFalse);
    });

    test('reads embedded services and verification', () {
      final progress = WorkerProgress.fromJson({
        'verification_status': 'pending',
        'worker_services': [
          {'category_id': 'c1'},
        ],
        'worker_verifications': {'worker_id': 'user-1'},
      });
      expect(progress.hasProfile, isTrue);
      expect(progress.hasServices, isTrue);
      expect(progress.hasVerification, isTrue);
      expect(progress.status, VerificationStatus.pending);
    });

    test('empty embeds, as an empty list or null', () {
      final asLists = WorkerProgress.fromJson({
        'verification_status': 'rejected',
        'worker_services': [],
        'worker_verifications': [],
      });
      expect(asLists.hasServices, isFalse);
      expect(asLists.hasVerification, isFalse);

      final asNull = WorkerProgress.fromJson({
        'verification_status': 'pending',
        'worker_services': [],
        'worker_verifications': null,
      });
      expect(asNull.hasVerification, isFalse);
    });
  });
}
