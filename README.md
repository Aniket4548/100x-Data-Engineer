# 100x Data Engineer — 52-Week Master Syllabus

### The rules

Every week follows the same cycle:

**READ → UNDERSTAND → CODE → PRACTICE → BUILD → DOCUMENT → PUBLISH**

A week is **not complete because you watched a course**.

You should be able to:

1. Explain the concept without notes.
2. Write code without copying.
3. Debug a broken implementation.
4. Explain trade-offs.
5. Explain when *not* to use the technology.
6. Add the work to GitHub.
7. Write a short weekly learning post.

### Weekly time target

**6–8 hours/week**

A heavy work week can become **3–4 hours**. Do not compensate by trying to study 5 hours every night the following week.

---

# PHASE 0 — Baseline

## Week 0 — The starting point

### READ

Understand:

* What Data Engineering actually encompasses
* OLTP vs OLAP
* ETL vs ELT
* Data warehouse vs data lake
* Lakehouse
* Batch vs streaming
* Data platform vs BI platform
* Modern AI/data architecture

### UNDERSTAND

Answer:

> What does a modern Data Engineer actually own?

> Where does my current SQL/Power BI work fit?

> What skills am I missing?

### CODE / SETUP

Create:

```text
100x-data-engineer/
│
├── README.md
├── weekly/
├── sql/
├── python/
├── dbt/
├── airflow/
├── spark/
├── cloud/
├── lakehouse/
├── kafka/
├── ai/
└── projects/
```

Set up:

* Git
* GitHub
* Python
* VS Code
* Docker
* PostgreSQL
* DuckDB

### PRACTICE

Create a baseline assessment:

* 20 SQL questions
* 5 Python problems
* 1 ETL script
* 1 data-modeling exercise

Record your scores.

### BUILD

Your public roadmap.

### PUBLISH

**100x Data Engineer — Week 0**

---

# PHASE 1 — SQL + DATABASE ENGINEERING

You already know SQL. Therefore we're going beyond syntax.

## Week 1 — Window Functions

### READ

* `OVER`
* `PARTITION BY`
* `ORDER BY`
* Window frames

### UNDERSTAND

* `ROW_NUMBER`
* `RANK`
* `DENSE_RANK`
* `LAG`
* `LEAD`
* Running totals
* Moving averages

### CODE

Write 20–25 queries.

### PRACTICE

* Latest record per customer
* Top N per category
* Employee ranking
* Month-over-month growth
* Running revenue
* Consecutive events

### BUILD

Sales analytics query pack.

### PUBLISH

"What I finally understood about window functions."

---

## Week 2 — Advanced SQL

### READ / UNDERSTAND

* CTEs
* Recursive CTEs
* Correlated subqueries
* `EXISTS`
* `NOT EXISTS`
* Set operators
* Conditional aggregation
* `MERGE`
* Upsert patterns

### CODE

30 problems.

### PRACTICE

Real-world transformation problems rather than interview-only puzzles.

### BUILD

Hierarchical employee/category analysis + incremental upsert.

---

## Week 3 — Data Modeling

### UNDERSTAND

* Table grain
* Facts
* Dimensions
* Star schema
* Snowflake schema
* Surrogate keys
* Natural keys
* Degenerate dimensions
* Role-playing dimensions

### SCD

* Type 0
* Type 1
* Type 2
* Type 3

### CODE

Design a sales warehouse.

### PRACTICE

Take messy operational tables and turn them into a dimensional model.

### BUILD

A small star schema in PostgreSQL.

---

## Week 4 — Indexes

### UNDERSTAND

* Why indexes exist
* B-tree
* Hash indexes
* Composite indexes
* Covering indexes
* Selectivity
* Cardinality

### CODE

Create and remove indexes.

### PRACTICE

Benchmark queries:

```text
No index
Single-column index
Composite index
Covering index
```

### BUILD

Index-performance case study.

---

## Week 5 — Query Execution

### UNDERSTAND

* Query planner
* Execution plan
* Sequential scan
* Index scan
* Bitmap scan
* Nested-loop join
* Hash join
* Merge join
* Sort
* Cardinality estimation

### CODE

Run `EXPLAIN` / `EXPLAIN ANALYZE`.

### PRACTICE

Take 10 deliberately bad queries and optimize them.

### BUILD

Before/after optimization report.

---

## Week 6 — Transactions & Concurrency

### UNDERSTAND

