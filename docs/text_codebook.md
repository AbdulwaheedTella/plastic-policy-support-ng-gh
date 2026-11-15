# Codebook for the open-ended question

**Question (identical in both countries):** "Do you think plastic wastes can be used to generate wealth?" followed by "If yes, please specify".

**Unit of coding:** one answer. **Scheme:** multi-label. An answer can carry several codes.

**Non-substantive answers** ("yes", "no idea", single characters or three characters or fewer) are flagged and excluded from code prevalence.

**Implementation:** case-insensitive regular expressions in Step 6 of `Plastic_NG_GH_analysis.ipynb` (`CODEBOOK`). Every code assignment can be traced to the pattern below. The patterns were written after reading a random sample of 45 answers per country and before computing any country comparison.

| Code | Definition | Pattern (regex, lower case) | Counts as a concrete pathway |
|---|---|---|---|
| Recycling (generic) | Recycling, reprocessing or "renewing" without saying into what | `recycl`, `recyc`, `recyl`, `re-cycl`, `reprocess`, `regenerat`, `renew` | No |
| Reuse and upcycling | Reuse, repurposing, refurbishing, upcycling, repair | `reus`, `re-us`, `repurpos`, `refurbish`, `upcycl`, `repair` | No |
| New consumer products | Names a product or product class made from waste | `product`, `chair`, `bucket`, `bowl`, `table`, `furniture`, `sandal`, `cloth`, `textile`, `toy`, `container`, `cup`, `mat`, `plate`, `item`, `basket`, `bottle` | Yes |
| Energy and fuel | Energy recovery, fuel, pyrolysis, gasification | `energy`, `fuel`, `oil`, `gas`, `biogas`, `syngas`, `pyroly`, `gasifi`, `electric`, `power`, `diesel`, `petrol`, `combust`, `incinerat` | Yes |
| Construction materials | Bricks, blocks, roads, paving, tiles | `brick`, `block`, `road`, `pave`, `tile`, `building`, `construct`, `roof`, `cement`, `concrete`, `asphalt` | Yes |
| Collection and sale | Collecting, selling, buying back, exporting waste | `sell`, `sale`, `sold`, `buy`, `collect`, `gather`, `scaveng`, `trade`, `export`, `buy back`, `exchange`, `pick` | Yes |
| Jobs and livelihoods | Employment, livelihoods, youth work | `job`, `employ`, `livelihood`, `work for`, `unemploy`, `youth` | Yes |
| Enterprise and industry | Businesses, companies, factories, manufacturing, investment | `business`, `entrepreneur`, `compan`, `industr`, `factory`, `venture`, `profit`, `revenue`, `invest`, `start-up`, `sme`, `manufactur` | Yes |
| Crafts and art | Art, crafts, decoration, fashion | `art`, `artistic`, `craft`, `decorat`, `fashion`, `design`, `bead`, `handwork`, `ornament` | Yes |
| Agriculture | Farm uses, nurseries, plant pots, compost | `farm`, `agric`, `nursery`, `plant pot`, `compost`, `seedling` | Yes |
| Environmental and health co-benefits | Cleaner environment, less flooding, health | `environment`, `clean`, `pollution`, `flood`, `hygiene`, `health`, `drain`, `sanitat` | No |
| Governance and education | Government, policy, incentives, deposits, awareness | `government`, `polic`, `law`, `incentive`, `subsid`, `deposit`, `enforce`, `regulat`, `awareness`, `educat`, `sensitis/z`, `campaign`, `train` | No |

**Value-chain specificity** = number of distinct concrete pathways (rightmost column = Yes) named in one answer. **Generic only** = substantive answer with zero concrete pathways.

## Validation

Rule-based coding can miss synonyms and misread negations. To check it, the notebook exports a stratified random sample of 120 substantive answers (60 per country, shuffled) to `docs/text_validation_sample_for_coders.csv`. Two coders should code it independently, without looking at the `auto::` columns or at each other's work. Then run the last cell of the notebook ("Inter-coder agreement"), which reports Cohen's kappa between the two coders and between each coder and the rules. Report these kappas in the paper before submission. Codes with kappa below 0.60 should be revised or merged.
