library(tidyverse)
library(readxl)
source("rmba.R")

df <- read_excel("Parker et al 2016 dataset.xlsx")
  select(PatientID, Activity, RRox, RRacc)

df %>%
  ggplot(aes(x=RRox, y=RRacc, color = factor(PatientID))) + 
  geom_point() + 
  facet_wrap(~Activity)
  
#RRox is the gold standard measure. Compare RRacc agreement to RRox:
rmba_res <- rmba(df, "RRox", "RRacc", "Activity", "PatientID")
rmba_res