* ACID
* Transactions
* Commit / rollback
* Isolation levels
* Dirty read
* Non-repeatable read
* Phantom read
* Locks
* Deadlocks
* MVCC

### CODE

Open concurrent PostgreSQL sessions.

### PRACTICE

Create and reproduce:

* dirty-read scenarios
* blocking
* deadlocks

### BUILD

Transaction/concurrency lab.

---

## Week 7 — Database Engineering

### UNDERSTAND

* Views
* Materialized views
* Stored procedures
* Temporary tables
* Partitioning
* Constraints
* Foreign keys
* Check constraints

### PRACTICE

When should each object be used?

### BUILD

Production-style PostgreSQL database.

---

## Week 8 — SQL Project

Build:

```text
Raw
 ↓
Staging
 ↓
Transformation
 ↓
Dimensional Model
 ↓
Analytical SQL
```

Include:

* SCD2
* indexes
* constraints
* optimization
* documentation

### OUTPUT

**Project 1: Analytics Warehouse**

---

# PHASE 2 — PYTHON FOR DATA ENGINEERING

## Week 9 — Python Internals

### Understand

* Objects
* References
* Mutable vs immutable
* Scope
* Functions
* Modules
* Packages
* Virtual environments

### Code

Write small experiments demonstrating each concept.

### Practice

Debug intentionally broken Python code.

---

## Week 10 — Pythonic Programming

### Understand

* comprehensions
* iterators
* generators
* decorators
* context managers
* closures
* `*args`
* `**kwargs`

### Code

Build your own:

* generator
* decorator
* context manager

### Practice

Rewrite inefficient code using idiomatic Python.

---

## Week 11 — OOP

### Understand

* Classes
* Composition
* Inheritance
* Abstract classes
* Dataclasses
* SOLID
* Dependency injection

### Important

Learn **when OOP helps and when it is unnecessary**.

### Build

Reusable ingestion framework.

---

## Week 12 — Type Safety

### Learn

* Type hints
* `typing`
* Pydantic
* Dataclasses
* Validation
* Static analysis

### Build

Typed API ingestion package.

---

## Week 13 — Errors, Logging & Reliability

### Understand

* Exceptions
* Custom exceptions
* Logging
* Structured logging
* Retry
* Backoff
* Idempotency

### Build

A pipeline that survives:

* API failure
* timeout
* malformed response
* duplicate request

---

## Week 14 — APIs

### Understand

* HTTP
* REST
* GET/POST/PUT/PATCH/DELETE
* Status codes
* Authentication
* OAuth
* Pagination
* Rate limits
* Retries
* Webhooks
* Idempotency

### Build

```text
API → Python → PostgreSQL
```

---

## Week 15 — Testing

### Learn

* pytest
* unit tests
* integration tests
* fixtures
* mocking
* coverage

### Practice

Test your API pipeline.

---

## Week 16 — Python Data Stack

### Learn

* PyArrow
* Pandas
* Polars
* SQLAlchemy
* HTTPX
* AsyncIO

### Compare

```text
Pandas
vs
Polars
vs
DuckDB
```

### Build

A batch transformation pipeline using Arrow/Parquet.

---

# PHASE 3 — FILE FORMATS + LOCAL DATA SYSTEMS

This phase is deliberately local and cheap.

## Week 17 — Data Storage Concepts

### Understand

* Filesystem
* Block storage
* File storage
* Object storage
* Objects
* Metadata
* Keys/prefixes

---

## Week 18 — Serialization

### Learn

* CSV
* JSON
* JSON Lines
* Avro
* Schema
* Serialization
* Deserialization
* Compression

### Practice

Compare file size and read/write characteristics.

---

## Week 19 — Parquet

This is important.

### Understand

* Columnar storage
* Row groups
* Column chunks
* Statistics
* Encoding
* Compression
* Predicate pushdown

### Code

Generate Parquet files.

Inspect metadata.

Compare:

```text
CSV
vs
Parquet
```

---

## Week 20 — DuckDB

### Learn

* Analytical execution
* Vectorized execution
* SQL over files
* External tables
* Parquet scanning

### Build

Query 10M+ rows without loading the full dataset into a traditional database.

---

## Week 21 — Arrow & Polars

### Understand

Why columnar memory matters.

### Practice

Run the same workload:

```text
Pandas
Polars
DuckDB
```

Compare:

* memory
* speed
* developer experience

---

## Week 22 — Project 2

Build:

```text
API
 ↓
Python
 ↓
Parquet
 ↓
DuckDB
 ↓
dbt
 ↓
PostgreSQL
 ↓
Power BI
```

