# Public support for plastic policy in Nigeria and Ghana

<!-- After the first Zenodo release, replace XXXXXXX below with the concept record number and delete this line. -->
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)

Data, code and every output for the article:

> **What explains public support for plastic policy? A comparative study of Nigeria and Ghana**
>
> Abdulwakil Olawale Saba, Mutala Mohammed, Musa Adamu Ibrahim, Abdulwaheed Tella, Dokuboba Amachree

One Jupyter notebook takes the de-identified survey data (740 respondents: Nigeria 481, Ghana 259) to every table and figure in the paper. All random steps use a fixed seed (20231101). The published outputs in `outputs/` were produced on Ubuntu 24.04 with Python 3.13 and R 4.3.3.

## Quick start

You need **Python 3.12 or later** (3.13 was used for the paper) and **R 4.3 or later** (4.3.3 was used).

```bash
git clone https://github.com/AbdulwaheedTella/plastic-policy-support-ng-gh.git
cd plastic-policy-support-ng-gh

python -m venv .venv
# Windows: .venv\Scripts\activate      macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt

python compare_tables.py --snapshot   # keep a copy of the published tables for checking
jupyter notebook Plastic_NG_GH_analysis.ipynb   # then Kernel > Restart & Run All
python compare_tables.py              # check that your run matches the published tables
```

To run without opening Jupyter:

```bash
jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=-1 Plastic_NG_GH_analysis.ipynb
```

* **Run time.** A full run takes 1.5 to 2 hours on a laptop, mostly in the SEM sensitivity checks and the machine-learning bootstraps. Set `QUICK = True` in the first code cell for a 10-minute test run with fewer bootstrap draws (the bootstrap-based numbers then differ slightly from the paper).
Nothing needs to be set by hand:

* **Folder.** The notebook and every R script find the project folder by themselves (the folder holding `data/processed/survey_merged_deidentified.csv`). Everything is read from and saved into this one folder.
* **R.** The notebook finds `Rscript` on your PATH or in the usual install folders. Only if R is somewhere unusual, set `RSCRIPT` in the first code cell to its full path, for example `r"C:\Program Files\R\R-4.3.3\bin\Rscript.exe"`.
* **R packages.** At the start, the notebook installs any missing R package (lavaan, semTools, psych, GPArotation, poLCA, nnet) as a ready-made binary into `r_library/` inside the project folder. No administrator rights and no Rtools are needed; the first run needs internet. You can also run `install_R_packages.R` once yourself in R or RStudio.
* **Running an R step on its own.** Open any script in `r_scripts/` in RStudio and click *Source*, or run `Rscript r_scripts/03_latent_classes.R`. Run `03_latent_classes.R` before `05_lca_invariance.R`.

## Getting exactly the published numbers

`compare_tables.py` compares every CSV in `outputs/tables/` with the snapshot. It reports each table as *same*, *same\** (identical apart from row order), *rounding* (one unit in the last rounded decimal, from a value sitting on a rounding boundary) or *DIFFERS*.

* **Exact match.** Use Linux with Python 3.13, the versions in `requirements.txt`, R 4.3.3 and lavaan 0.7-3, semTools 0.5-10, psych 2.6.9, GPArotation 2026.8-2, poLCA 1.6.0.2 and nnet 7.3-19. The GitHub Actions workflow in `.github/workflows/reproduce.yml` does exactly this on a clean machine: open the **Actions** tab, choose *Reproduce the analysis* and click *Run workflow* (about 25 minutes). Its first run (15 November 2026) reproduced all 48 tables: 44 byte-identical, 2 identical apart from the order of tied or alphabetically sorted rows (T6e, T11c), and 2 with one standardised coefficient of 0.088 instead of 0.087 (T6a, T7a; Ghana, norm → make plastic cheaper).
* **Other operating systems.** The descriptive statistics, SEM, invariance tests, latent class analysis, logistic regression, random forest and text coding come out the same. XGBoost does not give bit-identical results across operating systems, so on Windows or macOS the XGBoost rows of Tables T8a-T8b and the SHAP tables T9a-T9d (Fig. 5, Fig. 6, Fig. S3, Fig. S4) typically differ in the second or third decimal place, and the Monte Carlo confidence limits for indirect effects (T6e) in the third. `compare_tables.py` will report these tables as different.
* **Newer R packages.** The notebook installs the newest CRAN release of each R package. If a release newer than those listed above changes results, install the listed versions with `remotes::install_version()`.

