from django.contrib.auth import get_user_model
from django.core import mail
from django.test import override_settings
from django.test import TestCase
from datetime import timedelta
from django.utils import timezone
from rest_framework.test import APIClient
from unittest.mock import patch

from areas.models import Area
from outages.models import OutageReport
from accounts.models import EmailVerificationCode
import re


User = get_user_model()


class AccountApiTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username='tester',
			email='tester@example.com',
			password='StrongPass123!',
			name='Test User',
			phone='0200000000',
		)
		self.user.is_verified = True
		self.user.email_verified_at = timezone.now()
		self.user.save(update_fields=['is_verified', 'email_verified_at'])
		self.area = Area.objects.create(
			name='Kumasi Central',
			region='Ashanti',
		)
		self.client = APIClient()
		self.client.force_authenticate(self.user)

	def test_profile_can_be_updated(self):
		response = self.client.patch(
			'/api/auth/profile/',
			{
				'name': 'Updated User',
				'phone': '0240000000',
			},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.user.refresh_from_db()
		self.assertEqual(self.user.name, 'Updated User')
		self.assertEqual(self.user.phone, '0240000000')

	def test_password_can_be_changed_with_current_password(self):
		response = self.client.post(
			'/api/auth/change-password/',
			{
				'current_password': 'StrongPass123!',
				'new_password': 'NewStrongPass456!',
				'confirm_password': 'NewStrongPass456!',
			},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.user.refresh_from_db()
		self.assertTrue(self.user.check_password('NewStrongPass456!'))

	def test_password_change_rejects_wrong_current_password(self):
		response = self.client.post(
			'/api/auth/change-password/',
			{
				'current_password': 'WrongPassword123!',
				'new_password': 'NewStrongPass456!',
				'confirm_password': 'NewStrongPass456!',
			},
			format='json',
		)

		self.assertEqual(response.status_code, 400)

	@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
	def test_password_reset_request_sends_email(self):
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/password-reset/request/',
			{'email': self.user.email},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertEqual(len(mail.outbox), 1)
		self.assertRegex(mail.outbox[0].body, r'\b\d{6}\b')

	def test_password_reset_confirm_changes_password(self):
		self.client.force_authenticate(user=None)
		self.client.post(
			'/api/auth/password-reset/request/',
			{'email': self.user.email},
			format='json',
		)
		code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)
		response = self.client.post(
			'/api/auth/password-reset/confirm/',
			{
				'email': self.user.email,
				'code': code,
				'new_password': 'ResetStrong789!',
				'confirm_password': 'ResetStrong789!',
			},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.user.refresh_from_db()
		self.assertTrue(self.user.check_password('ResetStrong789!'))

	@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
	def test_password_reset_request_is_generic_for_unknown_email(self):
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/password-reset/request/',
			{'email': 'unknown@example.com'},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertEqual(
			response.data['message'],
			'If an eligible account exists, a code has been sent.',
		)
		self.assertEqual(len(mail.outbox), 0)

	def test_password_reset_code_is_one_time(self):
		self.client.force_authenticate(user=None)
		self.client.post(
			'/api/auth/password-reset/request/',
			{'email': self.user.email},
			format='json',
		)
		code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)
		payload = {
			'email': self.user.email,
			'code': code,
			'new_password': 'ResetStrong789!',
			'confirm_password': 'ResetStrong789!',
		}
		first_response = self.client.post(
			'/api/auth/password-reset/confirm/', payload, format='json'
		)
		second_response = self.client.post(
			'/api/auth/password-reset/confirm/', payload, format='json'
		)

		self.assertEqual(first_response.status_code, 200)
		self.assertEqual(second_response.status_code, 400)

	def test_expired_password_reset_code_is_rejected(self):
		self.client.force_authenticate(user=None)
		self.client.post(
			'/api/auth/password-reset/request/',
			{'email': self.user.email},
			format='json',
		)
		code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)
		verification = EmailVerificationCode.objects.get(
			user=self.user,
			purpose=EmailVerificationCode.PASSWORD_RESET,
		)
		verification.expires_at = timezone.now() - timedelta(minutes=1)
		verification.save(update_fields=['expires_at'])

		response = self.client.post(
			'/api/auth/password-reset/confirm/',
			{
				'email': self.user.email,
				'code': code,
				'new_password': 'ResetStrong789!',
				'confirm_password': 'ResetStrong789!',
			},
			format='json',
		)

		self.assertEqual(response.status_code, 400)

	def test_analytics_returns_outage_metrics(self):
		response = self.client.get('/api/auth/analytics/')

		self.assertEqual(response.status_code, 200)
		self.assertEqual(response.data['total_outages'], 0)
		self.assertEqual(response.data['active_outages'], 0)
		self.assertIsNone(response.data['most_affected_area'])

	def test_analytics_only_counts_current_users_outages(self):
		other_user = User.objects.create_user(
			username='other',
			email='other@example.com',
			password='StrongPass123!',
		)
		OutageReport.objects.create(
			reported_by=self.user,
			area=self.area,
			latitude=6.6885,
			longitude=-1.6244,
			outage_type='unplanned',
		)
		OutageReport.objects.create(
			reported_by=other_user,
			area=self.area,
			latitude=6.6890,
			longitude=-1.6250,
			outage_type='unplanned',
		)

		response = self.client.get('/api/auth/analytics/')

		self.assertEqual(response.status_code, 200)
		self.assertEqual(response.data['total_outages'], 1)
		self.assertEqual(response.data['active_outages'], 1)

	def test_saved_area_can_be_created_and_listed(self):
		create_response = self.client.post(
			'/api/auth/saved-areas/',
			{'area': self.area.id},
			format='json',
		)
		list_response = self.client.get('/api/auth/saved-areas/')

		self.assertEqual(create_response.status_code, 201)
		self.assertEqual(list_response.status_code, 200)
		self.assertEqual(len(list_response.data), 1)
		self.assertEqual(list_response.data[0]['area_name'], 'Kumasi Central')

	def test_login_does_not_require_verification(self):
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/token/',
			{'email': self.user.email, 'password': 'StrongPass123!'},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_legacy_account_without_phone_can_still_log_in(self):
		self.user.phone = ''
		self.user.phone_verified = False
		self.user.save(update_fields=['phone', 'phone_verified'])
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/token/',
			{'email': self.user.email, 'password': 'StrongPass123!'},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_verified_user_can_log_in(self):
		self.user.phone_verified = True
		self.user.save(update_fields=['phone_verified'])
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/token/',
			{'email': self.user.email, 'password': 'StrongPass123!'},
			format='json',
		)

		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_registration_creates_account_that_can_log_in_immediately(self):
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/register/',
			{
				'username': 'new-user',
				'name': 'New User',
				'email': 'new@example.com',
				'phone': '0240000000',
				'password': 'StrongPass123!',
			},
			format='json',
		)
		self.assertEqual(response.status_code, 201)
		user = User.objects.get(email='new@example.com')
		self.assertFalse(user.is_verified)
		response = self.client.post(
			'/api/auth/token/',
			{'email': user.email, 'password': 'StrongPass123!'},
			format='json',
		)
		self.assertEqual(response.status_code, 200)
		self.assertIn('access', response.data)

	def test_login_rejects_incorrect_credentials_with_clear_message(self):
		self.client.force_authenticate(user=None)
		response = self.client.post(
			'/api/auth/token/',
			{'email': self.user.email, 'password': 'WrongPassword123!'},
			format='json',
		)

		self.assertEqual(response.status_code, 401)
		self.assertEqual(
			response.data['detail'],
			'Incorrect username/email or password.',
		)

