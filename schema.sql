-- =========================================================
-- schema.sql — Projet “Mousses • Recyclage & filières”
-- Refonte DB pour coller à ta consigne UI (ordre & contenu fiche)
--
-- ✅ Noms mousses : sans “anti-feu”, plus parlants
-- ✅ Composition détaillée (table normalisée) — utilisable pour afficher “le détail”
-- ✅ Propriétés physiques (table normalisée)
-- ✅ Dangers : uniquement usage + recyclage (pas fabrication)
-- ✅ Normes : table normalisée
-- ✅ Filières de réutilisation : champ dédié
-- ✅ Méthodes : coût €/kg + CO2 eq (kgCO2e/kg) + bénéfice + process + précautions + calculs
-- ✅ Entreprises : description (champ notes) + infos utiles + logos
-- =========================================================

PRAGMA foreign_keys = ON;

-- =========================
-- RESET
-- =========================
DROP TABLE IF EXISTS company_recycling_options;
DROP TABLE IF EXISTS companies;

DROP TABLE IF EXISTS recycling_options;
DROP TABLE IF EXISTS process_methods;

DROP TABLE IF EXISTS foam_standards;
DROP TABLE IF EXISTS foam_hazards;
DROP TABLE IF EXISTS foam_physical_properties;
DROP TABLE IF EXISTS foam_composition_items;
DROP TABLE IF EXISTS foam_types;

-- =========================
-- 1) MOUSSES (fiche technique)
-- =========================
CREATE TABLE foam_types (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  code            TEXT NOT NULL UNIQUE,    -- EPDM, PU, ...
  name            TEXT NOT NULL,           -- nom “parlant” (sans anti-feu)

  family          TEXT NOT NULL,           -- affiché en 1er dans la fiche
  visual_aspect   TEXT,                    -- affiché en 2e
  density_kg_m3   REAL,                    -- utile conversion volume->masse

  -- affiché en dernier dans la fiche
  reuse_routes    TEXT,

  -- image
  image_path      TEXT NOT NULL            -- img/xxx.jpg  => /static/img/xxx.jpg
);

-- =========================
-- 1.b) COMPOSITION DÉTAILLÉE
-- =========================
CREATE TABLE foam_composition_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  foam_type_id INTEGER NOT NULL,
  category     TEXT NOT NULL,      -- Polymère / Charges / Plastifiants / Vulcanisation / RF / Autres
  component    TEXT NOT NULL,      -- ex: EPDM, noir de carbone...
  typical      TEXT,               -- ex: “majoritaire”, “faible teneur”, “selon formulation”
  notes        TEXT,
  FOREIGN KEY (foam_type_id) REFERENCES foam_types(id) ON DELETE CASCADE
);

-- =========================
-- 1.c) PROPRIÉTÉS PHYSIQUES
-- =========================
CREATE TABLE foam_physical_properties (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  foam_type_id INTEGER NOT NULL,
  property     TEXT NOT NULL,      -- ex: Densité, Température service...
  value        TEXT NOT NULL,      -- ex: "90–180"
  unit         TEXT,               -- ex: "kg/m³"
  standard     TEXT,               -- ex: "ISO 845" (si applicable)
  notes        TEXT,
  FOREIGN KEY (foam_type_id) REFERENCES foam_types(id) ON DELETE CASCADE
);

-- =========================
-- 1.d) DANGERS (UNIQUEMENT usage + recyclage)
-- =========================
CREATE TABLE foam_hazards (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  foam_type_id INTEGER NOT NULL,
  phase        TEXT NOT NULL CHECK(phase IN ('use','recycling')),
  hazard       TEXT NOT NULL,
  mitigation   TEXT,
  FOREIGN KEY (foam_type_id) REFERENCES foam_types(id) ON DELETE CASCADE
);

-- =========================
-- 1.e) NORMES (liste structurée)
-- =========================
CREATE TABLE foam_standards (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  foam_type_id INTEGER NOT NULL,
  domain       TEXT NOT NULL,   -- Feu / Fumées / Matériaux / Tests / etc.
  standard_ref TEXT NOT NULL,   -- ex: "ISO 845"
  title        TEXT,
  notes        TEXT,
  FOREIGN KEY (foam_type_id) REFERENCES foam_types(id) ON DELETE CASCADE
);

-- =========================
-- 2) RÉFÉRENTIEL PROCÉDÉS (générique)
-- =========================
CREATE TABLE process_methods (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  code                  TEXT NOT NULL UNIQUE,
  name                  TEXT NOT NULL,

  yield_low_percent     REAL,
  yield_high_percent    REAL,

  capex_low_k_eur       REAL,
  capex_high_k_eur      REAL,

  cost_low_eur_per_t    REAL,
  cost_mid_eur_per_t    REAL,
  cost_high_eur_per_t   REAL,

  notes                 TEXT
);

INSERT INTO process_methods
(code, name, yield_low_percent, yield_high_percent, capex_low_k_eur, capex_high_k_eur, cost_low_eur_per_t, cost_mid_eur_per_t, cost_high_eur_per_t, notes)
VALUES
('DEVULC_TME', 'Dévulcanisation thermo-mécanique', 50, 80, 200, 700, 120, 180, 260, 'Rupture sélective des ponts soufrés ; qualité dépend du flux.'),
('GRIND_AMB',  'Broyage ambiant (granulat/poudre)', 70, 95, 50, 350, 80, 130, 200, 'Robuste, dépend du tri et de la propreté.'),
('GRIND_CRYO', 'Broyage cryogénique', 85, 98, 300, 1200, 280, 420, 650, 'Granulométrie fine, dépend des coûts LN2.'),
('PU_GLYCO',   'Glycolyse / alcoholyse (PU)', 70, 90, 500, 4000, -50, 80, 250, 'Récupération polyols si filière structurée.'),
('PYRO',       'Pyrolyse', 40, 65, 1500, 12000, 250, 450, 900, 'Huiles + gaz ; nécessite traitement émissions.');

-- =========================
-- 3) OPTIONS DE RECYCLAGE
-- =========================
CREATE TABLE recycling_options (
  id                        INTEGER PRIMARY KEY AUTOINCREMENT,
  foam_type_id              INTEGER NOT NULL,
  process_method_id         INTEGER,

  name                      TEXT NOT NULL,                 -- affichage
  description               TEXT NOT NULL,                 -- “intro” (début page method)
  cost_eur_per_kg           REAL NOT NULL DEFAULT 0.0,     -- coût (€/kg)
  co2_saved_kg_per_kg_foam  REAL NOT NULL DEFAULT 0.0,     -- kgCO2e/kg mousse (positif = gain)

  benefit                   TEXT NOT NULL,                 -- bénéfice possible après recyclage

  method_process            TEXT NOT NULL,
  method_prerequisites      TEXT NOT NULL,
  method_precautions        TEXT NOT NULL,
  calc_details              TEXT NOT NULL,

  notes                     TEXT,

  FOREIGN KEY (foam_type_id) REFERENCES foam_types(id) ON DELETE CASCADE,
  FOREIGN KEY (process_method_id) REFERENCES process_methods(id) ON DELETE SET NULL
);