This becomes your first **modern local data platform**.

---

# PHASE 4 — ENGINEERING TOOLING

## Week 23 — Git

Learn deeply:

* branches
* merge
* rebase
* conflicts
* cherry-pick
* tags
* releases
* pull requests
* commit hygiene

---

## Week 24 — Linux

Learn:

* processes
* memory
* CPU
* filesystems
* permissions
* environment variables
* SSH

Commands:

```text
grep
awk
sed
curl
ps
top
htop
find
xargs
```

---

## Week 25 — Docker Fundamentals

### Understand

* Image
* Container
* Dockerfile
* Layer
* Registry
* Volume
* Network

---

## Week 26 — Docker Compose

Build:

```text
Python
+
PostgreSQL
+
dbt
```

as containers.

---

## Week 27 — CI/CD

Learn GitHub Actions:

```text
git push
 ↓
lint
 ↓
test
 ↓
build
 ↓
Docker image
```

---

## Week 28 — Engineering Upgrade

Take Project 2 and add:

* Docker
* testing
* logging
* CI/CD
* environment configuration

Now you have a **production-style portfolio project**.

---

# PHASE 5 — DBT + DATA MODELING

You already have dbt exposure, so we're going deeper.

## Week 29 — dbt Architecture

Learn:

* project structure
* sources
* models
* seeds
* tests
* documentation
* lineage

---

## Week 30 — Data Modeling in dbt

Learn:

* staging
* intermediate
* marts
* grain
* naming
* modular transformations

### Build

Refactor your previous transformation layer into dbt.

---

## Week 31 — Advanced dbt

Learn:

* Jinja
* macros
* variables
* packages
* hooks
* incremental models
* snapshots

---

## Week 32 — Production dbt

Learn:

* environments
* CI
* testing
* data contracts
* exposures
* documentation
* model governance
* lineage

This is particularly important because AI-assisted data development is increasing the output of analytics teams while concerns about correctness and governance remain high. dbt's 2026 research reports 72% prioritizing AI-assisted coding while 71% remain concerned about incorrect/hallucinated data reaching stakeholders. ([dbt Labs][3])

### Build

**Project 3 — Production dbt Analytics Platform**

---

# PHASE 6 — ORCHESTRATION

## Week 33 — Airflow Architecture

Understand:

* DAG
* Scheduler
* Worker
* Executor
* Metadata database
* API server
* Task SDK

Current Airflow 3 documentation explicitly emphasizes the Task SDK as the primary interface for DAG/task authoring. ([Apache Airflow][4])

---

## Week 34 — DAGs

Learn:

* DAG definition
* Tasks
* Dependencies
* Operators
* TaskFlow API
* Dynamic task mapping

### Build

Basic API ingestion DAG.

---

## Week 35 — Production Airflow

Learn:

* retries
* timeouts
* sensors
* XCom
* connections
* secrets
* logging
* scheduling
* catchup
* backfills

---

## Week 36 — Airflow Project

Build:

```text
Airflow
 ↓
API
 ↓
Parquet
 ↓
dbt
 ↓
PostgreSQL
```

Requirements:

* retries
* failure handling
* backfill
* logging
* data-quality checks

Airflow's current tutorials explicitly cover workflows, TaskFlow, data pipelines, object storage and human-in-the-loop workflows. ([Apache Airflow][5])

---

# PHASE 7 — CLOUD

Now we touch AWS.

And this is where we follow your earlier point:

**You are not "learning AWS."**

You are learning specific infrastructure capabilities.

---

## Week 37 — Cloud Fundamentals

Understand:

* Region
* Availability Zone
* Compute
* Storage
* Networking
* Scalability
* Fault tolerance
* High availability
* Shared responsibility model
* IAM

---

## Week 38 — AWS IAM

Learn:

* Users
* Groups
* Roles
* Policies
* Resource policies
* Identity policies
* Least privilege
* STS

### Practice

Create a role that can:

```text
Read S3
but cannot
Delete S3 objects
```

---

## Week 39 — AWS S3

### Learn

* Buckets
* Objects
* Keys
* Storage classes
* Versioning
* Lifecycle
* Encryption
* Multipart upload
* Presigned URLs
* Access control
* Event notifications

### Build

```text
Python
 ↓
S3
 ↓
Parquet
```

This is an important transition because you're moving the local object-storage concepts you've already learned into cloud infrastructure.

---

## Week 40 — AWS Lambda

Learn:

