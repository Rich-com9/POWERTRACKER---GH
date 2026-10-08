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

## Backend Setup

From the project root:

```powershell
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8001
```

The local API is available at:

```text
http://127.0.0.1:8001/api/
```

For a phone on the same Wi-Fi network, add the computer's LAN IP to `ALLOWED_HOSTS` in `config/settings.py`. Find it with `ipconfig`. Start Django bound to all interfaces:

```text
http://192.168.124.68:8001/api/
```

Allow Python through Windows Firewall on private networks if prompted. The phone and computer must be on the same Wi-Fi network.

Django API documentation:

```text
http://127.0.0.1:8001/api/docs/
```

## Authentication Flow

Users register with a username, email, phone number, and password. Email verification is not required, and they can log in immediately after registration. Login sessions are stored securely on the device and refresh tokens remain valid for 90 days.

If a user forgets their password:

1. They enter their email address.
2. The backend sends a six-digit reset code through the configured email backend. During local development, Django prints the message in the backend terminal.
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

The app defaults to the deployed API at `https://powertracker-gh-3x4s.onrender.com`. Enter only the server origin (scheme, hostname/IP, and port) in `API_HOST`; the app adds `/api` and endpoint paths automatically. To use the local server instead, override it:

```powershell
flutter run --dart-define=API_HOST=http://YOUR_COMPUTER_IP:8001
```

For a deployed HTTPS API, override it when building:

```powershell
flutter build apk --release `
  --dart-define=API_HOST=https://powertracker-gh-3x4s.onrender.com
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
.\.venv\Scripts\python.exe manage.py test
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
- Add the production domain to `ALLOWED_HOSTS` in [settings.py](config/settings.py) and configure CORS origins.
- Use PostgreSQL or another production database instead of SQLite.
- Configure an email backend if password-reset email delivery is needed.
- Configure static and uploaded media file storage.
- Create and use an Android release keystore instead of the debug signing key.
- Configure production Firebase settings for push notifications.
- Apply all Django migrations.
- Set up database backups, logging, and monitoring.

## Security Notes

- Keep [.env](.env), SMTP credentials, Firebase service-account files, signing keys, and production secrets out of version control.
- Rotate any credential that has been exposed.
- Do not use the development LAN API address in a released mobile app.