-- =========================
-- 4) ENTREPRISES
-- =========================
CREATE TABLE companies (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL,
  company_type TEXT,       -- recycler / equipment / chemicals / sorting / energy / other

  country      TEXT,
  city         TEXT,
  address      TEXT,

  website      TEXT,
  email        TEXT,
  phone        TEXT,

  logo_path    TEXT,       -- company/...

  notes        TEXT        -- description entreprise (affichée avant infos utiles)
);

-- =========================
-- 5) LIEN entreprise -> options
-- =========================
CREATE TABLE company_recycling_options (
  company_id          INTEGER NOT NULL,
  recycling_option_id INTEGER NOT NULL,
  PRIMARY KEY (company_id, recycling_option_id),
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (recycling_option_id) REFERENCES recycling_options(id) ON DELETE CASCADE
);

-- =========================================================
-- DONNÉES — MOUSSES (noms sans “anti-feu”)
-- (✅ MAJ famille / aspect / densité / filières depuis ton texte)
-- =========================================================
INSERT INTO foam_types
(code, name, family, visual_aspect, density_kg_m3, reuse_routes, image_path)
VALUES
('EPDM', 'Mousse EPDM ',
 'Caoutchouc synthétique EPDM (terpolymère saturé) à cellules fermées. Élastomère durable (UV/ozone/intempéries) ; la version ignifugée intègre des additifs retardateurs de flamme et parfois un traitement de surface.',
 'Mousse noire (chargée en noir de carbone), souple, avec peau extérieure fine (moulage/continu). Cellules fermées homogènes : aspect lisse, légèrement compressible.',
 165,
 'Broyage en granulat réutilisable (jusqu’à ~20 % dans des mélanges). Valorisation en revêtements de sols sportifs/sécurité (1–4 mm), dalles agglomérées liant PU, panneaux/bourres d’isolation thermo-acoustique pour ERP, joints techniques (auto/bâtiment) et solutions antivibratoires.',
 'img/epdm.jpg'),

('PU', 'Mousse polyuréthane souple ',
 'Polymère thermodurci alvéolaire formé par polyaddition polyol + isocyanate (famille uréthanes). Présent en mousse souple (confort/doublures) et rigide (isolants). Version ignifugée : additifs anti-feu (phosphore/azote, parfois graphite) et/ou traitement post-moussage.',
 'Souple à cellules ouvertes (spongieuse) pour les versions confort (souvent jaunâtre pâle à grise selon additifs). Les versions rigides anti-feu (PIR) sont à cellules fermées, aspect mousse isolante friable (crème).',
 40,
 'Réemploi chutes propres en calage/rembourrage. Rebonding (mousse réagglomérée) en sous-couches, tapis, dalles. Recyclage chimique (glycolyse/alcoholyse) pour récupérer des polyols et fabriquer de nouvelles mousses (y compris anti-feu). Broyage/charges isolantes pour mousses rigides (réincorporation limitée ~15–20 %).',
 'img/pu.jpg'),

('SBR', 'Mousse SBR ',
 'Élastomère SBR', 'Noire, résiliente, cellules mixtes à plutôt fermées.', 140,
 'Réutilisation : calage, pièces non critiques si chutes propres et tracées.',
 'img/sbr.jpg'),

('NBR', 'Mousse NBR ',
 'Caoutchouc synthétique thermodurci (élastomère vulcanisé) à base de copolymère nitrile-butadiène, formulé en mousse à cellules fermées. Résistant aux huiles ; version ignifugée par additifs (souvent sans halogènes).',
 'Mousse alvéolaire à cellules fermées, généralement noire (noir de carbone). Surface semi-lisse avec peau externe (moulage). Texture souple et compressible, densité plus élevée qu’une mousse standard (fortes charges).',
 225,
 'Réemploi matière : poudrets/granulés incorporables jusqu’à ~20 % sans forte perte mécanique. Usages : joints conformes EPI (huiles/chaleur), isolants acoustiques/thermiques pour ERP, gaines/câblage ignifuges (ferroviaire), pièces moulées techniques (amortissement/capteurs).',
 'img/nbr.jpg'),

('CR', 'Mousse néoprène (chloroprène) ',
 'Caoutchouc synthétique polychloroprène (CR) vulcanisé, mousse à cellules fermées. Naturellement moins inflammable (chlore dans le polymère). Grades EPI formulés pour résistance au feu accrue.',
 'Mousse souple noire ou gris foncé. Très flexible (type néoprène). Surface parfois tissuée/jersey, sinon brute avec peau lisse issue du moulage.',
 200,
 'Broyage en granulés (1–3 mm) réutilisables comme charges dans mélanges CR/caoutchoucs chlorés (jusqu’à ~20 %). Usages : joints bâtiment (intempéries), supports antivibratoires, isolants composites pour cloisons coupe-feu, membranes/revêtements résistants au feu (liant PU/bitume) si conformité maintenue.',
 'img/cr.jpg'),

('SIL', 'Mousse silicone ',
 'Élastomère silicone (PDMS) cellulaire. Polymère inorganique (chaîne Si–O) réticulé (polyaddition platine ou peroxyde). Intrinsèquement très performant au feu : faible toxicité de fumées, excellente tenue en température.',
 'Mousse à cellules fermées ou ouvertes selon procédé, souvent gris pâle/orange (ou gris/noir si chargée). Toucher très doux possible. Peau externe fine lisse (moule/extrusion).',
 300,
 'Filières limitées : broyage en poudre/granulés silicone inertes utilisables comme charges dans plastiques/élastomères thermoplastiques, gaines électriques (amélioration diélectrique) ou réincorporation partielle dans silicone neuf. Voies “chimie” émergentes : récupération en huiles silicone/silice (niche).',
 'img/silicone.jpg'),

