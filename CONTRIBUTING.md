# Guide de contribution — ecommerce_pipeline

Ce document définit les conventions à respecter pour contribuer au pipeline dbt.
Il garantit que le repo reste lisible, maintenable et fiable dans le temps.

---

## Table des matières

1. [Prérequis](#prérequis)
2. [Workflow Git](#workflow-git)
3. [Ajouter un modèle dbt](#ajouter-un-modèle-dbt)
4. [Nommer les fichiers et colonnes](#nommer-les-fichiers-et-colonnes)
5. [Écrire des tests](#écrire-des-tests)
6. [Documenter un modèle](#documenter-un-modèle)
7. [Vérifier avant de committer](#vérifier-avant-de-committer)
8. [Matérialisations](#matérialisations)

---

## Prérequis

```bash
pip install dbt-duckdb==1.8.4
```

Vérifier l'installation :

```bash
dbt --version          # dbt Core 1.8.x
dbt debug --profiles-dir .   # connexion DuckDB OK
```

---

## Workflow Git

### Règle générale

Ne jamais committer directement sur `main`. Toujours passer par une branche.

### Types de branches

| Préfixe | Usage | Exemple |
|---------|-------|---------|
| `feature/` | Nouveau modèle ou fonctionnalité | `feature/add-product-returns-model` |
| `hotfix/` | Correction urgente d'un bug ou test | `hotfix/fix-null-net-amount` |
| `refactor/` | Refactorisation sans nouvelle feature | `refactor/simplify-dim-customers` |
| `docs/` | Documentation uniquement | `docs/update-schema-descriptions` |

### Étapes type

```bash
# 1. Créer une branche depuis main à jour
git checkout main
git pull origin main
git checkout -b feature/add-returns-model

# 2. Développer et tester
dbt run --select mon_modele --profiles-dir .
dbt test --select mon_modele --profiles-dir .

# 3. Committer avec un message sémantique
git add models/marts/dim_returns.sql
git add models/marts/schema.yml
git commit -m "feat: add dim_returns model with refund metrics"

# 4. Merger dans main (après validation)
git checkout main
git merge feature/add-returns-model
git branch -d feature/add-returns-model
```

### Convention de commits

Suivre la convention **Conventional Commits** :

```
<type>(<scope>): <description courte>

[corps optionnel — expliquer le POURQUOI, pas le QUOI]
```

| Type | Usage |
|------|-------|
| `feat` | Nouveau modèle, nouvelle colonne, nouveau test |
| `fix` | Correction d'un bug, d'un calcul incorrect |
| `docs` | Mise à jour README, schema.yml, CONTRIBUTING.md |
| `test` | Ajout ou modification de tests uniquement |
| `refactor` | Réorganisation du code sans impact fonctionnel |
| `chore` | Tâches de maintenance (deps, config) |

**Exemples valides :**
```
feat: add monthly_revenue model with MoM growth metrics
fix: correct net_amount formula when discount_pct is NULL
docs: enrich schema descriptions for dim_customers columns
test: add custom SQL test for negative gross_margin
refactor: extract date spine to a shared macro
```

**Exemples invalides :**
```
update                         ← trop vague
fixed bug                      ← pas de type, pas de scope
WIP                            ← ne jamais committer du WIP sur main
```

---

## Ajouter un modèle dbt

### 1. Choisir la bonne couche

| Couche | Dossier | Quand l'utiliser |
|--------|---------|-----------------|
| Staging | `models/staging/` | Nettoyage d'une source brute. 1 modèle = 1 table source. Pas de logique business. |
| Marts | `models/marts/` | Logique business, jointures, agrégations. Consommé par les dashboards. |

### 2. Créer le fichier SQL

```bash
# Staging
touch models/staging/stg_<source>.sql

# Mart dimensionnel
touch models/marts/dim_<entite>.sql

# Mart table de faits
touch models/marts/fct_<domaine>.sql

# Mart agrégation
touch models/marts/<metrique>_<granularite>.sql
```

### 3. Structure minimale d'un modèle

```sql
-- models/staging/stg_exemple.sql

with source as (
    select * from {{ ref('nom_seed_ou_modele') }}
),

renamed as (
    select
        cast(id as integer)     as exemple_id,
        lower(trim(email))      as email,
        -- ... autres colonnes nettoyées
        current_timestamp       as _loaded_at
    from source
)

select * from renamed
```

**Règles :**
- Toujours commencer par un CTE `source` qui isole la lecture de la source
- Toujours terminer par `select * from <dernier_cte>`
- Toujours ajouter `_loaded_at` dans les modèles staging
- Utiliser `{{ ref('nom_modele') }}` — jamais de nom de table en dur

### 4. Déclarer dans schema.yml

Ajouter le modèle dans le `schema.yml` de la couche correspondante.
Voir la section [Documenter un modèle](#documenter-un-modèle).

### 5. Tester le modèle

```bash
# Compiler (vérifie la syntaxe SQL sans exécuter)
dbt compile --select stg_exemple --profiles-dir .

# Exécuter uniquement ce modèle
dbt run --select stg_exemple --profiles-dir .

# Tester uniquement ce modèle
dbt test --select stg_exemple --profiles-dir .

# Les deux en une commande
dbt build --select stg_exemple --profiles-dir .
```

---

## Nommer les fichiers et colonnes

### Fichiers

| Pattern | Exemple |
|---------|---------|
| `stg_<source>.sql` | `stg_orders.sql` |
| `dim_<entite>.sql` | `dim_customers.sql` |
| `fct_<domaine>.sql` | `fct_orders.sql` |
| `<metrique>_<granularite>.sql` | `monthly_revenue.sql` |

### Colonnes

| Règle | Bon | Mauvais |
|-------|-----|---------|
| snake_case uniquement | `customer_id` | `customerId`, `CustomerID` |
| Clé primaire = `<entite>_id` | `order_id` | `id`, `orderId` |
| Booléens préfixés `is_` ou `has_` | `is_active`, `has_discount` | `active`, `discount_flag` |
| Dates suffixées `_at` (timestamp) ou `_date` (date) | `created_at`, `order_date` | `creation`, `orderDate` |
| Montants suffixés `_amount` | `net_amount` | `net`, `revenue` |
| Pourcentages suffixés `_pct` | `discount_pct` | `discount_percent`, `pct_discount` |
| Colonnes techniques préfixées `_` | `_loaded_at` | `loaded_at`, `pipeline_ts` |

---

## Écrire des tests

### Tests génériques (schema.yml)

Ajouter sous chaque colonne dans le `schema.yml` :

```yaml
- name: ma_colonne
  description: "Description métier complète"
  tests:
    - not_null                    # obligatoire pour toute PK et colonne critique
    - unique                      # obligatoire pour toute PK
    - accepted_values:
        values: ['val1', 'val2']  # pour les énumérations
    - relationships:
        to: ref('autre_modele')   # pour les FK
        field: cle_etrangere
```

**Règle minimum** : toute clé primaire doit avoir `not_null` + `unique`.
Toute clé étrangère doit avoir `not_null` + `relationships`.

### Tests custom SQL (dossier `tests/`)

Pour les règles métier qui ne peuvent pas s'exprimer en tests génériques :

```sql
-- tests/assert_<regle_metier>.sql
-- Convention : le test PASSE si la requête retourne 0 ligne.

select
    colonne_problematique
from {{ ref('mon_modele') }}
where <condition_qui_ne_devrait_jamais_etre_vraie>
```

**Exemples de bons tests custom :**
- Vérifier qu'un montant calculé est cohérent avec ses composantes
- Détecter des doublons sur une combinaison de colonnes
- Vérifier qu'un ratio reste dans une plage acceptable

**Nommage :** `assert_<ce_qui_doit_etre_vrai>.sql`

---

## Documenter un modèle

Toute contribution **doit** inclure la mise à jour du `schema.yml`.
Un modèle non documenté sera refusé en review.

### Structure minimale obligatoire

```yaml
- name: mon_modele
  description: >
    Une phrase qui explique QUOI fait ce modèle (grain, source, transformations clés).
    Une phrase qui explique POURQUOI il existe (quel besoin business il couvre).
    Une phrase sur les choix techniques importants (matérialisation, filtres).

  columns:
    - name: id_colonne
      description: >
        Ce que contient cette colonne et comment elle est calculée.
        Les valeurs possibles et leur signification métier.
        Les cas limites (NULL, 0, valeurs négatives).
      tests:
        - not_null
```

### Ce qu'une bonne description doit contenir

- **Quoi** : ce que contient la colonne (pas juste le nom répété)
- **Comment** : la formule de calcul si applicable
- **Pourquoi** : l'usage business attendu
- **Limites** : les cas edge (NULL, valeurs extrêmes, évolution dans le temps)

---

## Vérifier avant de committer

Checklist à exécuter **avant chaque commit** :

```bash
# 1. Pipeline complet sur les modèles modifiés
dbt build --select <modele_modifie>+ --profiles-dir .

# 2. Pipeline complet sur tout le projet (avant merge dans main)
dbt build --profiles-dir .

# 3. Vérifier que les descriptions schema.yml sont à jour
#    (contrôle manuel — relire le fichier)

# 4. Vérifier le message de commit
git diff --staged
git commit -m "type(scope): description"
```

Aucun commit ne doit laisser le projet dans un état où `dbt build` échoue.

---

## Matérialisations

| Couche | Matérialisation | Raison |
|--------|----------------|--------|
| Staging | `view` | Pas de stockage — simple transformation. Recalculé à la volée. |
| Marts dimensions | `table` | Lue fréquemment par les dashboards. Jointures coûteuses pré-calculées. |
| Marts faits | `table` | Volume important. Agrégations pré-calculées pour la performance. |
| Marts agrégations | `table` | Résultats finaux — doivent être stables et rapides à lire. |

Pour changer la matérialisation d'un modèle spécifique :

```sql
{{ config(materialized='table') }}  -- en tête du fichier .sql
```

Ou globalement dans `dbt_project.yml` pour toute une couche.
