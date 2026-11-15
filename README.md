# Public support for plastic policy in Nigeria and Ghana

<!-- After the first Zenodo release, replace XXXXXXX below with the concept record number and delete this line. -->
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)

Data, code and every output for the article:

> **What explains public support for plastic policy? A comparative study of Nigeria and Ghana**
>
> Abdulwakil Olawale Saba, Mutala Mohammed, Musa Adamu Ibrahim, Abdulwaheed Tella, Dokuboba Amachree

One Jupyter notebook takes the de-identified survey data (740 respondents: Nigeria 481, Ghana 259) to every table and figure in the paper. All random steps use a fixed seed, so a full run reproduces the published numbers.

## Quick start

You need **Python 3.12 or later** (3.13 was used for the paper) and **R 4.3 or later** (4.3.3 was used).

```bash
git clone https://github.com/AbdulwaheedTella/plastic-policy-support-ng-gh.git
cd plastic-policy-support-ng-gh

python -m venv .venv
# Windows: .venv\Scripts\activate      macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt

Rscript install_R_packages.R          # once; installs the exact R package versions used

python compare_tables.py --snapshot   # keep a copy of the published tables for checking
jupyter notebook Plastic_NG_GH_analysis.ipynb   # then Kernel > Restart & Run All
python compare_tables.py              # check that your run matches the published tables
```

To run without opening Jupyter:

```bash
jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=-1 Plastic_NG_GH_analysis.ipynb
```

* **Run time.** A full run takes 1.5 to 2 hours on a laptop, mostly in the SEM sensitivity checks and the machine-learning bootstraps. Set `QUICK = True` in the first code cell for a 10-minute test run with fewer bootstrap draws (the bootstrap-based numbers then differ slightly from the paper).
* **Rscript not found** (common on Windows): set `RSCRIPT` in the first code cell to its full path, for example `r"C:\Program Files\R\R-4.3.3\bin\Rscript.exe"`.
* **Windows and R packages.** `install_R_packages.R` builds the pinned versions from source. Packages with compiled code (`poLCA`, `nnet`) need [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version.
* **Checking your run.** `compare_tables.py` compares every CSV in `outputs/tables/` with the snapshot, allowing only floating-point noise (relative tolerance 1e-6). The paper's results were produced on Ubuntu 24.04 with Python 3.13 and R 4.3.3; other operating systems may differ in the last decimal places.

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
| `r_scripts/` | The R scripts, re-written by the notebook each time it runs |

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
