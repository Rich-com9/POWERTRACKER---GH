import logging
import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, messaging

from .models import DeviceToken


logger = logging.getLogger(__name__)


def _firebase_app():
    if firebase_admin._apps:
        return firebase_admin.get_app()

    credentials_path = os.environ.get('FIREBASE_CREDENTIALS_PATH')
    if not credentials_path:
        logger.info('Firebase push disabled: credentials path is not configured.')
        return None

    path = Path(credentials_path)
    if not path.is_file():
        logger.warning('Firebase push disabled: credentials file was not found.')
        return None

    return firebase_admin.initialize_app(
        credentials.Certificate(str(path))
    )


def send_push_notification(*, user, title, message, notification_type, outage_id=None):
    app = _firebase_app()
    if app is None:
        return

    tokens = list(DeviceToken.objects.filter(user=user).values_list('token', flat=True))
    if not tokens:
        return

    data = {'type': notification_type}
    if outage_id is not None:
        data['outage_id'] = str(outage_id)

    for token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=message,
                    ),
                    data=data,
                    token=token,
                ),
                app=app,
            )
        except Exception:
            logger.exception('Unable to send push notification to a device token.')