('PFN', 'Composite PF/NBR/Phosphate ',
 'Composite thermodurci cellulaire : résine phénolique (PF) modifiée par NBR + additifs phosphatés intumescents (ex. phosphate dihydrogène d’aluminium) et charges minérales. Très haute résistance au feu (quasi incombustible).',
 'Mousse rigide à semi-rigide brun/noir. Alvéoles fermées ; plus cassante qu’une mousse élastomère (riche en résine). Souvent en panneaux/blocs usinés.',
 125,
 'Pas de filière grand public : (1) broyage ultrafin (charge ignifuge haute performance) pour composites/résines techniques ; (2) alcoolyse/extraction de composés phosphatés (voie R&D) ; (3) pyrolyse inerte contrôlée pour récupérer phosphates inorganiques (AlPO₄) ; (4) réemploi direct en “système” si pièces compatibles et tracées.',
 'img/pfn.jpg');

-- =========================================================
-- COMPOSITION (structurée) — MAJ depuis ton texte
-- =========================================================

-- EPDM
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='EPDM'),
  'Composition',
  'EPDM (100 phr) + noir de carbone (40 phr) + ZnO (5 phr) + acide stéarique (1 phr) + ADC (10-15 phr) + retardateurs flamme (ATH 100-150 phr, phosphates organiques)',
  NULL,
  NULL
);

-- PU
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='PU'),
  'Composition',
  'Polyol (100 phr) + isocyanate MDI/TDI (80–140 phr) + agent moussant eau / pentane / CO₂ (0.5–20 phr) + catalyseurs amines / organométalliques (0.1–2 phr) + surfactants silicones (0.5–3 phr) + retardateurs flamme phosphates / mélamine / graphite (5–30 phr)',
  NULL,
  NULL
);
-- SBR (inchangé)
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='SBR'),
  'Composition',
  'SBR (100 phr) + charges (20–80 phr) + ZnO (3–5 phr) + acide stéarique (1–2 phr) + plastifiants (0–30 phr) + soufre (1–3 phr) + accélérateurs (0.5–2.5 phr) + agent moussant ADC (2–12 phr) + retardateurs flamme ATH / phosphates / mélamine (10–150 phr)',
  NULL,
  NULL
);

-- NBR
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='NBR'),
  'Composition',
  'NBR (100 phr) + ATH hydroxyde d aluminium (195 phr) + Graphite expansible/Phosphore rouge/APP (10-30 phr) + ADC agent moussant + ZnO + acide stéarique + DOP + retardateurs flamme sans halogène',
  NULL,
  NULL
);

-- CR
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='CR'),
  'Composition',
  'Polychloroprène (100 phr) + charges renforçantes (20–60 phr) + MgO (3–8 phr) + ZnO (3–6 phr) + acide stéarique (0.5–2 phr) + plastifiant (0–15 phr) + agent moussant ADC ou bicarbonate (2–10 phr) + retardateurs flamme phosphates ± antimoine (10–40 phr)',
  NULL,
  NULL
);

-- SIL
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='SIL'),
  'Composition',
  'PDMS (100 phr) + silice pyrogénée (15–45 phr) + mica / charges minérales (10–60 phr) + agent moussant bicarbonate ou ADC (1–8 phr) + retardateurs flamme oxydes / ATH (20–120 phr) + système de réticulation platine ou peroxyde (0.01–2 phr)',
  NULL,
  NULL
);

-- PFN
INSERT INTO foam_composition_items (foam_type_id, category, component, typical, notes)
VALUES (
  (SELECT id FROM foam_types WHERE code='PFN'),
  'Composition',
  'Résine phénolique PF (100 phr) + NBR (10–40 phr) + ADP phosphate d’aluminium (20–80 phr) + alumine Al₂O₃ (20–100 phr) + charges renforçantes (10–60 phr) + agent moussant (0–10 phr) + durcisseur (1–10 phr)',
  NULL,
  NULL
);

-- =========================================================
-- PROPRIÉTÉS PHYSIQUES — MAJ depuis ton texte
-- =========================================================

-- EPDM
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='EPDM'),'Densité (ordre de grandeur)','130–200','kg/m³','ISO 845','Peut augmenter si très chargée RF.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Conductivité thermique','~0,04','W/m·K',NULL,'Bon isolant (cellules fermées).'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Dureté (ordre de grandeur)','40–60','Shore OO',NULL,'≈ 15–25 Shore A (indicatif).'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Résistance traction','~0,4–0,5','MPa',NULL,'Ordre de grandeur.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Allongement à rupture','~150–200','%','ISO 1798','Ordre de grandeur.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Température service (continu)','~130–150','°C','ASTM D573','Excellente tenue thermique vs autres caoutchoucs.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Température service (froid)','≤ -50','°C',NULL,'Reste souple à très basse température.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Comportement au feu (LOI typique)','>28','% O₂','ISO 4589 / ASTM D2863','Auto-extinguible (char de surface).');

-- PU
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='PU'),'Densité (souple anti-feu)','~30–50','kg/m³','ISO 845','Confort/doublures.'),
((SELECT id FROM foam_types WHERE code='PU'),'Densité (rigide isolant)','~30','kg/m³','ISO 845','Panneaux isolants.'),
((SELECT id FROM foam_types WHERE code='PU'),'Densité (grades très chargés RF)','~60–100','kg/m³',NULL,'Charges type mélamine/phosphates augmentent la densité.'),
((SELECT id FROM foam_types WHERE code='PU'),'Conductivité thermique (rigide PIR)','0,022–0,028','W/m·K',NULL,'Très bon isolant.'),
((SELECT id FROM foam_types WHERE code='PU'),'Conductivité thermique (souple)','~0,04','W/m·K',NULL,'Cellules ouvertes.'),
((SELECT id FROM foam_types WHERE code='PU'),'Température service (continu)','~90','°C',NULL,'Au-delà : dégradation progressive.'),
((SELECT id FROM foam_types WHERE code='PU'),'Décomposition forte','~180','°C',NULL,'Fumées très toxiques en feu intense (CO/HCN/NOx).'),
((SELECT id FROM foam_types WHERE code='PU'),'Allongement à rupture (souple)','~50–100','%','ASTM D3574','Mousse souple se déchire plus vite.');

-- SBR (inchangé)
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='SBR'),'Densité (typique)','90–180','kg/m³','ISO 845','Selon formulation.'),
((SELECT id FROM foam_types WHERE code='SBR'),'Température de service','-30 à +100','°C',NULL,'Ordre de grandeur.');