* Runtime
* Handler
* Event
* Execution role
* Environment variables
* Layers
* Package deployment

### Build

```text
S3 Upload
 ↓
Lambda
 ↓
Process
 ↓
Output
```

Lambda currently has a free tier of 1M requests and 400,000 GB-seconds/month, although always check current pricing and account eligibility before deploying resources. ([Amazon Web Services, Inc.][6])

---

## Week 41 — Cloud Data Services

Understand the role of:

* Glue
* Athena
* RDS
* Redshift
* EMR
* Kinesis

**Do not try to master all six.**

You need architecture-level understanding first.

---

## Week 42 — Project 4

Build:

```text
API
 ↓
S3
 ↓
Glue/Athena
 ↓
dbt
 ↓
Analytics
```

Then document the architecture, cost considerations and failure points.

---

# PHASE 8 — DISTRIBUTED COMPUTING

Only now do we introduce Spark.

## Week 43 — Distributed Systems

Learn:

* Nodes
* Parallelism
* Partitioning
* Replication
* Fault tolerance
* Network transfer
* Serialization
* Data locality
* Horizontal scaling

---

## Week 44 — Spark Architecture

Learn:

* Driver
* Executors
* Cluster manager
* Job
* Stage
* Task
* DAG

---

## Week 45 — Spark Programming

Learn:

* DataFrames
* Spark SQL
* transformations
* actions
* lazy evaluation
* narrow transformations
* wide transformations

---

## Week 46 — Spark Performance

This is the important week.

Learn:

* Partitions
* Shuffle
* Broadcast joins
* Sort-merge joins
* Caching
* Data skew
* AQE
* Predicate pushdown
* File sizing

Current Spark documentation lists Spark 4.2.0 as the current stable release and includes SQL/DataFrames and Spark Streaming among its built-in components. ([Apache Spark][2])

### Practice

Take the same workload and deliberately make it inefficient.

Then optimize it.

---

## Week 47 — Spark Project

Build:

```text
Object Storage
 ↓
Parquet
 ↓
Spark
 ↓
Transformation
 ↓
Parquet
```

Add:

* partitioning
* joins
* optimization
* data quality

---

# PHASE 9 — LAKEHOUSE

## Week 48 — Lakehouse Architecture

Understand deeply:

```text
Data Lake
vs
Data Warehouse
vs
Lakehouse
```

And:

* object storage
* compute/storage separation
* metadata
* catalogs
* table formats

---

## Week 49 — Apache Iceberg

This should be concept-heavy.

Learn:

* Tables
* Snapshots
* Metadata
* Manifests
* Manifest lists
* Schema evolution
* Partition evolution
* Hidden partitioning
* Time travel
* Rollback
* Deletes
* Merge
* Compaction

Iceberg's current documentation emphasizes exactly these table-management capabilities and describes Iceberg as an open table format used by engines including Spark, Trino and Flink. ([Apache Iceberg][7])

---

## Week 50 — Trino

Learn:

* Coordinator
* Workers
* Catalog
* Connector
* Distributed query execution
* Predicate pushdown
* Query planning
* Federation

### Build

```text
Iceberg
 ↓
Trino
 ↓
SQL
```

---

# PHASE 10 — STREAMING

## Week 51 — Kafka Fundamentals

Learn:

* Producer
* Consumer
* Broker
* Topic
* Partition
* Offset
* Consumer group
* Replication

### Build

```text
Python producer
 ↓
Kafka
 ↓
Python consumer
```

---

## Week 52 — Kafka Engineering

Learn:

* Ordering
* Delivery semantics
* At-most-once
* At-least-once
* Exactly-once concepts
* Idempotency
* Schema Registry
* Avro
* Kafka Connect

### Build

```text
Application event
 ↓
Kafka
 ↓
Processing
 ↓
Data Lake
```

---

# PHASE 11 — DATA QUALITY & OBSERVABILITY

I don't want to leave this as an optional side topic. The 2026 ecosystem is making it increasingly important because AI can accelerate data work without guaranteeing correctness. ([dbt Labs][3])

## Week 53 — Data Quality

Learn:

* Accuracy
* Completeness
* Consistency
* Uniqueness
* Validity
* Timeliness
* Freshness

### Build

Data-quality test framework.

---

## Week 54 — Data Contracts

Learn:

* Schema contracts
* Ownership
* Producers
* Consumers
* Breaking changes
* Schema evolution

---

## Week 55 — Observability

Learn:

