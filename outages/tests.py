from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from areas.models import Area
from accounts.models import SavedArea
from notifications.models import Notification

from .models import (
	OutageConfirmation,
	OutageReport,
	OutageUpdate,
	OutageVerification,
)


User = get_user_model()


class OutageApiTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username='reporter',
			email='reporter@example.com',
			password='StrongPass123!',
		)
		self.other_user = User.objects.create_user(
			username='other',
			email='other@example.com',
			password='StrongPass123!',
		)
		self.area = Area.objects.create(
			name='Accra Central',
			region='Greater Accra',
		)
		self.outage = OutageReport.objects.create(
			reported_by=self.user,
			area=self.area,
			description='Power is out',
			latitude=5.6037,
			longitude=-0.1870,
			outage_type='unplanned',
		)
		self.client = APIClient()
		self.client.force_authenticate(self.user)

	def test_user_can_confirm_an_outage_once(self):
		response = self.client.post(
			f'/api/outages/{self.outage.id}/confirm/',
		)
		duplicate_response = self.client.post(
			f'/api/outages/{self.outage.id}/confirm/',
		)

		self.assertEqual(response.status_code, 200)
		self.assertEqual(duplicate_response.status_code, 400)
		self.assertEqual(OutageConfirmation.objects.count(), 1)

	def test_user_can_verify_an_outage_once(self):
		response = self.client.post(
			f'/api/outages/{self.outage.id}/verify/',
			{'is_accurate': True},
			format='json',
		)
		duplicate_response = self.client.post(
			f'/api/outages/{self.outage.id}/verify/',
			{'is_accurate': False},
			format='json',
		)

		self.assertEqual(response.status_code, 201)
		self.assertEqual(duplicate_response.status_code, 400)
		self.assertEqual(OutageVerification.objects.count(), 1)

	def test_user_can_mark_an_outage_restored(self):
		response = self.client.post(
			f'/api/outages/{self.outage.id}/resolve/',
		)

		self.assertEqual(response.status_code, 200)
		self.outage.refresh_from_db()
		self.assertEqual(self.outage.status, 'restored')
		self.assertIsNotNone(self.outage.restored_at)

	def test_user_only_sees_own_outages(self):
		other_outage = OutageReport.objects.create(
			reported_by=self.other_user,
			area=self.area,
			description='Another power issue',
			latitude=5.6040,
			longitude=-0.1875,
			outage_type='unplanned',
		)

		response = self.client.get('/api/outages/')

		self.assertEqual(response.status_code, 200)
		self.assertEqual(
			{outage['id'] for outage in response.data},
			{self.outage.id},
		)

	def test_user_cannot_retrieve_another_users_outage(self):
		other_outage = OutageReport.objects.create(
			reported_by=self.other_user,
			area=self.area,
			description='Another power issue',
			latitude=5.6040,
			longitude=-0.1875,
			outage_type='unplanned',
		)

		response = self.client.get(f'/api/outages/{other_outage.id}/')

		self.assertEqual(response.status_code, 404)

	def test_admin_sees_all_outages(self):
		admin = User.objects.create_superuser(
			username='admin',
			email='admin@example.com',
			password='StrongPass123!',
		)
		other_outage = OutageReport.objects.create(
			reported_by=self.other_user,
			area=self.area,
			description='Another power issue',
			latitude=5.6040,
			longitude=-0.1875,
			outage_type='unplanned',
		)
		self.client.force_authenticate(admin)

		response = self.client.get('/api/outages/')

		self.assertEqual(response.status_code, 200)
		self.assertEqual(
			{outage['id'] for outage in response.data},
			{self.outage.id, other_outage.id},
		)

	def test_only_admin_can_send_an_outage_update(self):
		response = self.client.post(
			f'/api/outages/{self.outage.id}/updates/',
			{'message': 'A technician has been assigned.'},
			format='json',
		)
		self.assertEqual(response.status_code, 403)

		admin = User.objects.create_superuser(
			username='admin',
			email='admin@example.com',
			password='StrongPass123!',
		)
		self.client.force_authenticate(admin)
		response = self.client.post(
			f'/api/outages/{self.outage.id}/updates/',
			{'message': 'A technician has been assigned.'},
			format='json',
		)

		self.assertEqual(response.status_code, 201)
		self.assertEqual(OutageUpdate.objects.count(), 1)
		self.assertEqual(response.data['message'], 'A technician has been assigned.')

	def test_outage_update_notifies_reporter_and_saved_area_users(self):
		SavedArea.objects.create(user=self.other_user, area=self.area)
		admin = User.objects.create_superuser(
			username='admin',
			email='admin@example.com',
			password='StrongPass123!',
		)
		self.client.force_authenticate(admin)

		response = self.client.post(
			f'/api/outages/{self.outage.id}/updates/',
			{'message': 'A technician has been assigned.'},
			format='json',
		)

		self.assertEqual(response.status_code, 201)
		self.assertEqual(
			Notification.objects.filter(
				outage=self.outage,
				notification_type='update',
			).count(),
			2,
		)
