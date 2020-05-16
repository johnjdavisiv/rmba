# rmba

### Repeated-measure Bland-Altman analysis with mixed models

**To-do**:   
 * Implement bootstrap confidence intervals  

Let's say you want to validate a new heart rate monitor. You might get some subects together, outfit them with the new heart rate monitor and a "gold standard" research-grade device (like an ECG). Then, you could have them run on a treadmill at different speeds, measuring their heart rate using both the gold standard research-grade device and the new device.  

Once you've collected your data, how do you determine whether the new device is accurate? One extremely common way is to make a simple scatterplot and compute an R<sup>2</sup> value. Unfortunately, this approach is flawed, for two reasons.

**First**, scatter plots can be very visually misleading. Simply collecting a wider or a narrower range of data can make the correllation plot look artificially "good" or "bad." Observe:

![](corr_comparison.png)

The data in the left panel is just a subset of the data on the right panel. Clearly, the agreement between the devices is a constant amount—but the R<sup>2</sup> values are extremely misleading!

**Second**, computing a correllation coefficient on this dataset breaks a very important statistical assumption: our data are not independent. Since we've taken *repeated measures* on the same subjects in different conditions, we have introduced dependencies into our data.

## Mixed models for measuring agreement

The usual solution to the "R<sup>2</sup> is misleading" problem is to make a [Bland-Altman plot](https://www.thelancet.com/retrieve/pii/S0140673686908378), which sounds extremely fancy but is, in truth, far simpler to do and to interpret even than an R<sup>2</sup> value.  

However, even the classic Bland-Altman plot assumes independent observations—i.e. you can't use it when you have repeated measurements. There is a modified version that takes a repeated-measures-ANOVA-style approach, but even this tweak can't handle unbalanced data, missing data, and doesn't take into account the fact that the agreement between two devices might change in different conditions.

A very elegant solution to this problem was described in a [2016 paper published by Parker et al. in PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0168321). It uses linear mixed models to account for within-subject correlations, and on top of that, even accounts for variation across different conditions. In our example of validating a heart rate monitor, it's quite possible that agreement will be worse at different speeds.

Parker et al's linear mixed model approach to Bland-Altman analysis (henceforth referred to as **rmba**) is easy to implement in R's `nlme` package. This repository houses `rmba()`, a convenient function to perform rmba on repeated-measures data.

## Using the rmba function: worked example

`rmba` works as follows: with `rmba.R` in your current R directory, use `source("rmba.R")` to add the function to your workspace. The example below uses data from Parker et al. to reproduce the results for comparing respiration rate for one new device (`RRacc`) to the gold-standard device(`RRox`). The actual results can be found in Table 1 of the paper.

```

library(tidyverse)
library(readxl)
source("rmba.R")

df <- read_excel("Parker et al 2016 dataset.xlsx")
  select(PatientID, Activity, RRox, RRacc)

df %>%
  ggplot(aes(x=RRox, y=RRacc, color = factor(PatientID))) +
  geom_point() +
  facet_wrap(~Activity)

```

![](rmba_demo_figure.png)

Notice what a mess this is: we have lots of unbalanced data (many subjects couldn't complete all of the conditions—these were patients with COPD; many could not walk on the treadmill). Astute useRs will notice that we didn't even bother to specify `PatientID` and `Activity` as factors, yet `rmba()` will handle all of this just fine, reproducing the numbers in Table 1 of Parker et al. exactly. It's still good practice to import your data correctly (factors as factors, and all of that) but isn't *strictly* necessary.  

### Input

```
#RRox is the gold standard measure. Compare RRacc agreement to RRox:
rmba_res <- rmba(data = df, measure_one_col = "RRox",
                   measure_two_col = "RRacc",
                   condition_col = "Activity",
                   id_col = "PatientID")
rmba_res

```

### Output

```

[1] "Mean bias of RRacc compared to RRox: -2.183 with 95% limits of agreement [-8.631, 4.265]"

```

Programmatic useRs fear not; `rmba()` returns a `list` object with all the goodies stored inside:

```
rmba_res <- rmba(df, "RRox", "RRacc", "Activity", "PatientID")
rmba_res

$bias
[1] -2.182703

$bias_se
[1] 0.2645315

$sd
[1] 3.289795

$lower_agreement_limit
[1] -8.630582

$upper_agreement_limit
[1] 4.265176

```

Hopefully you enjoy this function, and hopefully it will lead to broader use of Bland-Altman analysis for validation studies in biomechanics, physiology, and wearable technology research. Drop me a line or open an issue if you find any issues with it. 

-J