-- NBR
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='NBR'),'Densité (typique)','150–300','kg/m³','ISO 845','Variable selon taux de charges.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Conductivité thermique','~0,04','W/m·K',NULL,'Cellules fermées : bonne isolation.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Fermeté (compression 25%)','~50','kPa',NULL,'Ordre de grandeur.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Allongement à rupture','~100–150','%','ISO 1798','Structure alvéolaire limite la déformabilité.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Température service (continu)','~100','°C',NULL,'Durcissement au-delà.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Décomposition','>200','°C',NULL,'Ordre de grandeur.'),
((SELECT id FROM foam_types WHERE code='NBR'),'LOI (indice oxygène limite)','~30 ou +','% O₂','ASTM D2863 / ISO 4589','Ignifugé : inflammabilité réduite.');

-- CR
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='CR'),'Densité (typique)','150–250','kg/m³','ISO 845','Grades industriels chargés >200 possibles.'),
((SELECT id FROM foam_types WHERE code='CR'),'Conductivité thermique','~0,05','W/m·K',NULL,'Isolation thermique correcte.'),
((SELECT id FROM foam_types WHERE code='CR'),'Compression 25%','~30–60','kPa',NULL,'Selon densité.'),
((SELECT id FROM foam_types WHERE code='CR'),'Allongement à rupture','≥150','%','ISO 1798','Bonne cohésion cellules fermées.'),
((SELECT id FROM foam_types WHERE code='CR'),'Température service (continu)','~100','°C',NULL,'Un peu < EPDM.'),
((SELECT id FROM foam_types WHERE code='CR'),'Température service (froid)','≥ -40','°C',NULL,'Reste flexible.'),
((SELECT id FROM foam_types WHERE code='CR'),'Comportement au feu','auto-extinguible','—',NULL,'Ne propage pas le feu (chlore dans polymère).');

-- SIL
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='SIL'),'Densité (gamme)','~150 à 500','kg/m³','ISO 845','Extra-soft ~200 ; firm ~450 (ordre de grandeur).'),
((SELECT id FROM foam_types WHERE code='SIL'),'Conductivité thermique','~0,1','W/m·K',NULL,'Structure cellulaire abaisse vs silicone solide.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Dureté (compression deflection 25%)','~14 à 96','kPa',NULL,'Selon grade (très souple à ferme).'),
((SELECT id FROM foam_types WHERE code='SIL'),'Allongement à rupture','~50–120','%','ISO 1798','Cellules peuvent initier rupture.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Température service (continu)','-100 à +200','°C',NULL,'Peut aller jusqu’à +250°C selon grade.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Tenue feu (structure)','jusqu’à ~400','°C',NULL,'Ne fond pas ; char/silice inerte.'),
((SELECT id FROM foam_types WHERE code='SIL'),'LOI','>35','% O₂','ISO 4589','Très faible inflammabilité.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Fumées/toxicité','très faibles','—',NULL,'Gaz principaux : CO₂, vapeur d’eau, silice fine.');

-- PFN
INSERT INTO foam_physical_properties(foam_type_id, property, value, unit, standard, notes) VALUES
((SELECT id FROM foam_types WHERE code='PFN'),'Densité (typique)','100–150','kg/m³','ISO 845','Fortement chargé minéral.'),
((SELECT id FROM foam_types WHERE code='PFN'),'Conductivité thermique','~0,04–0,05','W/m·K',NULL,'Isolation proche phénoliques isolants.'),
((SELECT id FROM foam_types WHERE code='PFN'),'Structure','rigide / semi-rigide','—',NULL,'Casse plutôt que fluage sous contrainte.'),
((SELECT id FROM foam_types WHERE code='PFN'),'Allongement à rupture','<5–10','%','ISO 1798','Faible (matériau thermodur).'),
((SELECT id FROM foam_types WHERE code='PFN'),'Tenue thermique (structure)','jusqu’à ~400','°C',NULL,'Après 30 min à 400°C : ~60 % résistance conservée (ordre de grandeur).'),
((SELECT id FROM foam_types WHERE code='PFN'),'LOI','~47,6','% O₂','ASTM D2863 / ISO 4589','Très haute résistance au feu.'),
((SELECT id FROM foam_types WHERE code='PFN'),'PHRR (pic HRR)','~6','kW/m²','ASTM E1354 (type cone)','Très bas (ordre de grandeur).');

-- =========================================================
-- DANGERS (usage + recyclage) — MAJ depuis ton texte
-- =========================================================

-- USAGE
INSERT INTO foam_hazards(foam_type_id, phase, hazard, mitigation) VALUES
((SELECT id FROM foam_types WHERE code='NBR'),'use',
 'Produit considéré inerte et sûr en conditions normales ; en incendie extrême (>300°C) possibles gaz toxiques (CO, HCN) malgré réduction fumées par charges.',
 'Respect des usages certifiés ; en feu : protection respiratoire et ventilation (procédures incendie).'),
((SELECT id FROM foam_types WHERE code='EPDM'),'use',
 'Aucun danger en usage normal ; en incendie, comportement auto-extinguible possible, fumées très faibles selon formulation (Euroclass possible B-s1,d0).',
 'Respect normes feu ; prévention incendie ; ventilation en cas d’exposition fumées.'),
((SELECT id FROM foam_types WHERE code='CR'),'use',
 'Stable en usage ; en incendie, fumées/corrosifs possibles (présence chlore, HCl âcre) même si faible propagation.',
 'Prévention incendie ; protection respiratoire si fumées ; éviter exposition aux fumées corrosives.'),
((SELECT id FROM foam_types WHERE code='SIL'),'use',
 'Matériau inerte, très faible fumée/toxicité ; sous flammes directes ne dégage pas de gaz corrosifs (sans halogènes).',
 'Usage standard ; appliquer consignes incendie générales.'),
((SELECT id FROM foam_types WHERE code='PU'),'use',
 'En incendie : risque élevé de fumées très toxiques (CO, HCN, NOx), même si ignifugé retarde l’ignition.',
 'Respect strict des normes/limitations d’usage ; éloigner des sources de chaleur ; procédures incendie adaptées.'),
((SELECT id FROM foam_types WHERE code='PFN'),'use',
 'Inerte en usage ; très haute résistance au feu (quasi incombustible) ; fumées faibles comparées aux polymères classiques.',
 'Traçabilité et conformité de conception ; prévention incendie générale.'),
((SELECT id FROM foam_types WHERE code='SBR'),'use',
 'Faible risque en service ; fumées en feu.',
 'Prévention incendie.');

