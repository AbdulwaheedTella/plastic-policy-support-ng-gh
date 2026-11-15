# Raw data (not public)

The two raw Google Forms exports (`nigeria_raw.xlsx`, `ghana_raw.xlsx`) are not shared because they
contain exact submission times and free-text occupations.

You do not need them to reproduce the paper. When this folder has no raw files, the notebook starts
from `data/processed/survey_merged_deidentified.csv`, which is the table the raw files produce.

Authors with access to the raw exports can place them here under the names above; the notebook then
rebuilds the merged file and Table T0 (data flow) from them. Git ignores everything in this folder
except this README, so the raw files cannot be committed by accident.
