from db import get_connection


TABLES = [
    "customer.customers",
    "customer.addresses",
    "customer.customer_events",
    "catalog.categories",
    "catalog.products",
    "catalog.product_prices",
    "orders.orders",
    "orders.order_items",
    "orders.payments",
    "logistics.warehouses",
    "logistics.shipments",
    "logistics.delivery_events",
]


def main():

    with get_connection() as conn:

        with conn.cursor() as cur:

            print("\nTABLE COUNTS")
            print("=" * 50)

            for table in TABLES:

                cur.execute(
                    f"SELECT COUNT(*) FROM {table}"
                )

                count = cur.fetchone()[0]

                print(
                    f"{table:<40} {count:>10}"
                )

            print("\nFOREIGN KEY CHECKS")
            print("=" * 50)

            checks = {
                "orphan addresses": """
                    SELECT COUNT(*)
                    FROM customer.addresses a
                    LEFT JOIN customer.customers c
                        ON a.customer_id = c.customer_id
                    WHERE c.customer_id IS NULL
                """,

                "orphan orders": """
                    SELECT COUNT(*)
                    FROM orders.orders o
                    LEFT JOIN customer.customers c
                        ON o.customer_id = c.customer_id
                    WHERE c.customer_id IS NULL
                """,

                "orphan order items": """
                    SELECT COUNT(*)
                    FROM orders.order_items oi
                    LEFT JOIN orders.orders o
                        ON oi.order_id = o.order_id
                    WHERE o.order_id IS NULL
                """,

                "orphan products": """
                    SELECT COUNT(*)
                    FROM orders.order_items oi
                    LEFT JOIN catalog.products p
                        ON oi.product_id = p.product_id
                    WHERE p.product_id IS NULL
                """,

                "orphan shipments": """
                    SELECT COUNT(*)
                    FROM logistics.shipments s
                    LEFT JOIN orders.orders o
                        ON s.order_id = o.order_id
                    WHERE o.order_id IS NULL
                """,
            }

            for name, query in checks.items():

                cur.execute(query)

                result = cur.fetchone()[0]

                status = "PASS" if result == 0 else "FAIL"

                print(
                    f"{status:<8} {name:<30} {result}"
                )


if __name__ == "__main__":
    main()