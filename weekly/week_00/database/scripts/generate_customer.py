import json
import random
import uuid
from datetime import datetime, timedelta, timezone

from faker import Faker
from psycopg.rows import tuple_row

from config import (
    DB_CONFIG,
    NUM_CUSTOMERS,
    NUM_ADDRESSES,
    NUM_CUSTOMER_EVENTS,
    RANDOM_SEED,
    START_DATE,
    END_DATE,
)
from db import get_connection


random.seed(RANDOM_SEED)

fake = Faker()
fake.seed_instance(RANDOM_SEED)


def random_datetime(start, end):
    delta = end - start
    return start + timedelta(
        seconds=random.randint(0, int(delta.total_seconds()))
    )


start_date = datetime.fromisoformat(
    START_DATE
).replace(tzinfo=timezone.utc)

end_date = datetime.fromisoformat(
    END_DATE
).replace(tzinfo=timezone.utc)


def generate_customers(conn):
    customers = []

    for i in range(1, NUM_CUSTOMERS + 1):
        customer_id = uuid.uuid4()

        signup_date = random_datetime(start_date, end_date)

        customers.append(
            (
                customer_id,
                f"CUST-{i:06d}",
                fake.first_name(),
                fake.last_name(),
                fake.unique.email(),
                fake.phone_number(),
                fake.date_of_birth(
                    minimum_age=18,
                    maximum_age=70,
                ),
                signup_date,
                fake.country(),
                random.choices(
                    ["active", "inactive", "suspended"],
                    weights=[90, 8, 2],
                )[0],
                signup_date,
                signup_date,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO customer.customers (
                customer_id,
                customer_code,
                first_name,
                last_name,
                email,
                phone,
                date_of_birth,
                signup_date,
                country,
                customer_status,
                created_at,
                updated_at
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s
            )
            """,
            customers,
        )

    return [row[0] for row in customers]


def generate_addresses(conn, customer_ids):
    addresses = []

    address_types = [
        "home",
        "work",
        "billing",
        "shipping",
    ]

    for i in range(NUM_ADDRESSES):
        customer_id = random.choice(customer_ids)

        created_at = random_datetime(
            start_date,
            end_date,
        )

        addresses.append(
            (
                uuid.uuid4(),
                customer_id,
                random.choice(address_types),
                fake.street_address(),
                fake.city(),
                fake.state(),
                fake.postcode(),
                fake.country(),
                random.random() < 0.3,
                created_at,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO customer.addresses (
                address_id,
                customer_id,
                address_type,
                address_line_1,
                city,
                state,
                postal_code,
                country,
                is_default,
                created_at
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s
            )
            """,
            addresses,
        )


def generate_events(conn, customer_ids):
    events = []

    event_types = [
        "login",
        "product_view",
        "search",
        "add_to_cart",
        "checkout_started",
        "purchase",
        "logout",
    ]

    devices = [
        "mobile",
        "desktop",
        "tablet",
    ]

    platforms = [
        "web",
        "android",
        "ios",
    ]

    for _ in range(NUM_CUSTOMER_EVENTS):
        customer_id = random.choice(customer_ids)

        event_time = random_datetime(
            start_date,
            end_date,
        )

        events.append(
            (
                uuid.uuid4(),
                customer_id,
                random.choice(event_types),
                event_time,
                uuid.uuid4(),
                random.choice(devices),
                random.choice(platforms),
                json.dumps(
                    {
                        "source": random.choice(
                            ["organic", "paid", "direct", "referral"]
                        )
                    }
                ),
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO customer.customer_events (
                event_id,
                customer_id,
                event_type,
                event_timestamp,
                session_id,
                device_type,
                platform,
                metadata
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s
            )
            """,
            events,
        )


def main():
    with get_connection() as conn:
        customer_ids = generate_customers(conn)

        generate_addresses(
            conn,
            customer_ids,
        )

        generate_events(
            conn,
            customer_ids,
        )

        conn.commit()

    print("Customer data generated successfully.")


if __name__ == "__main__":
    main()