## What the notebook does

`Plastic_NG_GH_analysis.ipynb` runs the whole study in order, with an explanation above each step:

1. loads the merged, de-identified survey file (or, if the raw exports are present, rebuilds it from them: renames and recodes the questions and merges the two countries);
2. describes the samples and compares every item (Tables T0-T3, Fig. 1, Fig. 2, Fig. S1);
3. latent class analysis in R, response-style checks and a test that the classes mean the same in both countries (Tables T10a-T10m);
4. measurement model, invariance tests and multi-group SEM in R (Tables T4-T7);
5. machine learning: nested cross-validation, transfer between countries with non-inferiority and equivalence tests, bootstrap SHAP (Tables T8-T9);
6. coding of the open-ended answers (Table T11);
7. remaining figures (Fig. 3-7, Fig. S2-S4);
8. all tables in one Excel workbook (`outputs/All_tables.xlsx`);
9. optional: inter-coder agreement (Cohen's kappa) once two people have coded `docs/text_validation_sample_for_coders.csv`.

The R code is shown inside the notebook. Each R step is written to `r_scripts/` and run with `Rscript`, so you need R installed but not a separate R session.

## Folders

| Folder | Content |
|---|---|
| `data/processed/` | `survey_merged_deidentified.csv` and `.xlsx`: the merged, recoded, de-identified file (740 respondents, 70 variables). Variables are described in `docs/data_dictionary.md` |
| `data/geo/` | Natural Earth admin-0 and admin-1 boundaries for the map (public domain) |
| `data/raw/` | Empty in the public copy (see below) |
| `outputs/tables/` | Every table as CSV (T0 to T11); `outputs/All_tables.xlsx` has them all with an index sheet |
| `outputs/figures/` | Every figure as 600-dpi PNG, 600-dpi LZW TIFF and vector PDF |
| `outputs/models/`, `outputs/logs/` | Full lavaan model summaries, R session information and R logs |
| `docs/` | Data dictionary, open-ended codebook, and a 120-answer sample for two human coders |
| `r_scripts/` | The R steps. `00_setup.R` finds the folder and loads packages; the notebook rewrites these files each time it runs |
| `r_library/` | R packages installed by the notebook (created on first run, not in the repository, safe to delete) |

## Raw data

The two raw Google Forms exports are **not** shared because they contain exact submission times and free-text occupations. Nothing needs to change to reproduce the paper: when `data/raw/` is empty, Step 1 loads `data/processed/survey_merged_deidentified.csv`, which is exactly the table the raw files produce, and the rest of the notebook runs as with the raw files. Only Table T0 (data flow) needs the raw files; its saved copy is in `outputs/tables/`.

## Notes

* lavaan warns that the parameter covariance matrix "does not appear to be positive definite". The near-zero eigenvalues correspond to the equality constraints between countries (and the binary covariates), so the warning is expected. A model with fixed covariates gives the same coefficients (Table T7a).
* Running the notebook overwrites `outputs/` and `docs/text_validation_sample_for_coders.csv`. If you have filled in the coder columns of that file, keep a copy before re-running.

## How to cite

If you use these data or code, please cite the article and this archive. Citation details are in [`CITATION.cff`](CITATION.cff) (GitHub shows them under "Cite this repository") and on the Zenodo record linked by the DOI badge above.

## Licence

* Code (the notebook, `r_scripts/`, `install_R_packages.R`, `compare_tables.py`): MIT, see [`LICENSE`](LICENSE).
* Data, outputs and documentation (`data/processed/`, `outputs/`, `docs/`): CC BY 4.0, see [`LICENSE-DATA`](LICENSE-DATA).
* Boundary data in `data/geo/`: Natural Earth, public domain.
