from django.db import migrations


GHANA_REGIONAL_AREAS = [
    ('Kumasi Central', 'Ashanti'),
    ('Goaso Central', 'Ahafo'),
    ('Sunyani Central', 'Bono'),
    ('Techiman Central', 'Bono East'),
    ('Cape Coast Central', 'Central'),
    ('Dambai Central', 'Oti'),
    ('Koforidua Central', 'Eastern'),
    ('Bolgatanga Central', 'Upper East'),
    ('Wa Central', 'Upper West'),
    ('Tamale Central', 'Northern'),
    ('Damongo Central', 'Savannah'),
    ('Nalerigu Central', 'North East'),
    ('Ho Central', 'Volta'),
    ('Takoradi Central', 'Western'),
    ('Sefwi Wiawso Central', 'Western North'),
]


def add_ghana_regions(apps, schema_editor):
    Area = apps.get_model('areas', 'Area')

    for name, region in GHANA_REGIONAL_AREAS:
        Area.objects.get_or_create(
            name=name,
            region=region,
            defaults={'active_outage_count': 0},
        )


def remove_ghana_regions(apps, schema_editor):
    Area = apps.get_model('areas', 'Area')
    Area.objects.filter(
        name__in=[name for name, region in GHANA_REGIONAL_AREAS],
        region__in=[region for name, region in GHANA_REGIONAL_AREAS],
    ).delete()


class Migration(migrations.Migration):
    dependencies = [
        ('areas', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(
            add_ghana_regions,
            remove_ghana_regions,
        ),
    ]
