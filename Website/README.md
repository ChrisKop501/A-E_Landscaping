# A & E Landscaping and Hauling — Flask + XAMPP Setup

## Project Structure
```
ae_project/
  app.py              ← Flask backend (all routes + DB logic)
  requirements.txt    ← Python packages needed
  html/               ← All HTML templates (Flask renders these)
    ae-home.html      ← Public client website (feedback + estimate forms)
    index.html        ← Manager dashboard (live DB stats)
    home.html         ← Ad-Hoc queries (revenue by service, top clients)
    clients.html      ← Add client + feedback lookup + service history
    contracts.html    ← Contract entry form
    billing.html      ← Payment entry + invoice review
    reports.html      ← Monthly revenue + outstanding invoices + job costing
    employees.html    ← Estimate employees + service employees + schedule
    login.html        ← Manager login
    employee-portal.html  ← Employee schedule portal
    gallery.html      ← Before/After gallery
    properties.html   ← Properties page
    services.html     ← Services page
  css/                ← All CSS files (served by Flask as static)
```

---

## Step 1 — XAMPP Setup

1. Open **XAMPP Control Panel**, start **Apache** and **MySQL**
2. Go to `http://localhost/phpmyadmin`
3. Create a database called **`ae_landscaping`**
4. Import `ae_landscaping_database.sql` into that database

---

## Step 2 — Python Setup

Open a terminal/command prompt:

```bash
# Install required packages
pip install flask mysql-connector-python

# OR use requirements.txt
pip install -r requirements.txt
```

---

## Step 3 — Configure Database in app.py

Open `app.py` and check this section at the top:

```python
DB_CONFIG = {
    'user':     'root',
    'password': '',       # Leave empty for XAMPP default
    'host':     '127.0.0.1',
    'port':     3306,     # XAMPP default port
    'database': 'ae_landscaping'
}
```

If you set a MySQL password in XAMPP, enter it in `password`.

---

## Step 4 — Run the App

```bash
cd ae_project
python app.py
```

Open your browser to: **http://127.0.0.1:5000**

---

## Login Credentials

**Manager Dashboard:**
- Username: `manager` / Password: `ae2024!`
- Username: `admin` / Password: `admin123`

**Employee Portal:**
- Select name from dropdown, PIN: `1234`

---

## Page Map

| URL | Page |
|-----|------|
| `http://127.0.0.1:5000/` | Client-facing homepage |
| `http://127.0.0.1:5000/login` | Manager login |
| `http://127.0.0.1:5000/dashboard` | Manager dashboard |
| `http://127.0.0.1:5000/manager/clients` | Clients + feedback + history |
| `http://127.0.0.1:5000/manager/billing` | Payment entry |
| `http://127.0.0.1:5000/manager/reports` | Monthly revenue + job costing |
| `http://127.0.0.1:5000/manager/employees` | Employee assignments + schedule |
| `http://127.0.0.1:5000/manager/home` | Ad-hoc queries |
| `http://127.0.0.1:5000/manager/contracts` | Contract entry |
| `http://127.0.0.1:5000/employee-portal` | Employee portal |
