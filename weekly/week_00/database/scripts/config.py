import os


# ---------------------------------------------------------
# PostgreSQL connection
# ---------------------------------------------------------

DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT")),
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}


# ---------------------------------------------------------
# Dataset size
# ---------------------------------------------------------

NUM_CUSTOMERS = 500
NUM_ADDRESSES = 750

NUM_CATEGORIES = 20
NUM_PRODUCTS = 100
NUM_PRODUCT_PRICES = 300

NUM_ORDERS = 10_000
NUM_PAYMENTS = 10_000

NUM_CUSTOMER_EVENTS = 20_000

NUM_WAREHOUSES = 10
NUM_SHIPMENTS = 8_000
NUM_DELIVERY_EVENTS = 30_000


# ---------------------------------------------------------
# Reproducibility
# ---------------------------------------------------------

RANDOM_SEED = 100


# ---------------------------------------------------------
# Data generation period
# ---------------------------------------------------------

START_DATE = "2025-01-01"
END_DATE = "2026-08-01"