-- RECYCLAGE
INSERT INTO foam_hazards(foam_type_id, phase, hazard, mitigation) VALUES
((SELECT id FROM foam_types WHERE code='NBR'),'recycling',
 'Broyage/dévulcanisation : émissions possibles de COV (styrène, toluène), HAP, poussières d’additifs ignifuges ; cryogénie : risques LN2.',
 'Captage efficace + filtration HEPA ; surveillance air ; éviter surchauffe ; EPI respiratoires ; procédures LN2/ventilation.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'recycling',
 'Broyage/dévulcanisation : poussières minérales (ATH, phosphates) + vapeurs d’antioxydants ; contrôle température nécessaire.',
 'Aspiration confinée + filtration renforcée ; contrôle T° (éviter décomposition charges) ; EPI ; contrôles air ambiant.'),
((SELECT id FROM foam_types WHERE code='CR'),'recycling',
 'Broyage : poussières chlorées ; filières thermiques : risque HCl (gaz corrosifs) si T° élevée ; présence Sb₂O₃ à gérer.',
 'Éviter échauffement ; refroidissement/aspersion ; filière thermique uniquement en unité contrôlée avec lavage gaz acides ; EPI/aspiration.'),
((SELECT id FROM foam_types WHERE code='SIL'),'recycling',
 'Dévulcanisation difficile : recyclage surtout broyage/cryo ; pyrolyse : attention cyclosiloxanes (D4/D5/D6) ; poussières fines.',
 'Broyage sous aspiration ; EPI P3 ; en thermique : ventilation et post-traitement gaz, contrôle siloxanes.'),
((SELECT id FROM foam_types WHERE code='PU'),'recycling',
 'Broyage : poussières fines ; procédés chimiques (glycolyse/alcoholyse) : vapeurs polyols/catalyseurs, T° ~180°C, risques exothermie.',
 'Réacteurs étanches + traitement vapeurs ; procédures HSE chimie ; aspiration/EPI ; contrôle température.'),
((SELECT id FROM foam_types WHERE code='PFN'),'recycling',
 'Composite thermodur : poussières minérales/phosphatées abrasives ; procédés chimiques/pyrolyse : émissions à gérer (phénoliques/phosphorées).',
 'Enceinte confinée, filtration HEPA + charbon/acide selon filière ; contrôle strict T° ; traçabilité flux.'),
((SELECT id FROM foam_types WHERE code='SBR'),'recycling',
 'Poussières au broyage ; émissions sur filières thermiques.',
 'Aspiration ; traitement émissions.');

-- =========================================================
-- NORMES — MAJ depuis ton texte (ISO 845 conservée pour toutes)
-- =========================================================

-- ISO 845 (densité mousse) - utile pour toutes
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes)
SELECT id, 'Tests', 'ISO 845', 'Détermination de la densité apparente', 'Référence courante pour mousses.'
FROM foam_types;

-- NBR
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','EN 45545-2','Exigences feu/fumées (ferroviaire)','Niveaux HL1 à HL3 selon formulation/application.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','UL94 V-0','Auto-extinguibilité (vertical)','Selon formulation/épaisseur.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','M1/M2','Classement réaction au feu (France)','Selon application/épaisseur.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Tests','ASTM D2863','Indice d’oxygène limite (LOI)','Mesure inflammabilité.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Fumées','ASTM E662','Densité de fumée','Selon exigences.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','FMVSS 302','Inflammabilité matériaux intérieurs véhicules','Selon application.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','NF F 16-101','Classification feu/fumées (transport)','Selon projet.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Feu','BS 6853','Feu/fumées (transport)','Selon projet.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Matériaux','ASTM D1056','Classification caoutchoucs alvéolaires','Propriétés mécaniques/dimensionnelles.'),
((SELECT id FROM foam_types WHERE code='NBR'),'Tests','ISO 1798','Traction des mousses','Allongement/rupture.');

-- EPDM
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='EPDM'),'Feu','EN 45545-2','Exigences feu/fumées (ferroviaire)','HL1–HL3 selon application.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Feu','UL94 HF-1 / V-0','Auto-extinguibilité mousses','Selon formulation/épaisseur.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Feu','EN 13501-1','Euroclasses (bâtiment)','Objectif possible : B-s1,d0 selon formulation.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Feu','NF F 16-101','Classification feu/fumées','Transport.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Fumées','ASTM E662','Densité de fumée','Selon exigences.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Tests','ASTM E1354','Calorimétrie cone (HRR)','Selon exigences.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Feu','FMVSS 302','Inflammabilité véhicule','Selon application.'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Matériaux','ASTM D1056','Classification mousses caoutchouc','Catégories type 2A2…'),
((SELECT id FROM foam_types WHERE code='EPDM'),'Tests','ASTM D573','Vieillissement air chaud','Validation tenue thermique.');

-- CR
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='CR'),'Feu','EN 45545-2','Exigences feu/fumées (ferroviaire)','Souvent HL2/HL3 selon application.'),
((SELECT id FROM foam_types WHERE code='CR'),'Feu','UL94 V-0','Auto-extinguibilité (vertical)','Selon grade.'),
((SELECT id FROM foam_types WHERE code='CR'),'Feu','M1','Classement réaction au feu (France)','Possible en épaisseur fine selon produit.'),
((SELECT id FROM foam_types WHERE code='CR'),'Feu','BS 6853','Feu/fumées (transport)','Selon projet.'),
((SELECT id FROM foam_types WHERE code='CR'),'Feu','NF F 16-101','Classification feu/fumées (transport)','Selon projet.'),
((SELECT id FROM foam_types WHERE code='CR'),'Matériaux','ASTM D1056','Classification caoutchoucs alvéolaires','Catégories 2C*…'),
((SELECT id FROM foam_types WHERE code='CR'),'Réglementaire','FDA CFR 177.2600','Contact alimentaire (certains grades)','Selon grade/usage.');

-- SIL
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='SIL'),'Feu','UL94 V-0','Auto-extinguibilité (vertical)','Souvent atteint intrinsèquement selon grade.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Feu','NFPA 90A/90B','Matériaux pour conduits CVAC','Ininflammabilité / non propagation flamme.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Feu','EN 45545-2','Exigences feu/fumées (ferroviaire)','Souvent utilisé pour câbles/joints (HL3).'),
((SELECT id FROM foam_types WHERE code='SIL'),'Feu','EN 13501-1','Euroclasses (bâtiment)','Selon formulation et système.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Tests','ISO 4589-3','Indice oxygène (OIT/LOI)','Comportement au feu.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Réglementaire','FDA 21 CFR 177.2600','Contact alimentaire (selon grade)','Selon grade/usage.'),
((SELECT id FROM foam_types WHERE code='SIL'),'Matériaux','ASTM D2000','Classification élastomères','Selon exigences mécaniques/thermiques.');

