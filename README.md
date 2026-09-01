# PowerTracker GH

PowerTracker GH is a mobile application for reporting, tracking, and receiving updates about electricity outages in Ghana.

The project contains:

- A Django REST API backend
- A Flutter mobile application
- JWT authentication
- Password reset by short-lived email code
- Outage reporting with location and images
- Active outage map
- Outage confirmations and restoration updates
- Saved areas and notifications
- User analytics and an admin dashboard

## Project Structure

```text
accounts/          Authentication, profiles, saved areas, password reset
areas/             Ghana regions and service areas
outages/           Outage reports, confirmations, updates, and verification
notifications/     In-app and push notifications
config/             Django project configuration
powertracker_app/   Flutter mobile application
manage.py           Django management entry point
db.sqlite3         Local development database
```

## Requirements

- Python 3.12 or newer
- Flutter SDK
- Dart SDK compatible with `powertracker_app/pubspec.yaml`
- Android Studio or an Android device/emulator for Android development
- A Brevo account for password-reset email delivery

## Backend Setup

From the project root:

```powershell
.\venv\Scripts\Activate.ps1
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

The local API is available at:

```text
http://127.0.0.1:8000/api/
```

For a phone on the same Wi-Fi network, use the computer's LAN address:

```text
http://192.168.70.160:8000/api/
```

Django API documentation:

```text
http://127.0.0.1:8000/api/docs/
```

## Brevo Email Configuration

The backend reads email configuration from environment variables. The project does not automatically load `.env` files, so set the variables in the same PowerShell window used to start Django.

Use a Brevo SMTP key, not your Brevo account password:

```powershell
$env:EMAIL_BACKEND="django.core.mail.backends.smtp.EmailBackend"
$env:EMAIL_HOST="smtp-relay.brevo.com"
$env:EMAIL_PORT="587"
$env:EMAIL_USE_TLS="true"
$env:EMAIL_HOST_USER="your-brevo-account-email"
$env:EMAIL_HOST_PASSWORD="your-brevo-smtp-key"
$env:DEFAULT_FROM_EMAIL="your-verified-brevo-sender@example.com"

.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

The sender address must be verified in Brevo. Never commit SMTP keys. The example configuration is in [.env.example](.env.example), while [config/settings.py](config/settings.py) reads the values.

## Authentication Flow

Users register with a username, email, phone number, and password. They can log in immediately after registration.

If a user forgets their password:

1. They enter their email address.
2. The backend sends a six-digit reset code through Brevo.
3. The code expires after 10 minutes.
4. The user enters the code and a new password.
5. The code is invalidated after successful use.

Reset codes are hashed in the database and limited to five verification attempts. Reset requests use a generic response to avoid revealing whether an account exists.

## Flutter Setup

From the Flutter project directory:

```powershell
Set-Location powertracker_app
flutter pub get
flutter run
```

The development API address is configured in [api_constants.dart](powertracker_app/lib/core/constants/api_constants.dart).

For a deployed HTTPS API, override it when building:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.example.com/api
```

Release builds require an HTTPS API URL.

## API Endpoints

The API is mounted under `/api/`.

### Authentication

- `POST /api/auth/register/`
- `POST /api/auth/token/`
- `POST /api/auth/token/refresh/`
- `GET/PATCH /api/auth/profile/`
- `POST /api/auth/change-password/`
- `POST /api/auth/password-reset/request/`
- `POST /api/auth/password-reset/confirm/`
- `GET/POST /api/auth/saved-areas/`
- `DELETE /api/auth/saved-areas/<id>/`
- `GET /api/auth/analytics/`
- `GET /api/auth/admin/dashboard/`

### Areas

- `GET /api/areas/`
- `GET /api/areas/<id>/`

### Outages

- `GET/POST /api/outages/`
- `GET /api/outages/<id>/`
- `GET /api/outages/active/`
- `GET /api/outages/latest/`
- Outage confirmation, restoration, verification, and admin update endpoints are documented at `/api/docs/`.

### Notifications

- `GET /api/notifications/`
- `PUT /api/notifications/<id>/read/`
- Device-token registration for push notifications

## Testing

Run Django tests:

```powershell
.\venv\Scripts\python.exe manage.py test
```

Run Flutter analysis and tests:

```powershell
Set-Location powertracker_app
flutter analyze
flutter test
```

## Production Checklist

Before publishing the app:

- Deploy Django to a production host.
- Use a real HTTPS API domain instead of the local LAN address.
- Set `DJANGO_DEBUG=false`.
- Set a strong `DJANGO_SECRET_KEY`.
- Configure production `DJANGO_ALLOWED_HOSTS` and CORS origins.
- Use PostgreSQL or another production database instead of SQLite.
- Configure Brevo SMTP with a verified sender.
- Configure static and uploaded media file storage.
- Create and use an Android release keystore instead of the debug signing key.
- Configure production Firebase settings for push notifications.
- Apply all Django migrations.
- Set up database backups, logging, and monitoring.

## Deploying the API to Render

The repository includes [render.yaml](render.yaml), which defines a Django web service and a Render Postgres database.

1. Push the project to a GitHub repository.
2. In Render, choose **New > Blueprint** and connect the repository.
3. Render will read `render.yaml`, install dependencies, collect static files, run migrations, and start Gunicorn.
4. In the Render service settings, set these secret or service-specific values:

   ```text
   EMAIL_HOST_USER
   EMAIL_HOST_PASSWORD
   DEFAULT_FROM_EMAIL
   CORS_ALLOWED_ORIGINS
   FIREBASE_CREDENTIALS_PATH
   ```

5. Verify the Brevo sender before testing password reset.
6. Open the generated Render URL followed by `/api/docs/` to verify the API.

The generated API address will look like:

```text
https://powertracker-api.onrender.com/api/
```

Use that URL when building Flutter for release:

```powershell
Set-Location powertracker_app
flutter build apk --release `
  --dart-define=API_BASE_URL=https://powertracker-api.onrender.com/api
```

Render's local filesystem is not permanent. Configure persistent object storage for uploaded outage images before production use.

## Security Notes

- Keep `.env`, SMTP keys, Firebase service-account files, signing keys, and production secrets out of version control.
- Rotate any credential that has been exposed.
- Do not use the development LAN API address in a released mobile app.
- Do not use Django's console email backend in production.
