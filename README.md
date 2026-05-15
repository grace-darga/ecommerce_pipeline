# DataOps Pipeline — E-commerce dbt + DuckDB

Pipeline de transformation de données e-commerce industrialisé avec **dbt** et **DuckDB**.
Couvre l'intégralité de la chaîne de transformation : de la donnée brute CSV aux KPIs analytiques mensuels.

---

## Stack

| Outil | Version | Rôle |
|-------|---------|------|
| dbt-core | 1.8.9 | Orchestration des transformations SQL |
| dbt-duckdb | 1.8.4 | Adaptateur base de données |
| DuckDB | 1.5.x | Base de données analytique locale |
| Git | — | Versioning du code SQL |
| SQL | — | Langage de transformation |

---

## Architecture — Medallion en 3 couches

```
┌─────────────────────────────────────────────────────────────────────┐
│  SOURCES BRUTES (Seeds CSV)                                         │
│  customers.csv · orders.csv · products.csv                          │
│  12 clients · 30 commandes · 12 produits · Jan–Mai 2024             │
└────────────────────────┬────────────────────────────────────────────┘
                         │  dbt seed
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STAGING — Views (nettoyage & typage)                               │
│                                                                     │
│  stg_customers          stg_orders           stg_products           │
│  ─ email lowercase      ─ net_amount calc.   ─ gross_margin calc.   │
│  ─ segment UPPERCASE    ─ dates enrichies    ─ margin_pct calc.     │
│  ─ cast types           ─ cast types         ─ cast types           │
└────────────────────────┬────────────────────────────────────────────┘
                         │  dbt run
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  MARTS — Tables (logique business)                                  │
│                                                                     │
│  dim_customers          dim_products         fct_orders             │
│  ─ métriques RFM        ─ perf. commerciale  ─ table de faits       │
│  ─ value_tier           ─ popularity_tier    ─ tout dénormalisé     │
│  ─ panier moyen         ─ profit estimé      ─ is_cancelled flag    │
│                                                                     │
│  monthly_revenue                                                    │
│  ─ CA net mensuel · profit · panier moyen · taux annulation         │
└─────────────────────────────────────────────────────────────────────┘
                         │  dbt test
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│  QUALITÉ — 49 tests PASS · 0 erreur · 0 skip                        │
│  not_null · unique · accepted_values · relationships · custom SQL    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Structure du repo

```
ecommerce_pipeline/
│
├── data/                          # Seeds — données sources CSV
│   ├── customers.csv              # 12 clients (France, Belgique, Suisse)
│   ├── orders.csv                 # 30 commandes (Jan–Mai 2024)
│   └── products.csv               # 12 produits, 4 catégories
│
├── models/
│   ├── staging/                   # Couche nettoyage — matérialisée en VIEW
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_products.sql
│   │   └── schema.yml             # Tests + descriptions détaillées
│   │
│   └── marts/                     # Couche business — matérialisée en TABLE
│       ├── dim_customers.sql      # Dimension clients + RFM
│       ├── dim_products.sql       # Dimension produits + performance
│       ├── fct_orders.sql         # Table de faits centrale
│       ├── monthly_revenue.sql    # KPIs mensuels agrégés
│       └── schema.yml             # Tests + descriptions détaillées
│
├── tests/                         # Tests SQL custom (règles métier)
│   ├── assert_positive_net_amount.sql
│   ├── assert_margin_consistency.sql
│   ├── assert_no_orphan_orders.sql
│   └── assert_monthly_revenue_positive.sql
│
├── macros/                        # Fonctions SQL réutilisables
│
├── dbt_project.yml                # Configuration dbt (matérialisations, chemins)
├── profiles.yml                   # Connexion DuckDB (dev + prod)
├── CONTRIBUTING.md                # Guide de contribution et conventions
└── README.md                      # Ce fichier
```

---

## Installation et lancement

### Prérequis

- Python 3.9+
- pip

### 1. Installer dbt

```bash
pip install dbt-duckdb==1.8.4
```

> **Windows** : si vous obtenez `'javascript' KeyError`, installer dbt-core 1.8.9 :
> ```bash
> pip install dbt-core==1.8.9
> ```

### 2. Vérifier la configuration

```bash
cd ecommerce_pipeline
dbt debug --profiles-dir .
```

Résultat attendu : `All checks passed!`

### 3. Lancer le pipeline complet

```bash
# Tout en une commande (seed + run + test)
dbt build --profiles-dir .
```

Résultat attendu :
```
Found 7 models, 49 data tests, 3 seeds
Concurrency: 4 threads