-- PU
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='PU'),'Feu','EN 597-1/2','Résistance à la cigarette et petite flamme (literie)','Norme mousse/literie.'),
((SELECT id FROM foam_types WHERE code='PU'),'Feu','EN 45545-2','Exigences feu/fumées (ferroviaire)','HL2 min (HL3 possible selon formulation).'),
((SELECT id FROM foam_types WHERE code='PU'),'Feu','EN 13501-1','Euroclasses (bâtiment)','PIR avec parements : souvent B-s1,d0 visé.'),
((SELECT id FROM foam_types WHERE code='PU'),'Feu','FMVSS 302','Inflammabilité véhicule','Selon application.'),
((SELECT id FROM foam_types WHERE code='PU'),'Feu','NFPA 90A/90B','CVAC : exigences feu','Selon système.'),
((SELECT id FROM foam_types WHERE code='PU'),'Tests','ASTM D3574','Essais mousses flexibles','Densité, IFD, etc.'),
((SELECT id FROM foam_types WHERE code='PU'),'Matériaux','EN 14313','Isolants thermiques (équipements bâtiment)','Panneaux/isolants.');

-- PFN
INSERT INTO foam_standards(foam_type_id, domain, standard_ref, title, notes) VALUES
((SELECT id FROM foam_types WHERE code='PFN'),'EPI','EN 469','Vêtements de protection incendie','Intégration possible en composants EPI selon design.'),
((SELECT id FROM foam_types WHERE code='PFN'),'Feu','UL94 V-0','Auto-extinguibilité (vertical)','Généralement atteint / dépassé selon formulation.'),
((SELECT id FROM foam_types WHERE code='PFN'),'Tests','ASTM D2863','Indice oxygène limite (LOI)','LOI très élevé (ordre de grandeur ~47%).');



-- =========================================================
-- OPTIONS RECYCLAGE
-- (inchangé sauf: benefit = prix estimé de revente €/kg, et calc_details = CO2eq non vide)
-- =========================================================

-- EPDM
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='EPDM'),
 (SELECT id FROM process_methods WHERE code='GRIND_AMB'),
 'Broyage ambiant (granulat)',
 'Transformation des chutes EPDM en granulats réutilisables (charges, sols, sous-couches).',
 0.15, 1.20,
 'Prix estimé revente: 0.50–1.00 €/kg (granulats EPDM).',
 'Tri → découpe → broyage ambiant → tamisage → conditionnement.',
 'Flux propre (sans métal/colles), humidité faible, granulométrie cible.',
 'Aspiration poussières, EPI, prévention risques machines.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Option robuste “baseline”.'
),
((SELECT id FROM foam_types WHERE code='EPDM'),
 (SELECT id FROM process_methods WHERE code='DEVULC_TME'),
 'Dévulcanisation thermo-mécanique',
 'Récupération d’une fraction dévulcanisée réincorporable en compound.',
 0.22, 1.80,
 'Prix estimé revente: 0.40–0.90 €/kg (matière dévulcanisée/compound).',
 'Pré-broyage → dévulcanisation (cisaillement + T) → stabilisation → compoundage.',
 'Flux homogène, traçabilité formulation, équipement adapté.',
 'Température/pression, fumées à capter, sécurité machine.',
 'CO2eq estimé (kgCO2e/kg)',
 'Qualité dépend formulation & taux réticulation.'
),
((SELECT id FROM foam_types WHERE code='EPDM'),
 (SELECT id FROM process_methods WHERE code='GRIND_CRYO'),
 'Broyage cryogénique (poudre fine)',
 'Production de poudre fine par refroidissement LN2 pour meilleure incorporation.',
 0.45, 1.60,
 'Prix estimé revente: 0.50–1.00 €/kg (poudre/fin EPDM).',
 'LN2 → broyage → tamisage fin → conditionnement.',
 'Accès LN2, flux sec, cible granulométrie fine.',
 'Risque cryo (brûlures), ventilation, EPI.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Plus coûteux mais meilleure finesse.'
),
((SELECT id FROM foam_types WHERE code='EPDM'),
 (SELECT id FROM process_methods WHERE code='PYRO'),
 'Pyrolyse',
 'Dernier recours : valorisation via huiles + gaz + char (procédé thermique contrôlé).',
 0.35, 0.80,
 'Prix estimé revente: 0.05–0.20 €/kg (flux mélange/valorisation faible).',
 'Pré-traitement → pyrolyse 400–600°C → séparation → traitement fumées.',
 'Flux accepté par unité, logistique, conformité réglementaire.',
 'Sécurité incendie/explosion, contrôle émissions, gestion huiles.',
 'CO2eq estimé (kgCO2e/kg) ',
 'À réserver si matière impossible.'
);

-- PU
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='PU'),
 (SELECT id FROM process_methods WHERE code='PU_GLYCO'),
 'Glycolyse / alcoholyse',
 'Filière chimique : récupération de polyols réutilisables (haute valeur).',
 0.10, 2.40,
 'Prix estimé revente: 0.80–1.50 €/kg (polyols recyclés).',
 'Tri → réacteur glycolyse → séparation → purification polyols → réemploi.',
 'Flux PU identifié, traçabilité, contrôle additifs.',
 'Procédures HSE chimie, T° élevée, solvants/catalyseurs.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Option recommandée si filière accessible.'
),
((SELECT id FROM foam_types WHERE code='PU'),
 (SELECT id FROM process_methods WHERE code='GRIND_AMB'),
 'Broyage (downcycling)',
 'Découpe/broyage en broyat pour sous-couches (valeur moindre que glycolyse).',
 0.12, 1.10,
 'Prix estimé revente: 0.20–0.50 €/kg (broyat PU).',
 'Découpe → broyage → tamisage → mélange/underlay.',
 'Flux propre, faible humidité.',
 'Poussières, bruit, aspiration.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Solution robuste si chimie indisponible.'
),
((SELECT id FROM foam_types WHERE code='PU'),
 (SELECT id FROM process_methods WHERE code='PYRO'),
 'Pyrolyse',
 'Dernier recours : récupération huiles/gaz, unité thermique contrôlée.',
 0.30, 0.70,
 'Prix estimé revente: 0.05–0.20 €/kg (valorisation faible).',
 'Pré-traitement → pyrolyse → traitement gaz/fumées → valorisation.',
 'Acceptation flux par unité.',
 'Sécurité process + émissions.',
 'CO2eq estimé (kgCO2e/kg) ',
 'À réserver si matière impossible.'
);

