# Push this project to GitHub

The repo is initialized locally with a clean commit history. Nothing has been
pushed — run one of the options below. Replace `<username>` with your GitHub
username.

## Option A — GitHub CLI (fastest)

```bash
cd ~/workspace/goals/land-a-job-within-a-week/files/retail-sales-analysis

# create the public repo and push in one command
gh repo create retail-sales-analysis --public --source=. --remote=origin --push
```

(`gh` = GitHub CLI. Install: https://cli.github.com — then `gh auth login` once.)

## Option B — manual (no CLI)

```bash
cd ~/workspace/goals/land-a-job-within-a-week/files/retail-sales-analysis

# 1. On github.com, create a NEW EMPTY repository named
#    "retail-sales-analysis" (do NOT tick "Add a README" — this repo
#    already has one).

# 2. Link it and push:
git remote add origin https://github.com/<username>/retail-sales-analysis.git
git branch -M main
git push -u origin main
```

## After pushing

- GitHub renders `README.md` automatically on the repo home page.
- Add a screenshot of the Streamlit dashboard (`assets/dashboard.png`) and
  reference it in the README — dashboards sell the project at a glance.
- Pin the repo to your GitHub profile so recruiters see it first.

## Notes

- `db/retail.db` is gitignored by design — anyone cloning the repo rebuilds it
  with `python scripts/load_to_sqlite.py` (documented in the README).
- The vendored `data/online_retail.csv` is ~45 MB, under GitHub's 100 MB
  single-file limit.
