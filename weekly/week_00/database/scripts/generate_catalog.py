import random
import uuid
from datetime import datetime, timedelta, timezone

from faker import Faker

from config import (
    NUM_CATEGORIES,
    NUM_PRODUCTS,
    NUM_PRODUCT_PRICES,
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


def generate_categories(conn):
    category_ids = []

    categories = [
        "Electronics",
        "Computers",
        "Smartphones",
        "Accessories",
        "Gaming",
        "Home",
        "Kitchen",
        "Furniture",
        "Fashion",
        "Sports",
        "Books",
        "Beauty",
        "Health",
        "Automotive",
        "Toys",
        "Groceries",
        "Office",
        "Pet Supplies",
        "Travel",
        "Outdoor",
    ]

    with conn.cursor() as cur:
        for index, name in enumerate(
            categories[:NUM_CATEGORIES],
            start=1,
        ):
            category_id = uuid.uuid4()

            parent_id = None

            if index > 5:
                parent_id = random.choice(category_ids)

            cur.execute(
                """
                INSERT INTO catalog.categories (
                    category_id,
                    category_name,
                    parent_category_id,
                    created_at
                )
                VALUES (%s, %s, %s, %s)
                """,
                (
                    category_id,
                    name,
                    parent_id,
                    random_datetime(),
                ),
            )

            category_ids.append(category_id)

    return category_ids


def generate_products(conn, category_ids):
    products = []

    brands = [
        "Nova",
        "Vertex",
        "Apex",
        "Orbit",
        "Pulse",
        "Zenith",
        "Nimbus",
        "Quantum",
        "Echo",
        "Vertex Labs",
    ]

    with conn.cursor() as cur:
        for i in range(1, NUM_PRODUCTS + 1):
            product_id = uuid.uuid4()

            cost_price = round(
                random.uniform(10, 1000),
                2,
            )

            launch_date = random_datetime().date()

            products.append(
                (
                    product_id,
                    f"SKU-{i:06d}",
                    fake.catch_phrase(),
                    random.choice(category_ids),
                    random.choice(brands),
                    cost_price,
                    random.choices(
                        [
                            "active",
                            "inactive",
                            "discontinued",
                        ],
                        weights=[85, 10, 5],
                    )[0],
                    launch_date,
                    datetime.combine(
                        launch_date,
                        datetime.min.time(),
                        tzinfo=timezone.utc,
                    ),
                    datetime.combine(
                        launch_date,
                        datetime.min.time(),
                        tzinfo=timezone.utc,
                    ),
                )
            )

        cur.executemany(
            """
            INSERT INTO catalog.products (
                product_id,
                sku,
                product_name,
                category_id,
                brand,
                cost_price,
                status,
                launch_date,
                created_at,
                updated_at
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s
            )
            """,
            products,
        )

    return products


def generate_prices(conn, products):
    prices = []

    for _ in range(NUM_PRODUCT_PRICES):
        product = random.choice(products)

        product_id = product[0]
        cost_price = product[5]

        price = round(
            cost_price * random.uniform(1.15, 2.5),
            2,
        )

        prices.append(
            (
                uuid.uuid4(),
                product_id,
                price,
                "INR",
                random_datetime(),
                None,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO catalog.product_prices (
                product_price_id,
                product_id,
                price,
                currency,
                effective_from,
                effective_to
            )
            VALUES (
                %s, %s, %s, %s, %s, %s
            )
            """,
            prices,
        )


def main():
    with get_connection() as conn:
        category_ids = generate_categories(conn)

        products = generate_products(
            conn,
            category_ids,
        )

        generate_prices(
            conn,
            products,
        )

        conn.commit()

    print("Catalog data generated successfully.")


if __name__ == "__main__":
    main()