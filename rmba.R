#Repeated measrues bland altman
#Following Parker et al 2016 (doi:10.1371/journal.pone.0168321)
#John J Davis IV
#17 May 2020

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
# bootstrap - use parametric bootstrap to estimate CIs? (can be slow!)
# B - bootstrap resamples 
# seed - rng seed for bootstrapping

#Output:
# rmba_results: a list with the mean bias, se of mean bias, total SD, and limits of agreement

#-------------------------------------------------------
#         Primary function   
#-------------------------------------------------------

rmba <- function(data, 
                 measure_one_col, 
                 measure_two_col, 
                 condition_col = "1", 
                 id_col,
                 loa_level = 0.95,
                 verbose = TRUE,
                 bootstrap = FALSE,
                 bootstrap_ci_level = 0.95,
                 B = 1000,
                 seed = NA) {

  require(nlme)
  
  se_mult <- qnorm(1-(1-loa_level)/2)
  
  #Unlist for tibble messiness
  data$measure_diff_rmba <- unlist(data[,measure_two_col] - data[,measure_one_col])
  
  #Doing measure two minus one, so if measure one is gold standard, a positive result means
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
  
  #If bootstrap estimates desired, run boot
  if (bootstrap){
    #Do bootstrap
    
    if (!is.na(seed)) set.seed(seed)
    
    boot_results <- matrix(nrow=B, ncol=5)
    colnames(boot_results) <- c("bias","bias_se","sd",
                            "lower_agreement_limit",
                            "upper_agreement_limit")
    print("CAUTION! Parametric bootstrap implementation differs from Parker et al. This feature should be considered experimental.")
    print("Running bootstrap; this could take a while...")
    
    prog_bar <- txtProgressBar(min = 0, max = B, initial = 0, style=1) 
    
    #For each resample...
    for (b in 1:B){
      #Get a bootstrap sample
      boot_results[b,] <- unlist(rmba_resample(data, model_one, 
                                               condition_col,id_col, loa_level))
      setTxtProgressBar(prog_bar,b)
    }
    
    #A silly option that nobody will probably ever use
    boot_probs <- c((1-bootstrap_ci_level)/2, 
                    1-(1-bootstrap_ci_level)/2)
    
    #Get percentiles at end
    boot_ci <- apply(boot_results, 2, quantile, probs= boot_probs)
    
  } else boot_ci <- NULL #if no bootstrap requested
  
  #Write results to list
  rmba_results <- list(bias = mean_bias,
                       bias_se = mean_bias_se,
                       sd = total_sd,
                       lower_agreement_limit = lo_limit,
                       upper_agreement_limit = hi_limit,
                       boot_ci = boot_ci)
  
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
  

#-------------------------------------------------------
#   Parametric boostrapping for confidence intervals
#-------------------------------------------------------

#This function does the resampling. See below for function that fits the resampled data
rmba_resample <- function(data, 
                          orig_model_one, 
                          condition_col,
                          id_col,
                          loa_level) {
  #Input values needed:
  # orig_model_one - original model fit in call to rmba()
  # loa_level - original loa_level
  
  #Perform parametric bootstrap 
  #Specifically the "parametric random effects bootstrap coupled with residual bootstrap"
  #in section 2.3.2 in Thai et al 2013. Pharm Stat 12(3);129-140
  #The idea is we just take new Gaussian draws using the SD of random intercept and
  #the SD of the residuals to get a new Yij for each bootstrap replicate.
  
  #Grab SDs
  within_sd <- as.numeric(VarCorr(orig_model_one)[2,2])
  between_sd <- as.numeric(VarCorr(orig_model_one)[1,2])
  
  #How many subjects/clusters? 
  n_id_levels <- length(levels(as.factor(unlist(data[,id_col]))))
  
  #This gets a number of non-NA values for each patient
  n_i <- by(data$measure_diff_rmba, INDICES = unlist(data[,id_col]),
            FUN = function (x) sum(!is.na(x)))
  #Same as:
  #data %>%
  #  group_by(PatientID) %>%
  #  drop_na(measure_diff_rmba) %>%
  #  count()
  
  #Fixed-effects only (missing values will be omitted silently)
  X_B <- predict(orig_model_one, level=0)
  
  #Resample new random effects for each subject (n_i times) using estimated SD
  new_re <- rep(rnorm(n_id_levels, 0 , between_sd), 
                times = as.numeric(n_i))
  
  #Resample new residuals 
  #(all subjects share the same residual SD so we don't need to condition on subject here)
  new_resid <- rnorm(length(X_B),0,
                     within_sd)
  
  # Get new difference vector 
  #This is Yij = XB + Zu + e because Z is just a column vector of ones.
  boot_diff <- X_B + new_re + new_resid
  
  # --- Prepare data frame for boot_rmba()
  
  #NA ind - need to trim data because we used na.omit earlier
  na_ind <- is.na(data$measure_diff_rmba)
  
  #Get stuff ready for boot dataframe
  boot_id <- unlist(data[!na_ind, id_col])
  
  #If condition column was specificed
  if (condition_col != "1"){
    boot_condition <- unlist(data[!na_ind, condition_col])
  } else {
    boot_condition <- rep("1", length(boot_id))
  }
  
  #Make boot dataframe
  boot_data <- data.frame(boot_id = boot_id, 
                          boot_condition = boot_condition,
                          boot_diff = boot_diff)
  
  #Call boot_rmba and get estimates
  return(rmba_boot(boot_data, loa_level))
  
}

#-------------------------------------------------------
#         Fitting new model to resampled data     
#-------------------------------------------------------

#Helper function that refits a new model to resampled Yij values
rmba_boot <- function(boot_data,
                      loa_level = 0.95) {
  
  require(nlme)
  
  se_mult <- qnorm(1-(1-loa_level)/2)

  #If using a fixed effect for condition
  if (length(unique(boot_data$boot_condition)) == 1 &
    unique(boot_data$boot_condition)[1] == "1") {
    
    lme_form <- as.formula("boot_diff ~ 1")
    
  } else{
    lme_form <- as.formula("boot_diff ~ boot_condition")
  }
  
  lme_id_form <- as.formula("~1|boot_id")
  
  boot_model_one <- lme(lme_form, random = lme_id_form,
                   correlation = corCompSymm(form = lme_id_form),
                   data = boot_data,
                   na.action = na.omit)
  
  #Within-subject SD is the residual SD
  within_sd <- as.numeric(VarCorr(boot_model_one)[2,2])
  #Between subject SD is the random intercept SD
  between_sd <- as.numeric(VarCorr(boot_model_one)[1,2])
  
  #Total SD is the +/- for the mean bias (adjusted for condition)
  total_sd <- sqrt(between_sd^2 + within_sd^2)
  
  #Model two: intercept only
  #"extracts appropriately weighted mean and standard error
  boot_model_two <- lme(boot_diff ~ 1, random = lme_id_form,
                   correlation = corCompSymm(form = lme_id_form),
                   data = boot_data,
                   na.action = na.omit)
  
  #Intercept of the intercept only is the mean bias
  #  The standard error of that metric is the SE of the mean bias
  mean_bias <- summary(boot_model_two)$tTable[1,1]
  mean_bias_se <- summary(boot_model_two)$tTable[1,2]
  
  #Calculate 95% limits of agreement
  lo_limit <- mean_bias - se_mult*total_sd
  hi_limit <- mean_bias + se_mult*total_sd
  
  boot_rmba_results <- list(bias = mean_bias,
                       bias_se = mean_bias_se,
                       sd = total_sd,
                       lower_agreement_limit = lo_limit,
                       upper_agreement_limit = hi_limit)
  
  #use unlist() later to turn this into a named numeric
  return(boot_rmba_results)
}