* Logs
* Metrics
* Traces
* Lineage
* Freshness
* Pipeline health
* SLA/SLO

Learn concepts around:

* OpenLineage
* DataHub
* OpenMetadata

You don't need to master all three.

---

# PHASE 12 — AI ENGINEERING

This comes **after** your data foundations.

## Week 56 — LLM Fundamentals

Learn:

* Tokens
* Context windows
* Embeddings
* Transformers
* Attention
* Inference
* Temperature
* Structured output
* Tool/function calling

---

## Week 57 — Embeddings

Learn:

* Vector representation
* Semantic similarity
* Cosine similarity
* ANN
* Metadata
* Chunking

---

## Week 58 — Vector Databases

Start with:

**pgvector**

Then understand:

* Qdrant
* Milvus
* OpenSearch

conceptually.

---

## Week 59 — RAG

Build:

```text
Documents
 ↓
Chunking
 ↓
Embedding
 ↓
Vector DB
 ↓
Retrieval
 ↓
LLM
```

---

## Week 60 — Advanced RAG

Learn:

* Hybrid search
* Reranking
* Query rewriting
* Metadata filtering
* Retrieval evaluation
* Chunking strategies

---

## Week 61 — Tool Calling

Build:

```text
User
 ↓
LLM
 ↓
SQL Tool
 ↓
Database
 ↓
Result
 ↓
LLM
 ↓
Answer
```

---

## Week 62 — Agents

Learn:

* State
* Planning
* Tools
* Memory
* Human-in-the-loop
* Guardrails
* Agent evaluation

---

## Week 63 — MCP

Understand:

* Client
* Server
* Tools
* Resources
* Prompts
* Permissions
* Security model

Don't just learn "how to build an MCP server." Understand **why a protocol is useful in an AI/data architecture**.

---

# PHASE 13 — FINAL PROJECT

## Week 64–68 — AI Data Platform

Rather than pretending everything has to fit into exactly 52 calendar weeks, I'd reserve the final project for **4–5 weeks**.

Build:

```text
                         APIs
                          ↓
                       Python
                          ↓
                    Object Storage
                          ↓
                        Parquet
                          ↓
                       Iceberg
                     ↙          ↘
                  Spark        Trino
                     ↘          ↙
                         dbt
                          ↓
                   Semantic Models
                     ↙          ↘
                  Power BI       AI
                                  ↓
                                RAG
                                  ↓
                              Tool Calling
                                  ↓
                               Agent
                                  ↓
                                MCP
```

The agent should eventually be able to answer something like:

> "Why did revenue decline in Region A last month?"

It should:

1. understand the question
2. identify relevant metrics
3. generate SQL
4. query the platform
5. validate the output
6. retrieve business context
7. explain the result
8. show supporting data
9. identify uncertainty

That becomes your **flagship portfolio project**.

---

# The actual weekly workload

For every week, use this template.

### READ — 1 to 1.5 hours

Use:

**Primary:** official documentation
**Secondary:** one high-quality course/article/book

No resource-hoarding.

You don't need 15 YouTube videos.

---

### UNDERSTAND — 1 hour

Write down answers to:

```text
What problem does this solve?

Why does this technology exist?

How does it work internally?

What are its core abstractions?

What are its trade-offs?

When would I use it?

When would I NOT use it?

What can go wrong?
```

---

### CODE — 2 hours

Write from scratch.

No copy-paste tutorial.

Use official documentation as a reference.

---

### PRACTICE — 1 hour

Intentionally break something.

Examples:

**SQL:** bad execution plan

**Python:** malformed API response

**Docker:** broken network

**Airflow:** failed task

**Spark:** data skew

**Kafka:** duplicate event

**Iceberg:** schema evolution

**AWS:** permission failure

**RAG:** bad retrieval

This is where engineering skill develops.

---

### BUILD — 1–2 hours

Every 2–4 weeks, something tangible should exist.

---

### DOCUMENT — 30 minutes

GitHub:

```text
README.md
notes.md
code/
experiments/
results/
```

---

### PUBLISH — 15–30 minutes

Your weekly post:

> **100x Data Engineer — Week X**

Not:

> "This week I studied Airflow."

Instead:

> "I built my first Airflow pipeline and discovered that scheduling a task is very different from making a pipeline reliable."

Then show evidence.

---

# What you should NOT learn yet

This is equally important.

Do **not** simultaneously add:

```text
Kubernetes
Flink
Databricks
Snowflake
Delta Lake
Terraform
AWS
Azure
GCP
Ray
LangChain
LangGraph
CrewAI
100 vector databases
20 AI frameworks
```

