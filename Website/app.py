"""
A & E Landscaping and Hauling — Flask Backend
Connects to XAMPP MySQL (ae_landscaping database)
Run: python app.py  →  http://127.0.0.1:5000
"""

import mysql.connector
from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from functools import wraps

# ─────────────────────────────────────────────
#  DATABASE CONFIG  (update password if needed)
# ─────────────────────────────────────────────
DB_CONFIG = {
    'user':     'root',
    'password': '',          # XAMPP default is empty; change if you set one
    'host':     '127.0.0.1',
    'port':     3306,        # XAMPP default MySQL port
    'database': 'ae_landscaping'
}

# ─────────────────────────────────────────────
#  APP SETUP
# ─────────────────────────────────────────────
app = Flask(__name__, template_folder='templates', static_folder='static', static_url_path='/css')
# Note: name the static folder 'static' on disk, but serve it at /css URL path
app.secret_key = 'ae_landscape_secret_2024'

# ─────────────────────────────────────────────
#  DB HELPER
# ─────────────────────────────────────────────
def get_db():
    """Return a connected MySQL cursor (dictionary mode) or None."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as err:
        print(f"[DB ERROR] {err}")
        return None


def query_db(sql, params=None):
    """Run a SELECT and return list-of-dicts, or [] on error."""
    conn = get_db()
    if conn is None:
        return []
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        rows = cur.fetchall()
        return rows
    except Exception as e:
        print(f"[QUERY ERROR] {e}")
        return []
    finally:
        conn.close()


def exec_db(sql, params=None):
    """Run INSERT/UPDATE and return (success:bool, message:str)."""
    conn = get_db()
    if conn is None:
        return False, "Could not connect to database."
    try:
        cur = conn.cursor()
        cur.execute(sql, params or ())
        conn.commit()
        return True, "Success"
    except Exception as e:
        print(f"[EXEC ERROR] {e}")
        return False, str(e)
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  AUTH
# ─────────────────────────────────────────────
MANAGER_CREDS = {'manager': 'ae2024!', 'admin': 'admin123'}

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            # If this is a JSON/API request, return JSON error instead of HTML redirect
            # so fetch() calls don't silently fail
            if request.is_json or request.path.startswith('/submit/') or request.path.startswith('/api/'):
                return jsonify({'success': False, 'message': 'Session expired. Please log in again at /login.'}), 401
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


@app.route('/api/test-db')
def test_db():
    """Quick connectivity check — visit /api/test-db in browser to confirm DB is reachable."""
    conn = get_db()
    if not conn:
        return jsonify({'status':'ERROR','message':'Cannot connect to ae_landscaping. Make sure XAMPP MySQL is running.'})
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT COUNT(*) AS cnt FROM Employee")
        row = cur.fetchone()
        return jsonify({'status':'OK','employee_count':row['cnt'],'message':'Connected to ae_landscaping successfully.'})
    except Exception as e:
        return jsonify({'status':'ERROR','message':str(e)})
    finally:
        conn.close()


@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        u = request.form.get('username', '').strip()
        p = request.form.get('password', '')
        if MANAGER_CREDS.get(u) == p:
            session['logged_in'] = True
            session['username']  = u
            return redirect(url_for('dashboard'))
        error = 'Invalid username or password.'
    return render_template('login.html', error=error)


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


# HTML EXTENSION REDIRECTS
# Catches old-style links like /manager/billing.html -> /manager/billing
HTML_REDIRECT_MAP = {
    'index.html':           '/dashboard',
    'home.html':            '/manager/home',
    'clients.html':         '/manager/clients',
    'properties.html':      '/manager/properties',
    'contracts.html':       '/manager/contracts',
    'services.html':        '/manager/services',
    'billing.html':         '/manager/billing',
    'reports.html':         '/manager/reports',
    'employees.html':       '/manager/employees',
    'jobcosting.html':      '/manager/jobcosting',
    'estimates.html':       '/manager/estimates',
    'ae-home.html':         '/',
    'gallery.html':         '/gallery',
    'employee-portal.html': '/employee-portal',
    'login.html':           '/login',
}

@app.route('/manager/<page>')
def manager_html_redirect(page):
    if page in HTML_REDIRECT_MAP:
        return redirect(HTML_REDIRECT_MAP[page])
    return "Page not found", 404

@app.route('/<page>')
def top_level_html_redirect(page):
    if page in HTML_REDIRECT_MAP:
        return redirect(HTML_REDIRECT_MAP[page])
    return "Page not found", 404


# ─────────────────────────────────────────────
#  STATIC PAGES  (no auth needed)
# ─────────────────────────────────────────────
@app.route('/')
def home():
    return render_template('ae-home.html')

@app.route('/gallery')
def gallery():
    return render_template('gallery.html')

@app.route('/employee-portal')
def employee_portal():
    return render_template('employee-portal.html')


# ─────────────────────────────────────────────
#  MANAGER DASHBOARD
# ─────────────────────────────────────────────
@app.route('/dashboard')
@login_required
def dashboard():
    username = session.get('username', 'Manager')

    def safe_count(sql):
        try:
            rows = query_db(sql)
            if rows and rows[0]:
                return rows[0].get('c', 0) or 0
        except:
            pass
        return 0

    def safe_sum(sql):
        try:
            rows = query_db(sql)
            if rows and rows[0]:
                return rows[0].get('s', 0) or 0
        except:
            pass
        return 0

    stats = {
        'clients':   safe_count("SELECT COUNT(*) AS c FROM Client"),
        'contracts': safe_count("SELECT COUNT(*) AS c FROM Contract"),
        'open_inv':  safe_count("SELECT COUNT(*) AS c FROM Invoice WHERE Invoice_Status IN ('Unpaid','Partial')"),
        'total_inv': safe_sum("SELECT SUM(Total_Amount) AS s FROM Invoice"),
    }
    return render_template('index.html', username=username, stats=stats)

@app.route('/manager/home')
@login_required
def manager_home():
    return render_template('home.html', username=session.get('username','Manager'))

@app.route('/manager/clients')
@login_required
def clients_page():
    return render_template('clients.html', username=session.get('username','Manager'))

@app.route('/manager/properties')
@login_required
def properties_page():
    return render_template('properties.html', username=session.get('username','Manager'))

@app.route('/manager/contracts')
@login_required
def contracts_page():
    return render_template('contracts.html', username=session.get('username','Manager'))

@app.route('/manager/services')
@login_required
def services_page():
    return render_template('services.html', username=session.get('username','Manager'))

@app.route('/manager/billing')
@login_required
def billing_page():
    return render_template('billing.html', username=session.get('username','Manager'))

@app.route('/manager/reports')
@login_required
def reports_page():
    return render_template('reports.html', username=session.get('username','Manager'))

@app.route('/manager/estimates')
@login_required
def estimates_page():
    return render_template('estimates.html', username=session.get('username','Manager'))

@app.route('/manager/jobcosting')
@login_required
def jobcosting_page():
    return render_template('jobcosting.html', username=session.get('username','Manager'))

@app.route('/manager/employees')
@login_required
def employees_page():
    return render_template('employees.html', username=session.get('username','Manager'))


# ═══════════════════════════════════════════════════════════════
#  API ROUTES — ALL RETURN JSON
# ═══════════════════════════════════════════════════════════════

# ── ROUTINE QUERY 1: Client Feedback (filter by client_id or rating) ──
@app.route('/api/client-feedback')
@login_required
def api_client_feedback():
    client_id = request.args.get('client_id', '')
    rating    = request.args.get('rating', '')
    sql = """
        SELECT cf.Feedback_ID, c.Client_ID, c.Client_Name,
               s.Service_Type, s.Service_Date,
               cf.Rating, cf.Comments, cf.Suggestions, cf.Feedback_Date
        FROM Client_Feedback cf
        JOIN Client  c ON cf.Client_ID  = c.Client_ID
        JOIN Service s ON cf.Service_ID = s.Service_ID
        WHERE 1=1
    """
    params = []
    if client_id:
        sql += " AND c.Client_ID = %s"
        params.append(client_id)
    if rating:
        sql += " AND cf.Rating = %s"
        params.append(rating)
    sql += " ORDER BY cf.Feedback_Date DESC"
    return jsonify(query_db(sql, params))


# ── ROUTINE QUERY 2: Estimate Employees ──
@app.route('/api/estimate-employees')
@login_required
def api_estimate_employees():
    month       = request.args.get('month', '')
    year        = request.args.get('year',  '')
    employee_id = request.args.get('employee_id', '')
    sql = """
        SELECT e.Estimate_ID, c.Client_Name, e.Property_Address,
               e.Service_Description, e.Estimated_Cost,
               e.Estimated_Labor_Hours, e.Estimate_Date,
               emp.Employee_ID, emp.Employee_Name, emp.Employee_Role
        FROM Estimate e
        JOIN Client   c   ON e.Client_ID  = c.Client_ID
        LEFT JOIN Employee emp ON e.Employee_ID = emp.Employee_ID
        WHERE 1=1
    """
    params = []
    if month:
        sql += " AND MONTH(e.Estimate_Date) = %s"
        params.append(month)
    if year:
        sql += " AND YEAR(e.Estimate_Date) = %s"
        params.append(year)
    if employee_id:
        sql += " AND emp.Employee_ID = %s"
        params.append(employee_id)
    sql += " ORDER BY e.Estimate_Date DESC"
    return jsonify(query_db(sql, params))


# ── ROUTINE QUERY 3: Service Employees (available) ──
@app.route('/api/service-employees')
@login_required
def api_service_employees():
    sql = """
        SELECT emp.Employee_ID, emp.Employee_Name,
               emp.Employee_Role, emp.Employee_Phone,
               emp.Employee_Email, emp.Is_Available
        FROM Employee emp
        WHERE emp.Is_Available = 1
        ORDER BY emp.Employee_Name
    """
    return jsonify(query_db(sql))


# ── AD-HOC 1: Revenue by Service Type ──
@app.route('/api/revenue-by-service')
@login_required
def api_revenue_by_service():
    service_type = request.args.get('service_type', '')
    sql = """
        SELECT s.Service_Type,
               COUNT(DISTINCT s.Service_ID)  AS Total_Services,
               SUM(i.Total_Amount)           AS Total_Revenue,
               AVG(i.Total_Amount)           AS Avg_Revenue,
               MIN(s.Service_Date)           AS First_Service,
               MAX(s.Service_Date)           AS Latest_Service
        FROM Service  s
        JOIN Contract con ON s.Contract_ID  = con.Contract_ID
        JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
    """
    params = []
    if service_type:
        sql += " WHERE s.Service_Type = %s"
        params.append(service_type)
    sql += " GROUP BY s.Service_Type ORDER BY Total_Revenue DESC"
    return jsonify(query_db(sql, params))


# ── AD-HOC 2: Top Clients by Revenue ──
@app.route('/api/top-clients')
@login_required
def api_top_clients():
    limit = request.args.get('limit', 10)
    sql = """
        SELECT c.Client_ID, c.Client_Name,
               COUNT(DISTINCT con.Contract_ID)           AS Total_Contracts,
               SUM(i.Total_Amount)                       AS Total_Billed,
               SUM(i.Amount_Paid)                        AS Total_Collected,
               (SUM(i.Total_Amount) - SUM(i.Amount_Paid)) AS Outstanding_Balance
        FROM Client   c
        JOIN Contract con ON c.Client_ID    = con.Client_ID
        JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
        GROUP BY c.Client_ID, c.Client_Name
        ORDER BY Total_Collected DESC
        LIMIT %s
    """
    return jsonify(query_db(sql, [int(limit)]))


# ── REPORT 1: Monthly Revenue ──
@app.route('/api/monthly-revenue')
@login_required
def api_monthly_revenue():
    month = request.args.get('month', '')
    year  = request.args.get('year',  '')
    # Return every individual invoice for the selected period
    sql = """
        SELECT i.Invoice_ID,
               i.Invoice_Date,
               i.Due_Date,
               i.Total_Amount,
               i.Amount_Paid,
               (i.Total_Amount - i.Amount_Paid) AS Balance_Due,
               i.Invoice_Status,
               c.Client_Name,
               YEAR(i.Invoice_Date)  AS Year,
               MONTH(i.Invoice_Date) AS Month
        FROM Invoice i
        JOIN Client c ON i.Client_ID = c.Client_ID
        WHERE 1=1
    """
    params = []
    if month:
        sql += " AND MONTH(i.Invoice_Date) = %s"
        params.append(month)
    if year:
        sql += " AND YEAR(i.Invoice_Date) = %s"
        params.append(year)
    sql += " ORDER BY i.Invoice_Date DESC"
    return jsonify(query_db(sql, params))


# ── REPORT 2: Outstanding Invoices ──
@app.route('/api/outstanding-invoices')
@login_required
def api_outstanding_invoices():
    sql = """
        SELECT i.Invoice_ID, c.Client_Name, c.Client_ID,
               i.Invoice_Date, i.Due_Date,
               i.Total_Amount, i.Amount_Paid,
               (i.Total_Amount - i.Amount_Paid) AS Balance_Due,
               i.Invoice_Status,
               DATEDIFF(CURDATE(), i.Due_Date) AS Days_Overdue,
               CASE
                 WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 0  THEN 'Current'
                 WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 30 THEN '1-30 Days'
                 WHEN DATEDIFF(CURDATE(), i.Due_Date) <= 60 THEN '31-60 Days'
                 ELSE '60+ Days'
               END AS Aging_Bucket
        FROM Invoice i
        JOIN Client  c ON i.Client_ID = c.Client_ID
        WHERE i.Invoice_Status IN ('Unpaid','Partial')
        ORDER BY Days_Overdue DESC
    """
    return jsonify(query_db(sql))


# ── REPORT 3: Client Service History ──
@app.route('/api/client-service-history')
@login_required
def api_client_service_history():
    client_id = request.args.get('client_id', '')
    location  = request.args.get('location', '')
    sql = """
        SELECT c.Client_ID, c.Client_Name, c.Client_Phone, c.Client_Email,
               s.Service_ID, s.Service_Date, s.Service_Type, s.Property_Location,
               con.Contract_ID, con.Pricing AS Contract_Price,
               i.Invoice_ID, i.Invoice_Status,
               i.Total_Amount, i.Amount_Paid
        FROM Client   c
        JOIN Service  s   ON s.Client_ID    = c.Client_ID
        JOIN Contract con ON s.Contract_ID  = con.Contract_ID
        JOIN Invoice  i   ON con.Contract_ID = i.Contract_ID
        WHERE 1=1
    """
    params = []
    if client_id:
        sql += " AND c.Client_ID = %s"
        params.append(client_id)
    if location:
        sql += " AND s.Property_Location LIKE %s"
        params.append(f"%{location}%")
    sql += " ORDER BY c.Client_Name, s.Service_Date DESC"
    return jsonify(query_db(sql, params))


# ── REPORT 4: Job Costing ──
@app.route('/api/job-costing')
@login_required
def api_job_costing():
    estimate_id = request.args.get('estimate_id', '')
    month       = request.args.get('month', '')
    year        = request.args.get('year',  '')
    sql = """
        SELECT jc.Job_Cost_ID, jc.Estimate_ID,
               jc.Service_ID, s.Service_Type, s.Service_Date,
               c.Client_Name, s.Property_Location,
               jc.Total_Estimated_Cost, jc.Total_Actual_Cost,
               jc.Actual_Labor_Hours, jc.Actual_Labor_Cost,
               jc.Actual_Materials,
               (jc.Total_Actual_Cost - jc.Total_Estimated_Cost) AS Variance,
               CASE
                 WHEN (jc.Total_Actual_Cost - jc.Total_Estimated_Cost) > 0  THEN 'Over Budget'
                 WHEN (jc.Total_Actual_Cost - jc.Total_Estimated_Cost) < 0  THEN 'Under Budget'
                 ELSE 'On Budget'
               END AS Budget_Status,
               SUM(jc.Total_Actual_Cost)    OVER () AS Grand_Total_Actual,
               SUM(jc.Total_Estimated_Cost) OVER () AS Grand_Total_Estimated
        FROM Job_Costing jc
        JOIN Service s ON jc.Service_ID = s.Service_ID
        JOIN Client  c ON s.Client_ID   = c.Client_ID
        WHERE 1=1
    """
    params = []
    if estimate_id:
        sql += " AND jc.Estimate_ID = %s"
        params.append(estimate_id)
    if month:
        sql += " AND MONTH(s.Service_Date) = %s"
        params.append(month)
    if year:
        sql += " AND YEAR(s.Service_Date) = %s"
        params.append(year)
    sql += " ORDER BY s.Service_Date DESC"
    return jsonify(query_db(sql, params))


# ── REPORT 5: Schedule & Workload ──
@app.route('/api/schedule-workload')
@login_required
def api_schedule_workload():
    sql = """
        SELECT s.Service_ID, s.Service_Date, s.Service_Type,
               c.Client_Name, s.Property_Location,
               emp.Employee_Name, emp.Employee_Role,
               CASE
                 WHEN s.Service_Date < CURDATE()  THEN 'Completed'
                 WHEN s.Service_Date = CURDATE()  THEN 'Today'
                 ELSE 'Upcoming'
               END AS Status
        FROM Service          s
        JOIN Client           c   ON s.Client_ID   = c.Client_ID
        JOIN Service_Employee se  ON s.Service_ID  = se.Service_ID
        JOIN Employee         emp ON se.Employee_ID = emp.Employee_ID
        ORDER BY s.Service_Date ASC
    """
    return jsonify(query_db(sql))


# ── HELPER: Client list dropdown ──
@app.route('/api/clients-list')
@login_required
def api_clients_list():
    return jsonify(query_db("SELECT Client_ID, Client_Name FROM Client ORDER BY Client_Name"))


@app.route('/api/clients-full')
@login_required
def api_clients_full():
    return jsonify(query_db("SELECT Client_ID, Client_Name, Client_Phone, Client_Email, Property_Address FROM Client ORDER BY Client_Name"))

@app.route('/api/service-types')
@login_required
def api_service_types():
    rows = query_db("SELECT DISTINCT Service_Type FROM Service ORDER BY Service_Type")
    return jsonify([r['Service_Type'] for r in rows])

# ── Public employee lookup — used by employee portal PIN login ──
@app.route('/api/public/employee-lookup')
def api_public_employee_lookup():
    """Returns basic info for a single employee by ID — no manager session required."""
    emp_id = request.args.get('id', '')
    if not emp_id:
        return jsonify({'found': False, 'message': 'No ID provided.'})
    rows = query_db(
        "SELECT Employee_ID, Employee_Name, Employee_Role, Is_Available FROM Employee WHERE Employee_ID = %s LIMIT 1",
        [emp_id]
    )
    if not rows:
        return jsonify({'found': False, 'message': f'Employee ID {emp_id} not found.'})
    return jsonify({'found': True, 'employee': rows[0]})


@app.route('/api/public/my-clients')
def api_public_my_clients():
    """Returns all clients an employee has helped via vw_Employee_Clients.
    No manager session required — callable from the employee portal after PIN login."""
    emp_id = request.args.get('employee_id', '')
    if not emp_id:
        return jsonify({'success': False, 'message': 'employee_id is required.'})
    sql = """
        SELECT
            Client_ID,
            Client_Name,
            Client_Phone,
            Client_Email,
            Property_Address,
            Last_Service_Date,
            Times_Served,
            Last_Description
        FROM vw_Employee_Clients
        WHERE Employee_ID = %s
        ORDER BY Last_Service_Date DESC
    """
    rows = query_db(sql, [emp_id])
    return jsonify({'success': True, 'clients': rows})


@app.route('/api/employees-list')
@login_required
def api_employees_list():
    return jsonify(query_db("SELECT Employee_ID, Employee_Name, Employee_Role FROM Employee ORDER BY Employee_Name"))

@app.route('/api/contracts-list')
@login_required
def api_contracts_list():
    return jsonify(query_db("""
        SELECT con.Contract_ID, c.Client_Name, con.Pricing, con.Service_Scope
        FROM Contract con JOIN Client c ON con.Client_ID = c.Client_ID
        ORDER BY con.Contract_ID DESC
    """))

@app.route('/api/invoices-by-client')
@login_required
def api_invoices_by_client():
    client_id = request.args.get('client_id', '')
    sql = """
        SELECT i.Invoice_ID, i.Contract_ID, i.Client_ID,
               i.Total_Amount, i.Amount_Paid,
               (i.Total_Amount - i.Amount_Paid) AS Balance_Due,
               i.Invoice_Status, i.Invoice_Date, i.Due_Date
        FROM Invoice i
        WHERE 1=1
    """
    params = []
    if client_id:
        sql += " AND i.Client_ID = %s"
        params.append(client_id)
    sql += " ORDER BY i.Invoice_Date DESC"
    return jsonify(query_db(sql, params))


# ── API: All invoices (for invoice entry form) ──
@app.route('/api/all-invoices')
@login_required
def api_all_invoices():
    sql = """
        SELECT i.Invoice_ID, i.Contract_ID, i.Client_ID,
               c.Client_Name,
               i.Invoice_Date, i.Due_Date,
               i.Total_Amount, i.Amount_Paid,
               (i.Total_Amount - i.Amount_Paid) AS Balance_Due,
               i.Invoice_Status
        FROM Invoice i
        JOIN Client c ON i.Client_ID = c.Client_ID
        ORDER BY i.Invoice_Date DESC
    """
    return jsonify(query_db(sql))


# ═══════════════════════════════════════════════════════════════
#  FORM SUBMISSION ROUTES  (write to DB)
# ═══════════════════════════════════════════════════════════════

# ── FORM 1: Customer Feedback (ae-home.html — public) ──
# Client enters their Client_ID; the front end looks up the name and
# passes both. We insert directly using the client_id.
@app.route('/submit/feedback', methods=['POST'])
def submit_feedback():
    data      = request.get_json() or request.form
    client_id = data.get('client_id')

    if not client_id:
        return jsonify({'success': False, 'message': 'Client ID is required to submit feedback.'})

    # Verify the client exists
    rows = query_db("SELECT Client_ID, Client_Name FROM Client WHERE Client_ID = %s LIMIT 1", [client_id])
    if not rows:
        return jsonify({'success': False, 'message': f'Client ID {client_id} was not found in our records.'})

    sql = """
        INSERT INTO Client_Feedback
            (Client_ID, Service_ID, Rating, Comments, Suggestions, Feedback_Date)
        VALUES (%s, %s, %s, %s, %s, CURDATE())
    """
    ok, msg = exec_db(sql, (
        client_id,
        data.get('service_id') or None,
        data.get('rating'),
        data.get('comments', ''),
        data.get('suggestions', '')
    ))
    return jsonify({'success': ok, 'message': msg})


# ── FORM 1b: Estimate Request (ae-home.html — public) ──
# Creates a new Client record first (auto-generates Client_ID),
# then immediately links that Client_ID to the new Estimate.
@app.route('/submit/estimate-request', methods=['POST'])
def submit_estimate_request():
    data = request.get_json() or request.form

    client_name    = data.get('client_name', '').strip()
    client_phone   = data.get('client_phone', '').strip()
    client_email   = data.get('client_email', '').strip()
    property_addr  = data.get('property_address', '').strip()
    service_desc   = data.get('service_description', '').strip()
    est_cost       = data.get('estimated_cost') or 0
    est_hours      = data.get('estimated_labor_hours') or 0

    if not client_name or not property_addr or not service_desc:
        return jsonify({'success': False, 'message': 'Name, address, and service description are required.'})

    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})

    try:
        cur = conn.cursor()

        # Step 1: Insert new Client — MySQL auto-generates Client_ID
        cur.execute("""
            INSERT INTO Client (Client_Name, Client_Phone, Client_Email, Property_Address)
            VALUES (%s, %s, %s, %s)
        """, (client_name, client_phone or None, client_email or None, property_addr))

        new_client_id = cur.lastrowid  # grab the auto-generated Client_ID

        # Step 2: Insert Estimate linked to the new Client_ID
        cur.execute("""
            INSERT INTO Estimate
                (Client_ID, Employee_ID, Property_Address,
                 Service_Description, Estimated_Cost,
                 Estimated_Labor_Hours, Estimate_Date)
            VALUES (%s, %s, %s, %s, %s, %s, CURDATE())
        """, (new_client_id, None, property_addr, service_desc, est_cost, est_hours))

        new_estimate_id = cur.lastrowid

        conn.commit()
        return jsonify({
            'success':     True,
            'client_id':   new_client_id,
            'estimate_id': new_estimate_id,
            'message':     f'Client and estimate created successfully.'
        })

    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── FORM 2: New Client (clients.html) ──
@app.route('/submit/client', methods=['POST'])
@login_required
def submit_client():
    data = request.get_json() or request.form
    sql = """
        INSERT INTO Client (Client_Name, Client_Phone, Client_Email, Property_Address)
        VALUES (%s, %s, %s, %s)
    """
    ok, msg = exec_db(sql, (
        data.get('client_name'),
        data.get('client_phone'),
        data.get('client_email'),
        data.get('property_address')
    ))
    return jsonify({'success': ok, 'message': msg})


# ── FORM 3: New Contract (contracts.html) ──
@app.route('/submit/contract', methods=['POST'])
@login_required
def submit_contract():
    data = request.get_json() or request.form
    sql = """
        INSERT INTO Contract
            (Estimate_ID, Client_ID, Contract_StartDate, Contract_EndDate,
             Pricing, Service_Scope, Contract_Duration)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    ok, msg = exec_db(sql, (
        data.get('estimate_id') or None,
        data.get('client_id'),
        data.get('start_date'),
        data.get('end_date'),
        data.get('pricing'),
        data.get('service_scope'),
        data.get('duration')
    ))
    return jsonify({'success': ok, 'message': msg})


