list(
demo  = 'svyby(~TOTEXP.yy., FUN=svymean, by = ~.by., design = FYCdsgn)',

event = '
# Loop over event types
  events <- c("TOT", "DVT", "RX",  "OBV", "OBD", "OBO",
              "OPT", "OPY", "OPZ", "ERT", "IPT", "HHT", "OMA")

  results <- list()
  for(ev in events) {
    key <- paste0(ev, "EXP")
    formula <- as.formula(sprintf("~%s.yy.", key))
    results[[key]] <- svyby(formula, FUN = svymean, by = ~.by., design = FYCdsgn)
  }
  print(results)',

sop   = '
# Loop over sources of payment
  sops <- c("EXP", "SLF", "PTR", "MCR", "MCD", "OTZ")
  results <- list()

  for(sp in sops) {
    key <- paste0("TOT", sp)
    formula <- as.formula(sprintf("~%s.yy.", key))
    results[[key]] <- svyby(formula, FUN = svymean, by = ~.by., design = FYCdsgn)
  }

  print(results)',

event_sop = '
# Loop over events, sops
  events <- c("TOT", "DVT", "RX",  "OBV", "OBD", "OBO",
              "OPT", "OPY", "OPZ", "ERT", "IPT", "HHT", "OMA")

  sops <- c("EXP", "SLF", "PTR", "MCR", "MCD", "OTZ")

  results <- list()
  for(ev in events) {
    for(sp in sops) {
      key <- paste0(ev, sp)
      formula <- as.formula(sprintf("~%s.yy.", key))
      results[[key]] <- svyby(formula, FUN = svymean, by = ~.by., design = FYCdsgn)
    }
  }
  print(results)'

)