Some of these will become useful later.

But your objective is:

**depth > tool count**

---

# Your priority hierarchy

### Tier 1 — Master

```text
SQL
Python
Data Modeling
Git
Docker
dbt
Airflow
Cloud fundamentals
Parquet
Spark
Data Quality
```

### Tier 2 — Become strong

```text
AWS
S3
Iceberg
Trino
Kafka
Terraform
RAG
Vector databases
Tool calling
```

### Tier 3 — Understand first

```text
Flink
Delta Lake
Databricks
Snowflake
Kubernetes
MCP
Agents
ML platforms
```

You will move some Tier 3 topics upward when a project requires them.

---

# The most important change to your original idea

Your **LinkedIn post says you want to become proficient in 14 areas**.

That's fine.

But your *private curriculum* should look like:

```text
                    FOUNDATION
                        │
                 SQL + Python
                        │
                 DATA MODELING
                        │
            ┌───────────┴───────────┐
            │                       │
       DATA FORMATS            SOFTWARE ENG
            │                       │
          PARQUET             Git/Docker/CI
            │                       │
            └───────────┬───────────┘
                        │
                    dbt + Airflow
                        │
                        ↓
                      CLOUD
                        │
                        ↓
                     SPARK
                        │
                        ↓
              LAKEHOUSE / ICEBERG
                        │
                        ↓
                    TRINO
                        │
                        ↓
                     KAFKA
                        │
                        ↓
               DATA QUALITY
                        │
                        ↓
                       AI
                        │
                RAG / TOOLS
                        │
                  AGENTS / MCP
                        │
                        ↓
                 FINAL PLATFORM
```

**Each layer depends on what came before it.**

That's the part I want us to protect.

For example, I don't want you learning Spark simply because "Spark is required for Data Engineers." By the time you reach Spark, you'll already understand Parquet, partitioning, joins, distributed-computing concepts and object storage. Then Spark will make substantially more sense.

Likewise, when you eventually learn Iceberg, you'll already know Parquet and object storage, so concepts like manifests, snapshots, partition evolution and metadata are much easier to understand. Iceberg's current documentation specifically exposes these as core table-management concepts. ([Apache Iceberg][7])

---

# Your first 12 weeks

Since this is a huge curriculum, **do not look at Week 64 right now**.

Your immediate roadmap is:

| Week   | Focus                | Main output             |
| ------ | -------------------- | ----------------------- |
| **0**  | Baseline + setup     | GitHub + roadmap        |
| **1**  | Window functions     | SQL problem set         |
| **2**  | Advanced SQL         | Analytical SQL          |
| **3**  | Data modeling        | Star schema             |
| **4**  | Indexes              | Benchmark               |
| **5**  | Execution plans      | Query optimization      |
| **6**  | Transactions         | Concurrency lab         |
| **7**  | Database engineering | PostgreSQL project      |
| **8**  | SQL project          | **Analytics warehouse** |
| **9**  | Python internals     | Python experiments      |
| **10** | Pythonic programming | Reusable utilities      |
| **11** | OOP/design           | Ingestion framework     |
| **12** | Type safety          | Typed pipeline          |

And **you should not start Week 1 until Week 0 is actually done.**

That means:

* GitHub repository exists.
* Baseline assessment is recorded.
* Development environment works.
* You have your first dataset.
* You know what you're studying.
* You have your first experiment ready.

Then we start.

This also solves your earlier concern about inconsistency: **the syllabus is fixed, but the calendar isn't.** Week 7 could take you seven days or fourteen. Your progress is measured by completed competencies and projects, not by maintaining a streak.

[1]: https://ai-de.net/guide/data-engineer-skills "The Top Data Engineer Skills You Need in 2026 | AI-DE | AI-DE"
[2]: https://spark.apache.org/documentation "Documentation | Apache Spark"
[3]: https://www.getdbt.com/resources/state-of-analytics-engineering-2026 "2026 State of Analytics Engineering Report | dbt Labs"
[4]: https://airflow.apache.org/docs/index.html "Documentation | Apache Airflow"
[5]: https://airflow.apache.org/docs/apache-airflow/stable/tutorial/ "Tutorials — Airflow 3.3.0 Documentation"
[6]: https://aws.amazon.com/lambda/pricing/ "AWS Lambda Pricing"
[7]: https://iceberg.apache.org/docs/latest/api/ "Java API - Apache Iceberg™"