# ── New Estimate — Employee Portal (no manager session required) ──
@app.route('/submit/estimate-employee', methods=['POST'])
def submit_estimate_employee():
    """Public-facing estimate submission for employees logged in via PIN."""
    data = request.get_json() or request.form
    sql = """
        INSERT INTO Estimate
            (Client_ID, Employee_ID, Property_Address,
             Service_Description, Estimated_Cost,
             Estimated_Labor_Hours, Estimate_Date)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})
    try:
        cur = conn.cursor()
        cur.execute(sql, (
            data.get('client_id'),
            data.get('employee_id') or None,
            data.get('property_address'),
            data.get('service_description'),
            data.get('estimated_cost') or 0,
            data.get('estimated_labor_hours') or 0,
            data.get('estimate_date')
        ))
        new_id = cur.lastrowid
        conn.commit()
        return jsonify({'success': True, 'estimate_id': new_id, 'message': 'Estimate saved.'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── New Estimate (estimates.html) ──
@app.route('/submit/estimate', methods=['POST'])
@login_required
def submit_estimate():
    data = request.get_json() or request.form
    sql = """
        INSERT INTO Estimate
            (Client_ID, Employee_ID, Property_Address,
             Service_Description, Estimated_Cost,
             Estimated_Labor_Hours, Estimate_Date)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})
    try:
        cur = conn.cursor()
        cur.execute(sql, (
            data.get('client_id'),
            data.get('employee_id') or None,
            data.get('property_address'),
            data.get('service_description'),
            data.get('estimated_cost') or 0,
            data.get('estimated_labor_hours') or 0,
            data.get('estimate_date')
        ))
        new_estimate_id = cur.lastrowid

        # If job costing fields provided, save them too
        jc_service_id   = data.get('service_id')
        jc_actual_hours = data.get('actual_labor_hours')
        jc_actual_labor = data.get('actual_labor_cost')
        jc_actual_mats  = data.get('actual_materials')
        jc_actual_total = data.get('total_actual_cost')
        jc_est_total    = data.get('total_estimated_cost') or data.get('estimated_cost') or 0

        if jc_service_id and jc_actual_total:
            cur.execute("""
                INSERT INTO Job_Costing
                    (Service_ID, Estimate_ID, Actual_Labor_Hours, Actual_Labor_Cost,
                     Actual_Materials, Total_Actual_Cost, Total_Estimated_Cost)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                jc_service_id, new_estimate_id,
                jc_actual_hours or 0, jc_actual_labor or 0,
                jc_actual_mats or 0, jc_actual_total,
                jc_est_total
            ))

        conn.commit()
        return jsonify({'success': True, 'estimate_id': new_estimate_id, 'message': 'Estimate saved.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── API: All estimates ──
@app.route('/api/all-estimates')
@login_required
def api_all_estimates():
    sql = """
        SELECT e.Estimate_ID, c.Client_Name, c.Client_ID,
               e.Property_Address, e.Service_Description,
               e.Estimated_Cost, e.Estimated_Labor_Hours,
               e.Estimate_Date,
               emp.Employee_Name, emp.Employee_Role
        FROM Estimate e
        JOIN Client   c   ON e.Client_ID  = c.Client_ID
        LEFT JOIN Employee emp ON e.Employee_ID = emp.Employee_ID
        ORDER BY e.Estimate_Date DESC
    """
    return jsonify(query_db(sql))


# ── FORM 4: Payment Entry (billing.html) ──
@app.route('/submit/invoice', methods=['POST'])
@login_required
def submit_invoice():
    data = request.get_json() or request.form
    sql = """
        INSERT INTO Invoice
            (Contract_ID, Client_ID, Invoice_Date, Due_Date,
             Total_Amount, Amount_Paid, Invoice_Status)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    total  = float(data.get('total_amount', 0))
    paid   = float(data.get('amount_paid', 0))
    # Auto-set status based on amounts
    if paid <= 0:
        status = 'Unpaid'
    elif paid >= total:
        status = 'Paid'
    else:
        status = 'Partial'

    ok, msg = exec_db(sql, (
        data.get('contract_id') or None,
        data.get('client_id'),
        data.get('invoice_date'),
        data.get('due_date'),
        total,
        paid,
        status
    ))
    return jsonify({'success': ok, 'message': msg, 'status_set': status})


@app.route('/submit/payment', methods=['POST'])
@login_required
def submit_payment():
    data = request.get_json() or request.form
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'DB connection failed'})
    try:
        cur = conn.cursor()
        # Insert payment record
        cur.execute("""
            INSERT INTO Payment
                (Contract_ID, Invoice_ID, Payment_Amount,
                 Payment_Method, Due_Date, Payment_Date, Payment_Status)
            VALUES (%s, %s, %s, %s, %s, %s, 'Paid')
        """, (
            data.get('contract_id'),
            data.get('invoice_id'),
            data.get('payment_amount'),
            data.get('payment_method'),
            data.get('due_date'),
            data.get('payment_date')
        ))
        # Update invoice amount paid & status
        cur.execute("""
            UPDATE Invoice
            SET Amount_Paid = Amount_Paid + %s,
                Invoice_Status = CASE
                  WHEN (Amount_Paid + %s) >= Total_Amount THEN 'Paid'
                  WHEN (Amount_Paid + %s) > 0             THEN 'Partial'
                  ELSE 'Unpaid'
                END
            WHERE Invoice_ID = %s
        """, (
            data.get('payment_amount'),
            data.get('payment_amount'),
            data.get('payment_amount'),
            data.get('invoice_id')
        ))
        conn.commit()
        return jsonify({'success': True, 'message': 'Payment recorded and invoice updated.'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── Job Costing Form Submission ──
@app.route('/submit/job-costing', methods=['POST'])
@login_required
def submit_job_costing():
    data = request.get_json() or request.form
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})
    try:
        cur = conn.cursor()
        actual_total = float(data.get('total_actual_cost') or 0)
        est_total    = float(data.get('total_estimated_cost') or 0)

        cur.execute("""
            INSERT INTO Job_Costing
                (Service_ID, Estimate_ID, Actual_Labor_Hours, Actual_Labor_Cost,
                 Actual_Materials, Total_Actual_Cost, Total_Estimated_Cost)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            data.get('service_id')  or None,
            data.get('estimate_id') or None,
            data.get('actual_labor_hours')  or 0,
            data.get('actual_labor_cost')   or 0,
            data.get('actual_materials')    or 0,
            actual_total,
            est_total
        ))
        new_id = cur.lastrowid
        conn.commit()
        variance = round(actual_total - est_total, 2)
        return jsonify({
            'success':    True,
            'job_cost_id': new_id,
            'variance':   variance,
            'status':     'Over Budget' if variance > 0 else ('Under Budget' if variance < 0 else 'On Budget'),
            'message':    'Job costing record saved.'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── Add New Employee ──
# No @login_required here — the page itself is protected; removing it
# prevents Flask from silently redirecting the JSON POST to /login.
@app.route('/submit/employee', methods=['POST'])
def submit_employee():
    data  = request.get_json() or request.form
    name  = (data.get('employee_name') or '').strip()
    role  = (data.get('employee_role') or '').strip()
    phone = (data.get('employee_phone') or '').strip()
    email = (data.get('employee_email') or '').strip()

    if not name:
        return jsonify({'success': False, 'message': 'Employee name is required.'})
    if not role:
        return jsonify({'success': False, 'message': 'Employee role is required.'})

    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database. Make sure XAMPP is running.'})
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """INSERT INTO Employee (Employee_Name, Employee_Role, Employee_Phone, Employee_Email, Is_Available)
               VALUES (%s, %s, %s, %s, 1)""",
            (name, role, phone or None, email or None)
        )
        new_id = cur.lastrowid
        conn.commit()
        return jsonify({
            'success':       True,
            'employee_id':   new_id,
            'employee_name': name,
            'employee_role': role,
            'message':       f'Employee {name} added with ID {new_id}.'
        })
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── Employee Status Update (employee-portal.html) ──
@app.route('/submit/employee-status', methods=['POST'])
def submit_employee_status():
    data        = request.get_json() or request.form
    employee_id = data.get('employee_id')
    is_active   = data.get('is_active')   # '1' = Active, '0' = Inactive

    if not employee_id or is_active is None:
        return jsonify({'success': False, 'message': 'Employee ID and status are required.'})

    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})
    try:
        cur = conn.cursor(dictionary=True)
        # Update Is_Available in Employee table
        cur.execute(
            "UPDATE Employee SET Is_Available = %s WHERE Employee_ID = %s",
            (int(is_active), int(employee_id))
        )
        conn.commit()
        if cur.rowcount == 0:
            return jsonify({'success': False, 'message': 'Employee not found.'})
        # Return updated record
        cur.execute(
            "SELECT Employee_ID, Employee_Name, Employee_Role, Is_Available FROM Employee WHERE Employee_ID = %s",
            (int(employee_id),)
        )
        emp = cur.fetchone()
        return jsonify({'success': True, 'employee': emp, 'message': 'Status updated successfully.'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── API: All Referrals with client name lookups ──
@app.route('/api/referrals')
@login_required
def api_referrals():
    referrer_id = request.args.get('referrer_id', '')
    sql = """
        SELECT
            r.Referral_ID,
            r.Referee_Name,
            r.Referrer_ID,
            referrer.Client_Name  AS Referrer_Name,
            r.Referee_ID,
            referee.Client_Name   AS Referee_Client_Name,
            r.Referral_Date,
            r.Status
        FROM Referral r
        LEFT JOIN Client referrer ON r.Referrer_ID = referrer.Client_ID
        LEFT JOIN Client referee  ON r.Referee_ID  = referee.Client_ID
        WHERE 1=1
    """
    params = []
    if referrer_id:
        sql += " AND r.Referrer_ID = %s"
        params.append(referrer_id)
    sql += " ORDER BY r.Referral_Date DESC"
    return jsonify(query_db(sql, params))


# ── Referral submission (ae-home.html — public) ──
# Per DFD 7.0 and data dictionary: only Referee_Name is written
# from the public form. Referrer_ID / Referee_ID are set by managers.
@app.route('/submit/referral', methods=['POST'])
def submit_referral():
    data        = request.get_json() or request.form
    referee_name = data.get('referee_name', '').strip()
    referrer_id  = data.get('referrer_id') or None   # optional — existing client ID

    if not referee_name:
        return jsonify({'success': False, 'message': 'Please enter the name of the person you are referring.'})

    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Could not connect to database.'})
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO Referral (Referrer_ID, Referee_Name, Referral_Date, Status)
            VALUES (%s, %s, CURDATE(), 'Pending')
        """, (referrer_id, referee_name))
        new_id = cur.lastrowid
        conn.commit()
        return jsonify({
            'success':     True,
            'referral_id': new_id,
            'message':     'Referral submitted successfully.'
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        conn.close()


# ── Public clients list for ae-home forms ──
@app.route('/api/public/clients')
def api_public_clients():
    return jsonify(query_db("SELECT Client_ID, Client_Name FROM Client ORDER BY Client_Name"))

@app.route('/api/public/services-by-client')
def api_public_services_by_client():
    client_id = request.args.get('client_id', '')
    if not client_id:
        return jsonify([])
    return jsonify(query_db(
        "SELECT Service_ID, Service_Type, Service_Date FROM Service WHERE Client_ID = %s ORDER BY Service_Date DESC",
        [client_id]
    ))


# ─────────────────────────────────────────────
#  RUN
# ─────────────────────────────────────────────
if __name__ == '__main__':
    print("=" * 55)
    print("  A & E Landscaping — Flask App")
    print("  http://127.0.0.1:5000")
    print("  DB: ae_landscaping @ XAMPP MySQL :3306")
    print("=" * 55)
    app.run(debug=True, port=5000)
