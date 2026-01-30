from flask import Flask, render_template, jsonify, request
import sqlite3
import os

app = Flask(__name__)
DB_PATH = "mousse.db"


# ======================================================
# DB helper
# ======================================================
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def fmt_eur_per_kg(v):
    if v is None:
        return None
    try:
        return f"{float(v):.2f} €/kg"
    except Exception:
        return None


def fmt_co2(v):
    if v is None:
        return None
    try:
        return f"{float(v):.2f} kgCO₂e/kg"
    except Exception:
        return None


# ======================================================
# API — MOUSSES (catalogue)
# ======================================================
@app.route("/api/foam-types")
def api_foam_types():
    """
    Utilisé par index.html (catalogue).
    On renvoie l'essentiel : code, name, image_path.
    """
    db = get_db()
    rows = db.execute(
        """
        SELECT id, code, name, family, image_path
        FROM foam_types
        ORDER BY name;
        """
    ).fetchall()
    db.close()
    return jsonify([dict(r) for r in rows])


@app.route("/api/foam-types/<code>")
def api_foam_type_detail(code):
    """
    Fiche technique structurée (ordre logique demandé côté front) :
      1) family
      2) visual_aspect
      3) composition (détaillée)
      4) physical properties
      5) dangers (use + recycling)
      6) standards
      7) reuse_routes
    """
    db = get_db()

    foam = db.execute(
        """
        SELECT
            id, code, name, family, visual_aspect,
            density_kg_m3, reuse_routes, image_path
        FROM foam_types
        WHERE code = ?;
        """,
        (code,),
    ).fetchone()

    if not foam:
        db.close()
        return jsonify({"error": "Mousse introuvable"}), 404

    foam_id = foam["id"]

    # Composition détaillée
    comp = db.execute(
        """
        SELECT category, component, typical, notes
        FROM foam_composition_items
        WHERE foam_type_id = ?
        ORDER BY
          CASE lower(category)
            WHEN 'polymère' THEN 0
            WHEN 'composite' THEN 1
            WHEN 'charges' THEN 2
            WHEN 'plastifiants' THEN 3
            WHEN 'vulcanisation' THEN 4
            WHEN 'additifs' THEN 5
            WHEN 'rf' THEN 6
            ELSE 99
          END,
          component;
        """,
        (foam_id,),
    ).fetchall()

    # Propriétés physiques
    props = db.execute(
        """
        SELECT property, value, unit, standard, notes
        FROM foam_physical_properties
        WHERE foam_type_id = ?
        ORDER BY id;
        """,
        (foam_id,),
    ).fetchall()

    # Dangers : use + recycling (pas fabrication)
    haz_use = db.execute(
        """
        SELECT hazard, mitigation
        FROM foam_hazards
        WHERE foam_type_id = ? AND phase='use'
        ORDER BY id;
        """,
        (foam_id,),
    ).fetchall()

    haz_recy = db.execute(
        """
        SELECT hazard, mitigation
        FROM foam_hazards
        WHERE foam_type_id = ? AND phase='recycling'
        ORDER BY id;
        """,
        (foam_id,),
    ).fetchall()

    # Normes
    stds = db.execute(
        """
        SELECT domain, standard_ref, title, notes
        FROM foam_standards
        WHERE foam_type_id = ?
        ORDER BY
          CASE lower(domain)
            WHEN 'feu' THEN 0
            WHEN 'fumées' THEN 1
            WHEN 'tests' THEN 2
            ELSE 99
          END,
          standard_ref;
        """,
        (foam_id,),
    ).fetchall()

    db.close()

    # Réponse structurée + quelques champs utiles
    out = dict(foam)
    out["composition_items"] = [dict(r) for r in comp]
    out["physical_properties"] = [dict(r) for r in props]
    out["hazards"] = {
        "use": [dict(r) for r in haz_use],
        "recycling": [dict(r) for r in haz_recy],
    }
    out["standards"] = [dict(r) for r in stds]

    # Petit bonus : densité “display” si besoin
    if out.get("density_kg_m3") is not None:
        out["density_display"] = f"{out['density_kg_m3']} kg/m³"
    else:
        out["density_display"] = None

    return jsonify(out)


# ======================================================
# API — OPTIONS DE RECYCLAGE
# ======================================================
@app.route("/api/recycling-options")
def api_recycling_options():
    """
    Utilisé par methods.html : liste des méthodes pour une mousse.
    Exige: foam_code
    Retourne : name + cost_eur_per_kg + co2_saved_kg_per_kg_foam (+ display)
    """
    foam_code = request.args.get("foam_code")
    if not foam_code:
        return jsonify({"error": "foam_code manquant"}), 400

    db = get_db()
    rows = db.execute(
        """
        SELECT
            ro.id,
            ro.foam_type_id,
            ro.process_method_id,
            ro.name,
            ro.description,
            ro.cost_eur_per_kg,
            ro.co2_saved_kg_per_kg_foam,
            ro.benefit,
            ro.notes,

            ft.code AS foam_code,
            ft.name AS foam_name,
            ft.density_kg_m3 AS foam_density_kg_m3,

            pm.name AS process_method_name,
            pm.code AS process_method_code
        FROM recycling_options ro
        JOIN foam_types ft ON ft.id = ro.foam_type_id
        LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
        WHERE ft.code = ?
        ORDER BY ro.id;
        """,
        (foam_code,),
    ).fetchall()
    db.close()

    out = []
    for r in rows:
        d = dict(r)
        d["cost_display"] = fmt_eur_per_kg(d.get("cost_eur_per_kg"))
        d["co2_display"] = fmt_co2(d.get("co2_saved_kg_per_kg_foam"))
        out.append(d)

    return jsonify(out)


