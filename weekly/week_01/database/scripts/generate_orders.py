import random
import uuid
from datetime import datetime, timedelta, timezone

from faker import Faker

from config import (
    NUM_ORDERS,
    NUM_PAYMENTS,
    RANDOM_SEED,
    START_DATE,
    END_DATE,
)

from db import get_connection


random.seed(RANDOM_SEED)
fake = Faker()
fake.seed_instance(RANDOM_SEED)


start_date = datetime.fromisoformat(
    START_DATE
).replace(tzinfo=timezone.utc)

end_date = datetime.fromisoformat(
    END_DATE
).replace(tzinfo=timezone.utc)


def random_datetime():
    delta = end_date - start_date

    return start_date + timedelta(
        seconds=random.randint(
            0,
            int(delta.total_seconds()),
        )
    )


def load_ids(conn):
    with conn.cursor() as cur:

        cur.execute(
            """
            SELECT customer_id
            FROM customer.customers
            """
        )

        customer_ids = [
            row[0]
            for row in cur.fetchall()
        ]

        cur.execute(
            """
            SELECT product_id
            FROM catalog.products
            WHERE status = 'active'
            """
        )

        product_ids = [
            row[0]
            for row in cur.fetchall()
        ]

    return customer_ids, product_ids


def generate_orders(conn, customer_ids):
    orders = []

    statuses = [
        "pending",
        "confirmed",
        "processing",
        "shipped",
        "delivered",
        "cancelled",
        "refunded",
    ]

    for i in range(1, NUM_ORDERS + 1):
        order_id = uuid.uuid4()

        timestamp = random_datetime()

        subtotal = round(
            random.uniform(20, 2500),
            2,
        )

        discount = round(
            subtotal * random.uniform(0, 0.2),
            2,
        )

        tax = round(
            (subtotal - discount) * 0.18,
            2,
        )

        shipping = round(
            random.uniform(0, 150),
            2,
        )

        total = round(
            subtotal
            - discount
            + tax
            + shipping,
            2,
        )

        orders.append(
            (
                order_id,
                f"ORD-2026-{i:08d}",
                random.choice(customer_ids),
                timestamp,
                random.choices(
                    statuses,
                    weights=[
                        3,
                        10,
                        10,
                        10,
                        55,
                        8,
                        4,
                    ],
                )[0],
                "INR",
                subtotal,
                discount,
                tax,
                shipping,
                total,
                timestamp,
                timestamp,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO orders.orders (
                order_id,
                order_number,
                customer_id,
                order_timestamp,
                order_status,
                currency,
                subtotal,
                discount_amount,
                tax_amount,
                shipping_amount,
                total_amount,
                created_at,
                updated_at
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s
            )
            """,
            orders,
        )

    return orders


def generate_order_items(
    conn,
    orders,
    product_ids,
):
    order_items = []

    for order in orders:
        order_id = order[0]

        number_of_items = random.randint(1, 5)

        selected_products = random.sample(
            product_ids,
            min(
                number_of_items,
                len(product_ids),
            ),
        )

        for product_id in selected_products:
            quantity = random.randint(1, 5)

            unit_price = round(
                random.uniform(20, 1500),
                2,
            )

            discount = round(
                unit_price
                * quantity
                * random.uniform(0, 0.15),
                2,
            )

            line_total = round(
                unit_price * quantity
                - discount,
                2,
            )

            order_items.append(
                (
                    uuid.uuid4(),
                    order_id,
                    product_id,
                    quantity,
                    unit_price,
                    discount,
                    line_total,
                )
            )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO orders.order_items (
                order_item_id,
                order_id,
                product_id,
                quantity,
                unit_price,
                discount_amount,
                line_total
            )
            VALUES (
                %s, %s, %s, %s,
                %s, %s, %s
            )
            """,
            order_items,
        )


def generate_payments(conn, orders):
    payments = []

    methods = [
        "credit_card",
        "debit_card",
        "upi",
        "net_banking",
        "wallet",
    ]

    for order in orders[:NUM_PAYMENTS]:
        order_id = order[0]
        amount = order[10]
        timestamp = order[3]

        payments.append(
            (
                uuid.uuid4(),
                order_id,
                f"PAY-{uuid.uuid4().hex[:16].upper()}",
                random.choice(methods),
                random.choices(
                    [
                        "successful",
                        "failed",
                        "pending",
                        "refunded",
                    ],
                    weights=[
                        85,
                        5,
                        7,
                        3,
                    ],
                )[0],
                amount,
                timestamp
                + timedelta(
                    minutes=random.randint(
                        1,
                        30,
                    )
                ),
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO orders.payments (
                payment_id,
                order_id,
                payment_reference,
                payment_method,
                payment_status,
                amount,
                payment_timestamp
            )
            VALUES (
                %s, %s, %s, %s,
                %s, %s, %s
            )
            """,
            payments,
        )


def main():
    with get_connection() as conn:

        customer_ids, product_ids = load_ids(
            conn
        )

        orders = generate_orders(
            conn,
            customer_ids,
        )

        generate_order_items(
            conn,
            orders,
            product_ids,
        )

        generate_payments(
            conn,
            orders,
        )

        conn.commit()

    print("Order data generated successfully.")


if __name__ == "__main__":
    main()