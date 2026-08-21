import random
import uuid
from datetime import timedelta

from faker import Faker

from config import (
    NUM_WAREHOUSES,
    NUM_SHIPMENTS,
    NUM_DELIVERY_EVENTS,
    RANDOM_SEED,
)

from db import get_connection


random.seed(RANDOM_SEED)
fake = Faker()
fake.seed_instance(RANDOM_SEED)


def generate_warehouses(conn):
    warehouses = []

    for i in range(1, NUM_WAREHOUSES + 1):
        warehouses.append(
            (
                uuid.uuid4(),
                f"WH-{i:03d}",
                f"{fake.city()} Fulfillment Center",
                fake.city(),
                fake.state(),
                fake.country(),
                random.randint(
                    10_000,
                    100_000,
                ),
                fake.date_time_between(
                    start_date="-2y",
                    end_date="now",
                ),
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO logistics.warehouses (
                warehouse_id,
                warehouse_code,
                warehouse_name,
                city,
                state,
                country,
                capacity,
                created_at
            )
            VALUES (
                %s, %s, %s, %s,
                %s, %s, %s, %s
            )
            """,
            warehouses,
        )

    return [row[0] for row in warehouses]


def load_orders(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                order_id,
                order_timestamp,
                order_status
            FROM orders.orders
            WHERE order_status IN (
                'confirmed',
                'processing',
                'shipped',
                'delivered'
            )
            ORDER BY random()
            LIMIT %s
            """,
            (NUM_SHIPMENTS,),
        )

        return cur.fetchall()


def generate_shipments(
    conn,
    orders,
    warehouse_ids,
):
    shipments = []

    for i, order in enumerate(
        orders,
        start=1,
    ):
        order_id = order[0]
        order_time = order[1]
        order_status = order[2]

        shipped_at = order_time + timedelta(
            hours=random.randint(4, 72)
        )

        estimated_delivery = (
            shipped_at
            + timedelta(
                days=random.randint(1, 7)
            )
        )

        delivered_at = None

        if order_status == "delivered":
            delivered_at = (
                estimated_delivery
                + timedelta(
                    hours=random.randint(
                        -24,
                        48,
                    )
                )
            )

        if delivered_at:
            shipment_status = "delivered"
        else:
            shipment_status = random.choice(
                [
                    "created",
                    "packed",
                    "shipped",
                    "in_transit",
                    "out_for_delivery",
                ]
            )

        shipments.append(
            (
                uuid.uuid4(),
                order_id,
                random.choice(warehouse_ids),
                f"TRK-{uuid.uuid4().hex[:18].upper()}",
                random.choice(
                    [
                        "Delhivery",
                        "BlueDart",
                        "DHL",
                        "FedEx",
                        "Ecom Express",
                    ]
                ),
                shipment_status,
                shipped_at,
                estimated_delivery,
                delivered_at,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO logistics.shipments (
                shipment_id,
                order_id,
                warehouse_id,
                tracking_number,
                carrier,
                shipment_status,
                shipped_at,
                estimated_delivery_at,
                delivered_at
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s
            )
            """,
            shipments,
        )

    return shipments


def generate_delivery_events(
    conn,
    shipments,
):
    events = []

    event_types = [
        "shipment_created",
        "picked_up",
        "in_transit",
        "arrived_at_hub",
        "out_for_delivery",
        "delivered",
    ]

    for _ in range(NUM_DELIVERY_EVENTS):
        shipment = random.choice(shipments)

        shipment_id = shipment[0]

        base_time = shipment[6]

        event_time = (
            base_time
            + timedelta(
                hours=random.randint(
                    0,
                    120,
                )
            )
        )

        events.append(
            (
                uuid.uuid4(),
                shipment_id,
                random.choice(event_types),
                event_time,
                fake.city(),
                random.choice(
                    [
                        "Package processed",
                        "Package moving through network",
                        "Package arrived at facility",
                        "Package handed to carrier",
                        None,
                    ]
                ),
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO logistics.delivery_events (
                delivery_event_id,
                shipment_id,
                event_type,
                event_timestamp,
                location,
                remarks
            )
            VALUES (
                %s, %s, %s, %s, %s, %s
            )
            """,
            events,
        )


def main():
    with get_connection() as conn:

        warehouse_ids = generate_warehouses(
            conn
        )

        orders = load_orders(conn)

        shipments = generate_shipments(
            conn,
            orders,
            warehouse_ids,
        )

        generate_delivery_events(
            conn,
            shipments,
        )

        conn.commit()

    print("Logistics data generated successfully.")


if __name__ == "__main__":
    main()