@app.route("/api/recycling-options/<int:option_id>")
def api_recycling_option_detail(option_id):
    """
    Utilisé par method.html : détail d'une méthode.
    Doit contenir : description (en haut), coût, CO2, bénéfice, process, prereq, precautions, calc.
    """
    db = get_db()
    row = db.execute(
        """
        SELECT
            ro.*,
            ft.code AS foam_code,
            ft.name AS foam_name,
            ft.density_kg_m3 AS foam_density_kg_m3,
            pm.name AS process_method_name,
            pm.code AS process_method_code
        FROM recycling_options ro
        JOIN foam_types ft ON ft.id = ro.foam_type_id
        LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
        WHERE ro.id = ?;
        """,
        (option_id,),
    ).fetchone()
    db.close()

    if not row:
        return jsonify({"error": "Méthode introuvable"}), 404

    d = dict(row)
    d["cost_display"] = fmt_eur_per_kg(d.get("cost_eur_per_kg"))
    d["co2_display"] = fmt_co2(d.get("co2_saved_kg_per_kg_foam"))
    return jsonify(d)


# ======================================================
# API — ENTREPRISES
# ======================================================
@app.route("/api/companies")
def api_companies():
    """
    - /api/companies?recycling_option_id=XX : entreprises liées à une méthode
    - /api/companies : liste complète
    - /api/companies?search=... : filtre simple (nom/ville/pays/type)
    """
    recycling_option_id = request.args.get("recycling_option_id", type=int)
    search = (request.args.get("search") or "").strip().lower()

    db = get_db()

    if recycling_option_id:
        rows = db.execute(
            """
            SELECT c.*
            FROM companies c
            JOIN company_recycling_options cro
              ON cro.company_id = c.id
            WHERE cro.recycling_option_id = ?
            ORDER BY
              CASE WHEN lower(c.country) = 'france' THEN 0 ELSE 1 END,
              c.country, c.name;
            """,
            (recycling_option_id,),
        ).fetchall()
        db.close()
        return jsonify([dict(r) for r in rows])

    # liste globale (+ recherche)
    if search:
        rows = db.execute(
            """
            SELECT *
            FROM companies
            WHERE
              lower(name) LIKE ?
              OR lower(ifnull(city,'')) LIKE ?
              OR lower(ifnull(country,'')) LIKE ?
              OR lower(ifnull(company_type,'')) LIKE ?
            ORDER BY
              CASE WHEN lower(country) = 'france' THEN 0 ELSE 1 END,
              country, name;
            """,
            (f"%{search}%", f"%{search}%", f"%{search}%", f"%{search}%"),
        ).fetchall()
    else:
        rows = db.execute(
            """
            SELECT *
            FROM companies
            ORDER BY
              CASE WHEN lower(country) = 'france' THEN 0 ELSE 1 END,
              country, name;
            """
        ).fetchall()

    db.close()
    return jsonify([dict(r) for r in rows])


@app.route("/api/companies/<int:company_id>")
def api_company(company_id):
    """
    company.html : doit afficher une description (notes) puis infos utiles.
    """
    db = get_db()
    row = db.execute("SELECT * FROM companies WHERE id = ?;", (company_id,)).fetchone()
    db.close()

    if not row:
        return jsonify({"error": "Entreprise introuvable"}), 404

    return jsonify(dict(row))


# (optionnel mais pratique) : savoir quelles méthodes une entreprise gère
@app.route("/api/companies/<int:company_id>/recycling-options")
def api_company_options(company_id):
    db = get_db()
    rows = db.execute(
        """
        SELECT
          ro.id,
          ro.name,
          ro.description,
          ro.cost_eur_per_kg,
          ro.co2_saved_kg_per_kg_foam,
          ro.benefit,
          ft.code AS foam_code,
          ft.name AS foam_name
        FROM company_recycling_options cro
        JOIN recycling_options ro ON ro.id = cro.recycling_option_id
        JOIN foam_types ft ON ft.id = ro.foam_type_id
        WHERE cro.company_id = ?
        ORDER BY ft.name, ro.id;
        """,
        (company_id,),
    ).fetchall()
    db.close()

    out = []
    for r in rows:
        d = dict(r)
        d["cost_display"] = fmt_eur_per_kg(d.get("cost_eur_per_kg"))
        d["co2_display"] = fmt_co2(d.get("co2_saved_kg_per_kg_foam"))
        out.append(d)

    return jsonify(out)


# ======================================================
# PAGES — FRONT (inchangé pour l’instant)
# ======================================================
@app.route("/")
def page_index():
    return render_template("index.html")


@app.route("/foam/<code>")
def page_foam(code):
    return render_template("foam.html", foam_code=code)


@app.route("/foam/<code>/methods")
def page_methods(code):
    quantity = request.args.get("quantity")
    unit = request.args.get("unit")
    return render_template("methods.html", foam_code=code, quantity=quantity, unit=unit)


@app.route("/foam/<code>/method/<int:option_id>")
def page_method(code, option_id):
    quantity = request.args.get("quantity")
    unit = request.args.get("unit")
    return render_template(
        "method.html",
        foam_code=code,
        option_id=option_id,
        quantity=quantity,
        unit=unit,
    )


@app.route("/company/<int:company_id>")
def page_company(company_id):
    return render_template("company.html", company_id=company_id)


# ======================================================
# RUN
# ======================================================
if __name__ == "__main__":
    if not os.path.exists(DB_PATH):
        print("⚠️ Base absente : lance `sqlite3 mousse.db < schema.sql`")
    app.run(debug=True)
