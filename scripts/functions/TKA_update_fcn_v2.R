source(here::here("scripts", "functions", "apply_coefficent_customisations_fcn.R"))

TKA_update_fcn <- function(am_curr,
                           am_new,
                           pin,
                           TKA_time_trend,
                           OA_cust,
                           cycle.coefficents) {
  
  # NOTE: in future the tkadata_melt can be removed, the purpose of the
  # data is basically being taken over by the TKA_time_trend data
  # kept in at the moment for debugging purposes

  # setup categorical variables
  am_curr$age_group_tka_adj <- cut(am_curr$age, breaks = c(0, 44, 54, 64, 74, 1000), labels = c("< 45", "45-54", "55-64", "65-74", "75+"))
  am_curr$sex_tka_adj <- ifelse(am_curr$sex == "[1] Male", "Males", "Females")

  # find proportion in the synthetic population with OA, will be used to adjust the
  # overall rate of TKA (ie including those without OA) to represent the risk
  # of those with OA. Ie the risk is going to be upscaled from representing
  # the overall population to the risk for the OA population based on this
  # proportion


  # # get current year data
  # tkadata_current <- tkadata_melt %>%
  #   filter(Year == am_curr$year[1]) %>%
  #   mutate(TKR_annual_pop_risk = value/100000)
  #
  #
  # tkadata_current$sex_tka_adj <- grepl("female",tkadata_current$variable)
  # tkadata_current$sex_tka_adj <- ifelse(tkadata_current$sex_tka_adj == TRUE, "Females", "Males")
  #
  # tkadata_current$age_group_tka_adj <- ifelse(grepl("4554",tkadata_current$variable),"45-54",
  #                                             ifelse(grepl("5564",tkadata_current$variable),"55-64",
  #                                                    ifelse(grepl("6574",tkadata_current$variable),"65-74",
  #                                                           ifelse(grepl("75",tkadata_current$variable),"75+",
  #                                                                  "<45"))))
  #
  # am_curr <-left_join(am_curr,
  #                     tkadata_current[,c("sex_tka_adj", "age_group_tka_adj","TKR_annual_pop_risk")],
  #                     by = dplyr::join_by(sex_tka_adj == sex_tka_adj,
  #                                         age_group_tka_adj == age_group_tka_adj))
  #
  #
  # # for those <45 0 annual risk
  # am_curr$TKR_annual_pop_risk[which(is.na(am_curr$TKR_annual_pop_risk))] <- 0


  # NOTE: The following section uses OA_cust to customize TKA coefficients.
  # This seems unusual. Flagging for review.
  cycle.coefficents <- apply_coefficent_customisations(cycle.coefficents, OA_cust, "c9", "c6")

  am_curr$tka_initiation_prob <- cycle.coefficents$c9_cons +
    cycle.coefficents$c9_age * am_curr$age +
    cycle.coefficents$c9_age2 * (am_curr$age^2) +
    cycle.coefficents$c9_drugoa * am_curr$drugoa +
    cycle.coefficents$c9_ccount * am_curr$ccount +
    cycle.coefficents$c9_mhc * am_curr$mhc +
    cycle.coefficents$c9_tkr * am_curr$tka +
    cycle.coefficents$c9_kl2hr * am_curr$kl2 +
    cycle.coefficents$c9_kl3hr * am_curr$kl3 +
    cycle.coefficents$c9_kl4hr * am_curr$kl4

  # risk is a 5 year value so divided by 5 to get annual risk
  am_curr$tka_initiation_prob <- am_curr$tka_initiation_prob / 5

  # divide by 100 to get proportion for comparison with
  am_curr$tka_initiation_prob <- am_curr$tka_initiation_prob / 100

  # zero risk for anyone without OA, who is dead or who has already had two TKA
  am_curr$tka_initiation_prob <- am_curr$oa * am_curr$tka_initiation_prob
  am_curr$tka_initiation_prob <- (1 - am_curr$dead) * am_curr$tka_initiation_prob # only alive have TKA
  am_curr$tka_initiation_prob <- (1 - am_curr$tka2) * am_curr$tka_initiation_prob

  # apply secular scaling, difference values for gender*age groups so 8 groups in total
  am_curr$current_scaling_factor <- 1
  # females
  am_curr$current_scaling_factor[which(am_curr$sex == "[2] Female" & am_curr$age4554 == 1)] <- TKA_time_trend$female4554[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[2] Female" & am_curr$age5564 == 1)] <- TKA_time_trend$female5564[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[2] Female" & am_curr$age6574 == 1)] <- TKA_time_trend$female6574[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[2] Female" & am_curr$age75 == 1)] <- TKA_time_trend$female75[which(TKA_time_trend$Year == am_curr$year[1])]
  # males
  am_curr$current_scaling_factor[which(am_curr$sex == "[1] Male" & am_curr$age4554 == 1)] <- TKA_time_trend$male4554[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[1] Male" & am_curr$age5564 == 1)] <- TKA_time_trend$male5564[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[1] Male" & am_curr$age6574 == 1)] <- TKA_time_trend$male6574[which(TKA_time_trend$Year == am_curr$year[1])]
  am_curr$current_scaling_factor[which(am_curr$sex == "[1] Male" & am_curr$age75 == 1)] <- TKA_time_trend$male75[which(TKA_time_trend$Year == am_curr$year[1])]

  # adjust annual risk to reflect secular trend
  am_curr$tka_initiation_prob <- am_curr$tka_initiation_prob * am_curr$current_scaling_factor

  # determine events based on TKA probability
  tka_initiation_rand <- runif(nrow(am_curr), 0, 1)
  am_curr$tka_initiation_prob <- ifelse(am_curr$tka_initiation_prob > tka_initiation_rand, 1, 0)

  # records is a TKA happened in the cycle
  am_new$tka <- am_curr$tka_initiation_prob
  # if no prior TKA and a record is a TKA, then tka1 = 1
  am_new$tka1 <- am_curr$tka1 + (am_curr$tka_initiation_prob * (1 - am_curr$tka1))
  # if a tka is recorded and there is a prior tka (ie am_curr$tka1 == 1), then record tka2
  am_new$tka2 <- am_curr$tka2 + (am_curr$tka_initiation_prob * am_curr$tka1)

  # this operates as a counter, effectively years since the TKA
  am_new$agetka1 <- am_curr$agetka1 + am_curr$tka1
  am_new$agetka2 <- am_curr$agetka2 + am_curr$tka2

  comparison <- 1 # placeholder

  # bundle am_curr and am_new for export
  export_data <- list(
    am_curr = am_curr,
    am_new = am_new,
    summ_tka_risk = comparison
  )

  return(export_data)
}
