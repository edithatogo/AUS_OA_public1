library(testthat)

test_that("Simulation produces consistent outputs", {
  # This test runs a short, deterministic simulation and compares its output
  # to a "golden" snapshot. This prevents unintended changes to model results.

  # Ensure that functions are loaded. devtools should be a development dependency.
  if (!requireNamespace("devtools", quietly = TRUE)) {
    skip("devtools not available, skipping regression test.")
  }
  devtools::load_all()

  # Set a seed for reproducibility of stochastic processes
  set.seed(123)

  # --- 1. SETUP ---
  # Use here::here() to construct paths relative to the project root
  # This makes the test robust to changes in the working directory.
  config_path <- here::here("config")
  initial_am_path <- here::here("am_curr_before_oa.rds")

  # Check that the required files exist before running the test
  if (!dir.exists(config_path)) {
    stop("Configuration directory not found at: ", config_path)
  }
  if (!file.exists(initial_am_path)) {
    stop("Initial attribute matrix file not found at: ", initial_am_path)
  }

  # Load model parameters from the config directory
  params <- load_config(config_path)

  # Load the initial attribute matrix (the population state at the start)
  am_initial <- readRDS(initial_am_path)

  # For a fast test, we use a small population subset and few cycles.
  n_test_pop <- 50
  n_test_cycles <- 2
  am_test_input <- am_initial[1:n_test_pop, ]

  # Robustly ensure all columns that should be numeric are converted.
  # This prevents "non-numeric argument" errors in downstream functions.
  cols_to_convert <- c(
    "age", "bmi", "oa", "kl2", "kl3", "kl4", "dead", "tka", "tka1", "tka2",
    "agetka1", "agetka2", "rev1", "revi", "pain", "function_score", "qaly",
    "year", "d_bmi", "drugoa", "age044", "age4554", "age5564", "age6574",
    "age75", "male", "female", "bmi024", "bmi2529", "bmi3034", "bmi3539",
    "bmi40", "ccount", "mhc", "comp", "ir", "public", "sf6d", "d_sf6d"
  )
  
  for (col in cols_to_convert) {
    if (col %in% names(am_test_input)) {
      # Handle potential factors by converting to character first
      am_test_input[[col]] <- as.numeric(as.character(am_test_input[[col]]))
    }
  }
  # year12 is a factor with levels "0" and "1"
  if ("year12" %in% names(am_test_input)) {
    am_test_input$year12 <- as.numeric(as.character(am_test_input$year12))
  }

  # Override simulation parameters for the test run
  params$simulation_setup$n_total_cycles <- n_test_cycles

  # --- 2. EXECUTION ---
  # The simulation_cycle_fcn requires several specific inputs.
  # We create mock versions of these based on the loaded params.
  am_new <- am_test_input
  age_edges <- params$simulation_setup$age_edges
  bmi_edges <- params$simulation_setup$bmi_edges
  
  # Create a dummy life table for the test
  lt <- data.frame(
    male_sep1_bmi0 = rep(0.001, 101),
    female_sep1_bmi0 = rep(0.0008, 101)
  )
  rownames(lt) <- 0:100

  # Create dummy customisation tables
  eq_cust <- list(
    BMI = data.frame(covariate_set = "c1", proportion_reduction = 1),
    TKR = data.frame(),
    OA = data.frame(covariate_set = "c6", proportion_reduction = 1)
  )
  
  # Create a dummy TKA time trend table
  tka_time_trend <- data.frame(Year = 2023, female4554 = 1, male4554 = 1)


  # Run the simulation loop
  am_final_state <- am_test_input
  for (i in 1:n_test_cycles) {
    # The function returns a list; we need the 'am_new' element
    results_list <- simulation_cycle_fcn(
      am_curr = am_final_state,
      cycle.coefficents = params$coefficients,
      am_new = am_new,
      age_edges = age_edges,
      bmi_edges = bmi_edges,
      am = am_final_state, # Mocking 'am' with the current state
      mort_update_counter = 1, # Dummy counter
      lt = lt,
      eq_cust = eq_cust,
      tka_time_trend = tka_time_trend
    )
    am_final_state <- results_list$am_new
  }

  # --- 3. VERIFICATION ---
  # Calculate summary statistics from the final state of the population
  summary_stats <- OA_summary_fcn(am_final_state)

  # The path for the temporary output file that we will snapshot.
  # This file is created during the test run and then compared to the snapshot.
  output_file_for_snapshot <- tempfile(fileext = ".rds")
  saveRDS(summary_stats, output_file_for_snapshot)

  # Compare the output with the stored "golden" snapshot.
  # The first time this test is run, it will create the snapshot file.
  # Subsequent runs will compare against this file.
  # If the output changes, the test will fail. To update the snapshot,
  # run testthat::snapshot_review() or delete the snapshot file and re-run.
  expect_snapshot_file(output_file_for_snapshot, name = "regression-summary.rds")
  
  # The tempfile will be cleaned up automatically, but good practice to be explicit
  unlink(output_file_for_snapshot, force = TRUE)
})