PASS=59  WARN=0  ERROR=0  SKIP=0  TOTAL=59  (2.25s)
```

### 4. Commandes individuelles

```bash
dbt seed  --profiles-dir .   # Charger les CSV dans DuckDB
dbt run   --profiles-dir .   # Construire les 7 modèles
dbt test  --profiles-dir .   # Exécuter les 49 tests
```

### 5. Cibler un modèle spécifique

```bash
# Un seul modèle
dbt run --select dim_customers --profiles-dir .

# Un modèle et tous ses descendants
dbt build --select dim_customers+ --profiles-dir .

# Toute la couche staging
dbt build --select staging --profiles-dir .
```

### 6. Documentation interactive

```bash
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
# Ouvre http://localhost:8080 avec le lineage graph complet
```

---

## Modèles

### Staging (Views)

| Modèle | Source | Transformations clés |
|--------|--------|---------------------|
| `stg_customers` | customers.csv | email lowercase, segment UPPERCASE, cast types |
| `stg_products` | products.csv | gross_margin = unit_price − cost_price, margin_pct |
| `stg_orders` | orders.csv | net_amount = qté × prix × (1 − remise%), dates enrichies |

### Marts (Tables)

| Modèle | Grain | Description |
|--------|-------|-------------|
| `dim_customers` | 1 ligne / client | Attributs + métriques comportementales + value_tier RFM |
| `dim_products` | 1 ligne / produit | Attributs + performance commerciale + popularity_tier |
| `fct_orders` | 1 ligne / commande | Table de faits centrale, tout dénormalisé |
| `monthly_revenue` | 1 ligne / mois | KPIs mensuels : CA, profit, panier moyen, taux annulation |

---

## Tests de qualité (49 au total)

### Tests génériques

| Type | Nombre | Ce qu'il vérifie |
|------|--------|-----------------|
| `not_null` | 18 | Aucun champ critique ne peut être NULL |
| `unique` | 8 | Clés primaires et emails strictement uniques |
| `accepted_values` | 6 | Valeurs énumérées (segment, statut, tiers) |
| `relationships` | 4 | Intégrité FK → PK entre les tables |

### Tests custom SQL

| Fichier | Règle vérifiée |
|---------|---------------|
| `assert_positive_net_amount` | Aucune commande non-annulée n'a un montant net négatif |
| `assert_margin_consistency` | La marge brute = unit_price − cost_price (tolérance 0.01€) |
| `assert_no_orphan_orders` | Aucune commande sans client valide associé |
| `assert_monthly_revenue_positive` | Le CA net mensuel est toujours positif ou nul |

---

## Résultats — Données de démo

| Indicateur | Valeur |
|------------|--------|
| Période couverte | Janvier – Mai 2024 |
| CA net total | 11 747 € |
| Profit estimé | 4 783 € |
| Nombre de commandes | 30 (dont 1 annulée) |
| Taux d'annulation | 3.3% |
| Clients actifs | 12 |
| Meilleur produit | Laptop Pro 15 (6 175 €) |
| Meilleure catégorie | Informatique |
| Panier moyen | ~391 € |

### CA net mensuel

```
Jan 2024  ████████████████████  3 455 €
Fév 2024  ████████              1 185 €
Mar 2024  ████████████████      2 397 €
Avr 2024  ███████████████       2 272 €
Mai 2024  ████████████████      2 438 €
```

---

## Workflow Git

```
main
 │
 ├── feature/add-kpi-models       # nouvelles métriques analytiques
 └── hotfix/fix-margin-test       # correctifs urgents de qualité
```

### Historique des commits

```
feat: init DataOps pipeline dbt+DuckDB
  - Seeds: customers, orders, products (CSV)
  - Staging: 3 views (nettoyage + calculs financiers)
  - Marts: 4 tables (dims + fact + KPIs mensuels)
  - Tests: 49 tests (generic + 4 custom SQL)

docs: add comprehensive README with architecture and usage

docs: enrich schema.yml with detailed business descriptions

docs: add CONTRIBUTING.md with conventions and workflow
```

---

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour :
- Le workflow Git (branches, commits sémantiques)
- Les conventions de nommage (fichiers, colonnes)
- La procédure pour ajouter un modèle dbt
- Les règles de documentation (schema.yml)
- La checklist avant chaque commit
