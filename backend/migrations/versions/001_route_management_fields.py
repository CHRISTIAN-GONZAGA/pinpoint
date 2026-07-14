"""Add vehicle_type, fares, and stop description for route management.

Revision ID: 001_route_mgmt
Revises:
Create Date: 2026-07-14
"""

from alembic import op
import sqlalchemy as sa


revision = "001_route_mgmt"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
  with op.batch_alter_table("jeepney_routes") as batch:
    batch.add_column(
      sa.Column("vehicle_type", sa.String(length=30), nullable=False, server_default="jeepney")
    )
    batch.add_column(sa.Column("base_fare", sa.Float(), nullable=True))
    batch.add_column(sa.Column("additional_fare", sa.Float(), nullable=True))

  with op.batch_alter_table("route_stops") as batch:
    batch.add_column(sa.Column("description", sa.Text(), nullable=True))


def downgrade() -> None:
  with op.batch_alter_table("route_stops") as batch:
    batch.drop_column("description")

  with op.batch_alter_table("jeepney_routes") as batch:
    batch.drop_column("additional_fare")
    batch.drop_column("base_fare")
    batch.drop_column("vehicle_type")