-- NBR
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='NBR'),
 (SELECT id FROM process_methods WHERE code='GRIND_AMB'),
 'Broyage ambiant (granulat)',
 'Granulation NBR pour réutilisation en charges/sous-couches.',
 0.16, 1.25,
 'Prix estimé revente: 0.20–0.60 €/kg (broyat/granulat NBR).',
 'Tri → broyage → tamisage → conditionnement.',
 'Flux propre, retrait indésirables.',
 'Poussières, bruit, aspiration.',
 'CO2eq estimé (kgCO2e/kg) ',
 ''
),
((SELECT id FROM foam_types WHERE code='NBR'),
 (SELECT id FROM process_methods WHERE code='DEVULC_TME'),
 'Dévulcanisation thermo-mécanique',
 'Dévulcanisation NBR pour retour en compound (meilleure valeur).',
 0.25, 1.90,
 'Prix estimé revente: 0.40–0.90 €/kg (matière dévulcanisée/compound).',
 'Pré-broyage → dévulcanisation → compoundage.',
 'Flux homogène, contrôle formulation.',
 'Température/pression, fumées, HSE.',
 'CO2eq estimé (kgCO2e/kg) ',
 ''
),
((SELECT id FROM foam_types WHERE code='NBR'),
 (SELECT id FROM process_methods WHERE code='GRIND_CRYO'),
 'Broyage cryogénique (poudre)',
 'Poudre fine NBR pour incorporation plus technique.',
 0.48, 1.65,
 'Prix estimé revente: 0.40–0.90 €/kg (poudre fine NBR).',
 'LN2 → broyage → tamisage fin.',
 'Accès LN2, flux sec.',
 'Risque cryo, ventilation.',
 'CO2eq estimé (kgCO2e/kg) ',
 ''
);

-- SBR
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='SBR'),
 (SELECT id FROM process_methods WHERE code='GRIND_AMB'),
 'Broyage ambiant (granulat)',
 'Valorisation SBR en granulats (solution la plus simple).',
 0.15, 1.15,
 'Prix estimé revente: 0.20–0.60 €/kg (granulat SBR).',
 'Tri → broyage → tamisage.',
 'Flux propre.',
 'Poussières, aspiration.',
 'CO2eq estimé (kgCO2e/kg)',
 ''
),
((SELECT id FROM foam_types WHERE code='SBR'),
 (SELECT id FROM process_methods WHERE code='DEVULC_TME'),
 'Dévulcanisation thermo-mécanique',
 'Retour matière par dévulcanisation et compoundage.',
 0.23, 1.75,
 'Prix estimé revente: 0.40–0.90 €/kg (matière dévulcanisée/compound).',
 'Pré-broyage → dévulcanisation → compoundage.',
 'Flux homogène.',
 'HSE, fumées, T°/P.',
 'CO2eq estimé (kgCO2e/kg)',
 ''
),
((SELECT id FROM foam_types WHERE code='SBR'),
 (SELECT id FROM process_methods WHERE code='PYRO'),
 'Pyrolyse',
 'Dernier recours énergie/produits.',
 0.33, 0.75,
 'Prix estimé revente: 0.05–0.20 €/kg (valorisation faible).',
 'Pyrolyse + traitement fumées.',
 'Accès filière contrôlée.',
 'Sécurité process.',
 'CO2eq estimé (kgCO2e/kg)',
 ''
);

-- CR
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='CR'),
 (SELECT id FROM process_methods WHERE code='GRIND_AMB'),
 'Broyage ambiant (granulat)',
 'Filière matière privilégiée (évite filières thermiques sensibles).',
 0.18, 1.05,
 'Prix estimé revente: 0.30–0.80 €/kg (broyat/granulat CR - néoprène).',
 'Tri → broyage → tamisage.',
 'Flux propre.',
 'Poussières, aspiration.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Préférer matière (présence chlore).'
),
((SELECT id FROM foam_types WHERE code='CR'),
 (SELECT id FROM process_methods WHERE code='PYRO'),
 'Filière thermique contrôlée',
 'Dernier recours : unité thermique avec traitement gaz corrosifs.',
 0.40, 0.40,
 'Prix estimé revente: 0.05–0.20 €/kg (valorisation faible).',
 'Pré-traitement → unité thermique contrôlée → traitement fumées.',
 'Uniquement opérateur spécialisé.',
 'Conformité stricte émissions corrosives.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Seulement si aucune filière matière.'
);

-- SIL
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='SIL'),
 NULL,
 'Broyage silicone (reformulation)',
 'Filière silicone dédiée : broyage puis réincorporation en compound silicone.',
 0.70, 1.30,
 'Prix estimé revente: 0.50–1.50 €/kg (broyat silicone standard).',
 'Tri silicone → broyage → contrôle granulométrie → réincorporation formulation.',
 'Flux silicone identifié, sans contaminants majeurs.',
 'Poussières, aspiration.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Filière plus rare, à sécuriser par partenaire.'
),
((SELECT id FROM foam_types WHERE code='SIL'),
 NULL,
 'Valorisation énergétique contrôlée',
 'Dernier recours : valorisation en unité autorisée.',
 0.15, 0.20,
 'Prix estimé revente: 0.05–0.20 €/kg (valorisation faible).',
 'Pré-traitement → valorisation énergétique contrôlée.',
 'Accès opérateur autorisé.',
 'Contrôle émissions.',
 'CO2eq estimé (kgCO2e/kg) ',
 'À éviter si filière matière possible.'
);

-- PFN
INSERT INTO recycling_options
(foam_type_id, process_method_id, name, description, cost_eur_per_kg, co2_saved_kg_per_kg_foam, benefit,
 method_process, method_prerequisites, method_precautions, calc_details, notes)
VALUES
((SELECT id FROM foam_types WHERE code='PFN'),
 NULL,
 'Broyage composite (charges techniques)',
 'Downcycling en charges techniques (flux composite).',
 0.55, 0.85,
 'Prix estimé revente: 0.05–0.20 €/kg (composite/mélange).',
 'Tri → broyage → contrôle fraction → incorporation applications secondaires.',
 'Flux stable, contrôle contaminants.',
 'Poussières, aspiration.',
 'CO2eq estimé (kgCO2e/kg) ',
 'Composite = filière matière limitée.'
),
((SELECT id FROM foam_types WHERE code='PFN'),
 NULL,
 'Réemploi en couches internes',
 'Réutilisation directe en “système” (si pièces compatibles et tracées).',
 0.40, 1.10,
 'Prix estimé revente: 0.10–0.30 €/kg (réemploi interne)',
 'Contrôle qualité → découpe/ajustage → intégration en couche interne.',
 'Pièces propres, géométrie compatible, exigences feu respectées.',
 'Traçabilité, contrôle qualité.',
 'CO2eq ',
 'Option idéale si réemploi possible.'
);

