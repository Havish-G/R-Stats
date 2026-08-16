-- =====================================================================
-- Statistical Analysis Studio
-- Database schema (SQLite for local demo; PostgreSQL notes inline)
-- =====================================================================
-- SQLite has no native SERIAL/BOOLEAN, INTEGER PRIMARY KEY autoincrements.
-- For PostgreSQL: SERIAL PRIMARY KEY instead of INTEGER PRIMARY KEY, and
-- TIMESTAMPTZ DEFAULT now() instead of TEXT timestamp columns.

-- ---------------------------------------------------------------------
-- datasets: one row per dataset that's been loaded (built-in or upload)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS datasets (
  dataset_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  source       TEXT NOT NULL CHECK (source IN ('builtin','upload')),
  name         TEXT NOT NULL,             -- e.g. 'Iris (flower measurements)' or original filename
  n_rows       INTEGER,
  n_cols       INTEGER,
  numeric_cols TEXT,                      -- comma-separated column names, for quick reference
  categorical_cols TEXT,
  loaded_at    TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- analyses: every saved analysis run (EDA, hypothesis test, ANOVA,
-- regression, or CLT simulation), so results are reproducible/reviewable
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analyses (
  analysis_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  dataset_id      INTEGER REFERENCES datasets(dataset_id),
  analysis_type   TEXT NOT NULL CHECK (analysis_type IN ('EDA','HYPOTHESIS','ANOVA','REGRESSION','CLT')),
  parameters      TEXT,             -- JSON snapshot of the inputs used (variables, alpha, test type, etc.)
  result_summary  TEXT,             -- human-readable summary (what's shown in the app)
  p_value         REAL,             -- NULL for EDA/CLT
  created_at      TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- users: minimal user registry for demo audit attribution
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  username    TEXT UNIQUE NOT NULL,
  role        TEXT DEFAULT 'analyst' CHECK (role IN ('analyst','admin')),
  created_at  TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- audit_log: every user action - dataset loads, analyses run, reports
-- generated
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  log_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER REFERENCES users(user_id),
  action      TEXT NOT NULL,   -- 'LOGIN' | 'LOAD_DATASET' | 'RUN_EDA' | 'RUN_HYPOTHESIS' |
                                -- 'RUN_ANOVA' | 'RUN_REGRESSION' | 'RUN_CLT' | 'GENERATE_REPORT'
  entity      TEXT,            -- e.g. 'datasets', 'analyses'
  entity_id   INTEGER,
  details     TEXT,
  created_at  TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_analyses_dataset ON analyses(dataset_id);
CREATE INDEX IF NOT EXISTS idx_audit_user       ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created    ON audit_log(created_at);

-- ---------------------------------------------------------------------
-- Sample seed data
-- ---------------------------------------------------------------------
INSERT INTO users (username, role) VALUES ('demo_analyst', 'analyst');
INSERT INTO users (username, role) VALUES ('demo_admin', 'admin');

INSERT INTO datasets (source, name, n_rows, n_cols, numeric_cols, categorical_cols)
VALUES ('builtin', 'Iris (flower measurements)', 150, 5,
        'Sepal.Length,Sepal.Width,Petal.Length,Petal.Width', 'Species');
