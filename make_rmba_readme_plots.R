#Plots for GitHub
# JJD


library(tidyverse)
library(readxl)
library(cowplot)

#Read in the Parker et al. dataset and select the gold standard, and one of the new devices
df <- read_excel("Parker et al 2016 dataset.xlsx") %>%
  mutate(Activity = as.factor(Activity),
         PatientID = as.factor(PatientID),
         Obs = as.factor(Obs)) %>%
  select(PatientID, Activity, RRox, RRacc) %>%
  mutate(measure_diff = RRox - RRacc)

glimpse(df)

set.seed(1989) # A good year
ex_df <- data.frame(gold_standard = seq(60,220, length.out = 200) + rnorm(200))
ex_df$new_device = ex_df$gold_standard + 10*rnorm(200) - 5*rnorm(200)

ex_df_limit <- ex_df %>%
  filter(gold_standard > 115, gold_standard < 160)


plt_cor_1 <- sprintf("R^2 == %.3f", 
                   cor(ex_df_limit %>% pull(gold_standard),
                       ex_df_limit %>% pull(new_device))^2)

plt_cor_2 <- sprintf("R^2 == %.3f", 
                     cor(ex_df %>% pull(gold_standard),
                         ex_df %>% pull(new_device))^2)


corr_1 <- ggplot(data=ex_df_limit, 
                 aes(x=gold_standard, y=new_device)) + 
  geom_point(size=1.5, alpha= 0.5) + 
  geom_abline(linetype="dashed") +
  annotate("text", x=100, y=220, 
           label = plt_cor_1, parse=TRUE,
           size=3) + 
  lims(x=c(40,250), y=c(40,250)) + 
  theme(legend.position = "none",
        text = element_text(size=12),
        axis.text = element_text(color="black")) 

corr_2 <- ggplot(data=ex_df %>% filter(!between(gold_standard,115,160)), 
                 aes(x=gold_standard, y=new_device)) + 
  geom_point(size=1.5, alpha= 0.5) + 
  geom_point(data = ex_df_limit, 
             size=1.5, alpha= 0.5,
             color = "red") + 
  geom_abline(linetype="dashed") +
  annotate("text", x=100, y=220, 
            label = plt_cor_2, parse=TRUE,
            size=3) + 
  lims(x=c(40,250), y=c(40,250)) + 
  theme(legend.position = "none",
        text = element_text(size=12),
        axis.text = element_text(color="black")) 

my_cow <- plot_grid(corr_1, corr_2, nrow=1)

ggsave("corr_comparison.png", plot=my_cow, width=6, height=3, units="in")


naive_plot <- df %>%
  ggplot(aes(x=RRox, y=RRacc)) + 
  geom_abline(linetype="dashed") + 
  geom_point(size=3, alpha = 0.5) + 
  coord_equal() + 
  theme(legend.position = "none",
        text = element_text(size=20)) 

subj_plot <- df %>%
  ggplot(aes(x=RRox, y=RRacc, color = PatientID)) + 
  geom_abline(linetype="dashed") + 
  geom_point(size=3, alpha = 0.5) + 
  stat_smooth(geom='line', alpha=0.5, size=2, se=FALSE, method="lm") + 
  coord_equal() + 
  theme(legend.position = "none",
        text = element_text(size=20))