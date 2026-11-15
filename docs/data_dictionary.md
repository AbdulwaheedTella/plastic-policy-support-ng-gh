# Data dictionary: `data/processed/survey_merged_deidentified.csv` (also `.xlsx`)

One row per respondent (Nigeria n = 481, Ghana n = 259). Created in Step 1 of `Plastic_NG_GH_analysis.ipynb` from the two Google Forms exports, which are not shared because they hold exact timestamps and free-text occupations.

## Identifiers and design

| Variable | Description |
|---|---|
| `resp_id` | Anonymous respondent ID (NI0001… Nigeria, GH… Ghana) |
| `country` | Nigeria or Ghana |
| `collection_month` | Month of submission (YYYY-MM). Exact timestamps removed |

## Socio-demographics

| Variable | Coding |
|---|---|
| `gender` | Male / Female (missing if not answered) |
| `age` | 18-27, 28-37, 38-47, 48+ |
| `marital` | Single, Married, Widowed or divorced |
| `education` | Tertiary, Below tertiary |
| `discipline` | Science; Engineering and Technology; Agriculture; Medical and Health Sciences (incl. veterinary); Arts and Humanities (incl. law); Education |
| `occ_group` | Student; Academic or researcher; Public sector; Business or self-employed; Retired or unemployed; Other professional (rule-based grouping of free text; see `occ_group()` in Step 1 of the notebook) |
| `residence` | State (Nigeria) or region (Ghana) of residence. State/region of origin removed |
| `community` | City, Town, Village or suburb |
| `residence_years` | 1-2, 2-5, 6-10, >10 |
| `income_band` | Original household monthly income band (NGN or GHS) |
| `income_top` | 1 = highest band (NGN > 65,000 or GHS > 2,000), 0 = lower bands |
| `hh_size` | 1-3, 4-6, 7-9, 10 and above |

## Awareness and engagement (Yes = 1, Maybe = 0.5, No = 0)

`env_gathering` (attended an environment-related gathering), `heard_ce` (heard of circular economy), `ce_reduce` (circular economy can reduce plastic impacts; asked only of those who had heard of it), `waste_wealth` (plastic waste can generate wealth), `heard_bioplastic`, `bioplastic_benefit` (bioplastics can bring economic and environmental benefits). `engagement` = sum of `env_gathering`, `heard_ce` and `heard_bioplastic`, rescaled to 0-3 when one of the three is missing (requires at least two).

## Likert items (1 = strongly disagree … 5 = strongly agree)

Harm perception (stem: "The following ecological/environmental problems might be caused by improper disposal of plastic waste"): `flood`, `erosion`, `vector` (breeding ground for pests and disease vectors), `infiltration`, `buildings`, `toxic`, `microbes`, `nutrients`, `bags_billions`, `waterways_tons`, `aquatic`, `food`, `terrestrial`, `harmful_env`.

Other beliefs: `trash_no_harm` (throwing plastic waste in the trash will not harm the environment), `not_recycled`, `not_reused`, `charges` (additional charges on plastic products can reduce plastic pollution).

Responsibility and instruments: `gov_resp` (management is the government's responsibility), `everybody` (everybody can play a role), `polluter_pays`, `legal`, `cheaper_plastic` (making cheaper plastic products), `biodeg_alt` (provision of biodegradable alternatives), `cheap_bioplastic` (provision of cheaper and affordable bioplastic products).

## Multi-select items (1 = selected, 0 = not selected, missing if the question was skipped)

Plastics used regularly: `use_bag`, `use_bottle`, `use_pvc`, `use_styrofoam`. Preferred control measures: `pref_recycle`, `pref_reuse`, `pref_replace`, `pref_burning`, `pref_burying`. Sectors seen as main users of plastic: `sec_food_agric`, `sec_health`, `sec_sme`, `sec_recreation`, `sec_building`, `sec_handwork`, `sec_education`.

## Open-ended

`wealth_text`: answer to "If yes, please specify" (how plastic waste can generate wealth). E-mail addresses, URLs and phone numbers are redacted.

## Response-quality flags (1 = flagged; all flagged cases are kept in the main analysis)

| Flag | Rule |
|---|---|
| `n_likert_answered` | Number of the 25 Likert items answered |
| `flag_no_likert` | No Likert item answered |
| `flag_straightline` | Same answer on all answered Likert items (at least 20 answered) |
| `flag_harm_all_sd` | "Strongly disagree" on all 14 harm items |
| `flag_inconsistent` | Opposite extremes on "harmful to the environment" and both animal-harm items |
| `flag_any_quality` | Any of the above |
