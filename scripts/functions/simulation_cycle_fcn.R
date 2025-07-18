# goal: top level simulation function for the OA model
# note: version 1, largely replicating the original matlab code by C. Schilling


simulation_cycle_fcn <- function(am_curr, cycle.coefficents, am_new,
                                 age_edges, bmi_edges,
                                 am,
                                 mort_update_counter, lt,
                                 eq_cust,
                                 TKA_time_trend,
                                 pin) {
  # extract relevant equation modification data
  BMI_cust <- eq_cust[["BMI"]]
  TKR_cust <- eq_cust[["TKR"]]
  OA_cust <- eq_cust[["OA"]]

  ############################## update BMI in cycle
  am_curr <- BMI_mod_fcn(am_curr, cycle.coefficents, BMI_cust)


  # am_new.bmi = am_curr.bmi + d_bmi;
  # update BMI data using delta
  am_new$bmi <- am_curr$bmi + am_curr$d_bmi

  # add impact of BMI delta to SF6D
  am_curr$d_sf6d <- am_curr$d_sf6d + (am_curr$d_bmi * cycle.coefficents$c14_bmi)

  ############################## update OA incidence

  # % OA incidence - based on HILDA analysis

  OA_update_data <- OA_update(am_curr, am_new, cycle.coefficents, OA_cust, pin)

  # extract data.tables from output list
  am_curr <- OA_update_data[["am_curr"]]
  am_new <- OA_update_data[["am_new"]]

  # note: change in sf6d calculated in the OA_update function


  ############################## update personal charactistics (agecat, bmicat)

  # % Update groupings for categorising output


  am_new$age_cat <- cut(am_new$age, breaks = age_edges, include.lowest = TRUE)

  am_new$age044 <- ifelse(am_new$age_cat == levels(am_new$age_cat)[1], 1, 0)
  am_new$age4554 <- ifelse(am_new$age_cat == levels(am_new$age_cat)[2], 1, 0)
  am_new$age5564 <- ifelse(am_new$age_cat == levels(am_new$age_cat)[3], 1, 0)
  am_new$age6574 <- ifelse(am_new$age_cat == levels(am_new$age_cat)[4], 1, 0)
  am_new$age75 <- ifelse(am_new$age_cat == levels(am_new$age_cat)[5], 1, 0)



  am_new$bmi_cat <- cut(am_new$bmi, breaks = bmi_edges, include.lowest = TRUE)

  am_new$bmi024 <- ifelse(am_new$bmi_cat == levels(am_new$bmi_cat)[1], 1, 0)
  am_new$bmi2529 <- ifelse(am_new$bmi_cat == levels(am_new$bmi_cat)[2], 1, 0)
  am_new$bmi3034 <- ifelse(am_new$bmi_cat == levels(am_new$bmi_cat)[3], 1, 0)
  am_new$bmi3539 <- ifelse(am_new$bmi_cat == levels(am_new$bmi_cat)[4], 1, 0)
  am_new$bmi40 <- ifelse(am_new$bmi_cat == levels(am_new$bmi_cat)[5], 1, 0)


  ############################## update comorbidies (cci, mental health)

  # % Comorbidities


  
  am_curr$cci <- cycle.coefficents$c10_1 * am_curr$age4554 +
    cycle.coefficents$c10_2 * am_curr$age4554 +
    cycle.coefficents$c10_3 * am_curr$age5564 +
    cycle.coefficents$c10_4 * am_curr$age6574 +
    cycle.coefficents$c10_5 * am_curr$age75

  am_curr$cci <- (1 - am_curr$dead) * am_curr$cci
  cci_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$cci <- ifelse(am_curr$cci > cci_rand, 1, 0)
  am_new$ccount <- am_curr$cci + am_curr$ccount

  am_curr$d_sf6d <- am_curr$d_sf6d + (am_curr$cci * cycle.coefficents$c14_ccount)



  # % Mental health condition


  am_curr$mhci <- cycle.coefficents$c12_male * am_curr$male +
    cycle.coefficents$c12_female * am_curr$female


  mhci_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$mhci <- ifelse(am_curr$mhci > mhci_rand, 1, 0)
  am_new$mhc <- am_curr$mhci + am_curr$mhc
  am_curr$d_sf6d <- am_curr$d_sf6d + (am_curr$mhci * cycle.coefficents$c14_mhc)



  ############################## update TKA status (TKA, complications, revision, inpatient rehab)
  # % TKA

  TKA_update_data <- TKA_update_fcn(am_curr, am_new, pin, TKA_time_trend, OA_cust, cycle.coefficents)

  # extract data.tables from output list
  am_curr <- TKA_update_data[["am_curr"]]
  am_new <- TKA_update_data[["am_new"]]

  summ_tka_risk <- TKA_update_data[["summ_tka_risk"]]

  # % TKA complication


  # % TKA complication
  am_curr$compi <- cycle.coefficents$c16_cons +
    cycle.coefficents$c16_male * am_curr$male +
    cycle.coefficents$c16_ccount * am_curr$ccount +
    cycle.coefficents$c16_bmi3 * am_curr$bmi3539 +
    cycle.coefficents$c16_bmi4 * am_curr$bmi40 +
    cycle.coefficents$c16_mhc * am_curr$mhc +
    cycle.coefficents$c16_age3 * am_curr$age5564 +
    cycle.coefficents$c16_age4 * am_curr$age6574 +
    cycle.coefficents$c16_age5 * am_curr$age75 +
    cycle.coefficents$c16_sf6d * am_curr$sf6d +
    cycle.coefficents$c16_kl3 * am_curr$kl3 +
    cycle.coefficents$c16_kl4 * am_curr$kl4

  am_curr$compi <- exp(am_curr$compi)
  am_curr$compi <- am_curr$compi / (1 + am_curr$compi)
  am_curr$compi <- am_curr$compi * am_new$tka # % only have complication if have TKA
  am_curr$compi <- (1 - am_curr$dead) * am_curr$compi # ; % only alive have complication

  compi_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$compi <- ifelse(am_curr$compi > compi_rand, 1, 0)


  am_new$comp <- am_curr$compi


  # % TKA inpatient rehabiliation

  am_curr$ir <- cycle.coefficents$c17_cons +
    cycle.coefficents$c17_male * am_curr$male +
    cycle.coefficents$c17_ccount * am_curr$ccount +
    cycle.coefficents$c17_bmi3 * am_curr$bmi3539 +
    cycle.coefficents$c17_bmi4 * am_curr$bmi40 +
    cycle.coefficents$c17_mhc * am_curr$mhc +
    cycle.coefficents$c17_age3 * am_curr$age5564 +
    cycle.coefficents$c17_age4 * am_curr$age6574 +
    cycle.coefficents$c17_age5 * am_curr$age75 +
    cycle.coefficents$c17_sf6d * am_curr$sf6d +
    cycle.coefficents$c17_kl3 * am_curr$kl3 +
    cycle.coefficents$c17_kl4 * am_curr$kl4 +
    cycle.coefficents$c17_comp * am_curr$comp

  am_curr$ir <- exp(am_curr$ir)
  am_curr$ir <- am_curr$ir / (1 + am_curr$ir)
  am_curr$ir <- am_curr$ir * am_new$tka # ; % only have rehab if have TKA
  am_curr$ir <- (1 - am_curr$dead) * am_curr$ir # ; % only alive have rehab

  ir_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$ir <- ifelse(am_curr$ir > ir_rand, 1, 0)
  am_new$ir <- am_curr$ir

  # TKA revision
  X <- revisions_fcn(cycle.coefficents, am_curr)
  am_new$revision1 <- X$revision1
  am_new$revision2 <- X$revision2
  am_new$revi <- X$revi
  am_new$cum_haz1 <- X$cum_haz1
  am_new$cum_haz2 <- X$cum_haz2
  am_new$rev_haz1 <- X$rev_haz1
  am_new$rev_haz2 <- X$rev_haz2
  rm(X)




  am_curr$d_sf6d <- am_curr$d_sf6d + am_curr$revi * cycle.coefficents$c14_rev


  # % HRQOL progression or prediction (tbc)

  am_new$sf6d <- am_curr$sf6d + am_curr$d_sf6d





  ############################## Determine mortality in the cycle

  # % Mortality




  for (mort_update_counter in 1:nrow(am)) {
    am_curr$qx[mort_update_counter] <- lt$male_sep1_bmi0[am_curr$age[mort_update_counter]] * am_curr$male[mort_update_counter] +
      lt$female_sep1_bmi0[am_curr$age[mort_update_counter]] * (1 - am_curr$male[mort_update_counter])
  }

  # % Adjust mortality rate for BMI/SEP and implement


  am_curr$hr_mort <- 1 +
    am_curr$bmi2529 * cycle.coefficents$hr_BMI_mort +
    am_curr$bmi3034 * cycle.coefficents$hr_BMI_mort^2 +
    am_curr$bmi3539 * cycle.coefficents$hr_BMI_mort^3 +
    am_curr$bmi40 * cycle.coefficents$hr_BMI_mort^4

  am_curr$hr_mort <- am_curr$hr_mort * (1 - am_curr$year12) * cycle.coefficents$hr_SEP_mort
  am_curr$qx <- am_curr$qx * am_curr$hr_mort
  am_curr$qx <- (1 - am_curr$dead) * am_curr$qx # only die once

  dead_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$dead_rand <- ifelse(am_curr$qx > dead_rand, 1, 0)
  am_new$dead <- am_curr$dead + am_curr$dead_rand


  # zero SF6D for dead people
  am_new$sf6d <- (1 - am_new$dead) * am_new$sf6d

  ############################## Update age and QALYs at end of cycle

  # % Age the cohort, so long as they are alive


  am_new$age <- am_curr$age + (1 * (1 - am_new$dead))
  am_new$age <- ifelse(am_curr$age >= 100, 100, am_new$age)

  # % Update QALYs

  # NOTE: this is a running total of QALYs, not QALYs in the cycle
  am_new$qaly <- am_curr$qaly + am_curr$sf6d



  # bundle am_curr and am_new for export
  export_data <- list(
    am_curr = am_curr,
    am_new = am_new,
    summ_tka_risk = summ_tka_risk
  )

  return(export_data)
}