-- =========================================================
-- ENTREPRISES (inchangé)
-- =========================================================
INSERT INTO companies
(name, company_type, country, city, address, website, email, phone, logo_path, notes)
VALUES
('AER Caoutchouc', 'recycler', 'France', 'Feyzin', 'Chemin du Barlet, 69320 Feyzin, France',
 'https://www.aer-caoutchouc.com', 'direction@aercaoutchouc.com', '+33 4 72 89 26 66', 'company/AER.png',
 'Acteur de recyclage/valorisation des élastomères : tri, préparation, broyage et filières matière selon flux.'),
('Elastever', 'recycler', 'France', 'Saint-Georges-sur-Loire', 'Zone d’activité, 49170 Saint-Georges-sur-Loire, France',
 'https://www.elastever.com', 'contact@elastever.com', NULL, 'company/Elastever.png',
 'Spécialiste valorisation élastomères (granulats/poudres) : dépendance forte à la qualité du tri.'),
('Aliapur', 'sorting', 'France', 'Lyon', '71 cours Albert Thomas, 69003 Lyon, France',
 'https://www.aliapur.fr', 'contact@aliapur.fr', '09 70 24 13 13', 'company/aliapur.jpg',
 'Éco-organisme : orientation des flux et mise en relation avec filières de valorisation adaptées.'),
('VS Rubber Recycling', 'recycler', 'Pays-Bas', 'Venlo', NULL,
 'https://www.vsrubber.nl/fr/', 'info@vsrubberrecycling.com', '+31 77 389 73 11', 'company/rubber.png',
 'Recyclage caoutchouc : broyage / poudres, avec capacités selon les flux et la préparation.'),
('POFI-Engineering', 'chemicals', 'Luxembourg', 'Frisange', '21 rue de Luxembourg, L-5752 Frisange, Luxembourg',
 'https://www.pofi.lu', NULL, '+352 26 67 08 71', 'company/pofi.png',
 'Ingénierie procédés et accompagnement filières (dont chimie PU selon projets/partenaires).'),
('Hosokawa Alpine', 'equipment', 'Allemagne', 'Augsburg', NULL,
 'https://www.hosokawa-alpine.com', NULL, NULL, 'company/hosokawa.png',
 'Fabricant d’équipements de broyage, dont solutions fines/cryogéniques selon besoins industriels.'),
('ECO-Entgratungscenter GmbH', 'recycler', 'Allemagne', 'Rot am See', 'Friedrich-Ebert-Straße 4, 74585 Rot am See, Allemagne',
 'https://www.eco-entgratungscenter.de', 'info@eco-entgratungscenter.de', '+49 7955 9366-0', 'company/eco.jpeg',
 'Prestataire spécialisé en procédés cryogéniques (traitement/broyage/ébavurage).'),
('Paprec', 'recycler', 'France', 'Paris', '7 rue du Docteur Lancereaux, 75008 Paris, France',
 'https://www.paprec.com', NULL, NULL, 'company/paprec.png',
 'Groupe multi-filières : orientation/traitement selon flux, contrats et exutoires disponibles.'),
('Recticel', 'recycler', 'Belgique', 'Bruxelles', 'Avenue du Bourget 42, 1130 Bruxelles, Belgique',
 'https://www.recticel.com', NULL, NULL, 'company/recticel.jpg',
 'Acteur mousses/matériaux : projets et partenariats possibles sur la valorisation des flux PU.');

-- =========================================================
-- LIAISONS entreprises -> options (inchangé)
-- =========================================================

-- AER: broyage + dévulcanisation (élastomères)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='AER Caoutchouc'
  AND ft.code IN ('EPDM','NBR','SBR','CR')
  AND (pm.code IN ('GRIND_AMB','DEVULC_TME') OR ro.name LIKE '%Broyage%');

-- Elastever: broyage (élastomères)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='Elastever'
  AND ft.code IN ('EPDM','NBR','SBR','CR')
  AND (pm.code='GRIND_AMB' OR ro.name LIKE '%Broyage%');

-- VS Rubber: broyage + cryo (élastomères)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='VS Rubber Recycling'
  AND ft.code IN ('EPDM','NBR','SBR')
  AND pm.code IN ('GRIND_AMB','GRIND_CRYO');

-- ECO: cryo
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='ECO-Entgratungscenter GmbH'
  AND pm.code='GRIND_CRYO';

-- Hosokawa: équipement cryo
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='Hosokawa Alpine'
  AND pm.code='GRIND_CRYO';

-- POFI: filière chimique PU
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='POFI-Engineering'
  AND ft.code='PU'
  AND pm.code='PU_GLYCO';

-- Aliapur: orientation / tri (lié à options broyage élastomères)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='Aliapur'
  AND ft.code IN ('EPDM','NBR','SBR')
  AND pm.code='GRIND_AMB';

-- Paprec: généraliste (options standard broyage)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='Paprec'
  AND (pm.code IN ('GRIND_AMB') OR ro.name LIKE '%Broyage%');

-- Recticel: PU (broyage + glycolyse)
INSERT INTO company_recycling_options(company_id, recycling_option_id)
SELECT c.id, ro.id
FROM companies c
JOIN recycling_options ro
JOIN foam_types ft ON ft.id = ro.foam_type_id
LEFT JOIN process_methods pm ON pm.id = ro.process_method_id
WHERE c.name='Recticel'
  AND ft.code='PU'
  AND pm.code IN ('GRIND_AMB','PU_GLYCO');

-- =========================
-- INDEX (perf)
-- =========================
CREATE INDEX idx_foam_code                 ON foam_types(code);
CREATE INDEX idx_comp_foam                 ON foam_composition_items(foam_type_id);
CREATE INDEX idx_prop_foam                 ON foam_physical_properties(foam_type_id);
CREATE INDEX idx_haz_foam_phase            ON foam_hazards(foam_type_id, phase);
CREATE INDEX idx_std_foam                  ON foam_standards(foam_type_id);
CREATE INDEX idx_ro_foam                   ON recycling_options(foam_type_id);
CREATE INDEX idx_ro_method                 ON recycling_options(process_method_id);
CREATE INDEX idx_company_country_city      ON companies(country, city);
CREATE INDEX idx_cro_opt                   ON company_recycling_options(recycling_option_id);
CREATE INDEX idx_cro_company               ON company_recycling_options(company_id);

