# 🚀 100x Data Engineer — Week 0

## Development Environment Setup

Before starting the 100x Data Engineer roadmap, I set up my complete local development environment.

The goal of Week 0 was simple: **get all the tools installed, configured, and working so I can start building from Week 1.**

---

## 1. Git & GitHub

I installed Git and configured my Git identity.

### Verify Git

```bash
git --version
```

### Configure Git

```bash
git config --global user.name "My Name"
git config --global user.email "my-email@example.com"
```

I then created my GitHub repository and connected my local project to it.

```bash
git init
git remote add origin <repository-url>
```

I verified the connection with:

```bash
git remote -v
```

---

## 2. VS Code

I installed **Visual Studio Code** as my primary development environment.

I configured extensions for:

* Python
* Pylance
* Jupyter
* Docker
* Git
* SQL
* YAML

I kept the extensions limited to tools that I will actually use during the journey.

---

## 3. Python

I installed Python and verified the installation.

```bash
python --version
```

I also verified `pip`:

```bash
python -m pip --version
```

Then I upgraded pip:

```bash
python -m pip install --upgrade pip
```

---

## 4. Python Virtual Environment

I will use a separate virtual environment for each Python project.

I created one using:

```bash
python -m venv .venv
```

On Windows, I activated it with:

```powershell
.venv\Scripts\activate
```

I verified that the environment was active:

```bash
python --version
pip list
```

I also added `.venv/` to `.gitignore` so that the virtual environment is never pushed to GitHub.

---

## 5. Python Development Packages

I installed the basic packages required for my data engineering work:

```bash
pip install pandas numpy requests python-dotenv sqlalchemy
```

I saved the dependencies using:

```bash
pip freeze > requirements.txt
```

---

## 6. SQL Environment

I prepared my SQL development environment for the databases I will work with:

* MySQL
* PostgreSQL
* SQL Server

I also installed/configured the required database clients and management tools.

I verified that I could connect to my databases and execute basic SQL queries.

---

## 7. Docker

I installed Docker Desktop because I will use containers extensively throughout the roadmap.

I verified Docker:

```bash
docker --version
```

I verified Docker Compose:

```bash
docker compose version
```

Finally, I tested the Docker Engine:

```bash
docker run hello-world
```

A successful response confirmed that Docker was working correctly.

---

## 8. Jupyter

I installed Jupyter for data exploration and experimentation.

```bash
pip install jupyter
```

I verified it by running:

```bash
jupyter notebook
```

---

## 9. Environment Variables

I configured my projects to keep credentials and API keys outside the source code.

For local development, I use a `.env` file:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=my_database
DB_USER=my_user
DB_PASSWORD=my_password
API_KEY=my_api_key
```

I added `.env` to `.gitignore`:

```gitignore
.env
.env.*
```

---

## 10. Project Structure

I created the initial structure for my 100x Data Engineer repository:

```text
100x-data-engineer/
│
├── README.md
├── week-00/
├── week-01/
├── week-02/
├── projects/
├── exercises/
├── notes/
└── resources/
```

---

## 11. Final Verification

I verified that my complete environment was working:

* [x] Git installed and configured
* [x] GitHub repository created
* [x] VS Code configured
* [x] Python installed
* [x] Python virtual environment working
* [x] Required Python packages installed
* [x] SQL environment ready
* [x] Docker working
* [x] Docker Compose working
* [x] Jupyter working
* [x] Environment variables configured
* [x] Repository structure created

---

## Week 0 Complete ✅

My development environment is ready.

**Next → Week 1**
