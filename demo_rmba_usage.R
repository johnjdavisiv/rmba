#rmba demo
#JJD
#17 May 2020
library(tidyverse)
library(readxl)
source("rmba.R")

df <- read_excel("Parker et al 2016 dataset.xlsx") %>%
  select(PatientID, Activity, RRox, RRacc)

df %>%
  ggplot(aes(x=RRox, y=RRacc, color = factor(PatientID))) + 
  geom_point() + 
  facet_wrap(~Activity)
  
#RRox is the gold standard measure. Compare RRacc agreement to RRox:
rmba_res <- rmba(data = df, 
                 measure_one_col = "RRox", 
                 measure_two_col = "RRacc", 
                 condition_col = "Activity", 
                 id_col = "PatientID")
rmba_res

#Demo bootstrap
rmba_res_2 <- rmba(data = df, 
                 measure_one_col = "RRox", 
                 measure_two_col = "RRacc", 
                 condition_col = "Activity", 
                 id_col = "PatientID",
                 bootstrap = TRUE,
                 B = 500,
                 seed = 123)
rmba_res_2

