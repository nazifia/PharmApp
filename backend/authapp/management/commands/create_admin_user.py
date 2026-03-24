"""
Management command: create_admin_user

Creates either a platform superuser (software owner/developer) or
an organisation-scoped admin user (pharmacy admin).

Usage
─────
# Create platform superuser (sees ALL organisations):
python manage.py create_admin_user --superuser --phone 08000000000 --password "S3cur3P@ss!"

# Create org-scoped admin (sees only their own org's data):
python manage.py create_admin_user --org-slug=green-valley-pharmacy --phone 08011111111 --password "OrgPass123!"

# Interactive mode (prompts for missing values):
python manage.py create_admin_user --superuser
python manage.py create_admin_user --org-slug=my-pharmacy
"""
import getpass

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from authapp.models import Organization

User = get_user_model()


class Command(BaseCommand):
    help = "Create a platform superuser or an organisation-scoped admin user."

    def add_arguments(self, parser):
        group = parser.add_mutually_exclusive_group(required=True)
        group.add_argument(
            "--superuser",
            action="store_true",
            help="Create a platform superuser (no organisation — sees all data).",
        )
        group.add_argument(
            "--org-slug",
            metavar="SLUG",
            help="Org slug to scope the new admin to (e.g. green-valley-pharmacy).",
        )
        parser.add_argument("--phone",    metavar="PHONE",    help="Phone number (login credential).")
        parser.add_argument("--password", metavar="PASSWORD", help="Password (omit to be prompted securely).")

    # ─────────────────────────────────────────────────────────────────────────

    def handle(self, *args, **options):
        phone    = options["phone"]    or self._prompt("Phone number: ")
        password = options["password"] or self._prompt_password()

        if not phone:
            raise CommandError("Phone number is required.")
        if not password:
            raise CommandError("Password is required.")

        if User.objects.filter(phone_number=phone).exists():
            raise CommandError(f"A user with phone number '{phone}' already exists.")

        if options["superuser"]:
            self._create_superuser(phone, password)
        else:
            self._create_org_admin(phone, password, options["org_slug"])

    # ── Creation helpers ──────────────────────────────────────────────────────

    def _create_superuser(self, phone, password):
        user = User.objects.create_superuser(phone_number=phone, password=password)
        self.stdout.write(self.style.SUCCESS(
            f"\n✔  Platform superuser created."
            f"\n   Phone   : {user.phone_number}"
            f"\n   Role    : {user.role}"
            f"\n   Access  : ALL organisations (superuser)"
            f"\n\n   Log in at /admin/ with these credentials."
        ))

    def _create_org_admin(self, phone, password, slug):
        try:
            org = Organization.objects.get(slug=slug)
        except Organization.DoesNotExist:
            existing = ", ".join(
                Organization.objects.values_list("slug", flat=True)[:10]
            )
            raise CommandError(
                f"Organisation with slug '{slug}' not found.\n"
                f"Existing slugs: {existing or '(none)'}"
            )

        user = User.objects.create_user(
            phone_number=phone,
            password=password,
            role="Admin",
        )
        user.is_staff        = True
        user.is_superuser    = False
        user.organization    = org
        user.save()

        self.stdout.write(self.style.SUCCESS(
            f"\n✔  Org-admin user created."
            f"\n   Phone        : {user.phone_number}"
            f"\n   Role         : {user.role}"
            f"\n   Organisation : {org.name}  (slug: {org.slug})"
            f"\n   Access       : {org.name} data only"
            f"\n\n   Log in at /admin/ with these credentials."
        ))

    # ── Private helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _prompt(label):
        return input(label).strip()

    @staticmethod
    def _prompt_password():
        pw  = getpass.getpass("Password: ")
        pw2 = getpass.getpass("Password (again): ")
        if pw != pw2:
            raise CommandError("Passwords do not match.")
        return pw
