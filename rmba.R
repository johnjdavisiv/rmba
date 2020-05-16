#Repeated measrues bland altman
#Following Parker et al 2016 (doi:10.1371/journal.pone.0168321)
#John J Davis IV
#16 May 2020

#USAGE EXAMAPLE: 
#rmba_res <- rmba(my_df, "RRox", "RRacc", "Activity", "PatientID")

#Input: 
# data - dataframe
# measure_one_col - string name of column with first measure (or gold standard)
# measure_two_col - string name of column with second measure
# condition_col - name of column with (factor) conditions
# id_col - string name of column with IDs (patients, etc.)
# loa_level - limit of agreement percent (default: 0.95 for 95% LoA)
# verbose - print results? 

#Output:
# rmba_results: a list with the mean bias, se of mean bias, total SD, and limits of agreement

rmba <- function(data, 
                 measure_one_col, 
                 measure_two_col, 
                 condition_col = "1", 
                 id_col,
                 loa_level = 0.95,
                 verbose = TRUE) {

  require(nlme)
  
  se_mult <- qnorm(1-(1-loa_level)/2)
  
  #Unlist for tibble messiness
  data$measure_diff_rmba <- unlist(data[,measure_two_col] - data[,measure_one_col])
  
  
  #Doing two minus one, so if measure one is gold standard, a positive result means
  #that measure two is an OVERESTIMATE (+)
  
  
  lme_form <- as.formula(paste("measure_diff_rmba ~ ", condition_col, sep=""))
  lme_id_form <- as.formula(paste("~1|", id_col, sep=""))
  
  model_one <- lme(lme_form, random = lme_id_form,
                   correlation = corCompSymm(form = lme_id_form),
                   data = data,
                   na.action = na.omit)
  
  #Within-subject SD is the residual SD
  within_sd <- as.numeric(VarCorr(model_one)[2,2])
  #Between subject SD is the random intercept SD
  between_sd <- as.numeric(VarCorr(model_one)[1,2])
  
  #Total SD is the +/- for the mean bias (adjusted for condition)
  total_sd <- sqrt(between_sd^2 + within_sd^2)
  
  
  #Model two: intercept only
  #"extracts appropriately weighted mean and standard error
  model_two <- lme(measure_diff_rmba ~ 1, random = lme_id_form,
                   correlation = corCompSymm(form = lme_id_form),
                   data = data,
                   na.action = na.omit)
  
  #Intercept of the intercept only is the mean bias
  #  The standard error of that metric is the SE of the mean bias
  mean_bias <- summary(model_two)$tTable[1,1]
  mean_bias_se <- summary(model_two)$tTable[1,2]
  
  #Calculate 95% limits of agreement
  lo_limit <- mean_bias - se_mult*total_sd
  hi_limit <- mean_bias + se_mult*total_sd
  
  rmba_results <- list(bias = mean_bias,
                       bias_se = mean_bias_se,
                       sd = total_sd,
                       lower_agreement_limit = lo_limit,
                       upper_agreement_limit = hi_limit)

  #Print results if desired
  if (verbose) {
    print(sprintf("Mean bias of %s compared to %s: %.3f with %.0f%% limits of agreement [%.3f, %.3f]",
                  measure_two_col,
                  measure_one_col,
                  rmba_results$bias,
                  loa_level*100,
                  rmba_results$lower_agreement_limit,
                  rmba_results$upper_agreement_limit))
  }
  
  return(rmba_results)
}
  