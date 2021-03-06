# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h50.ssp');
  year <- 2000

  if(year <= 2001) FYC <- FYC %>% mutate(VARPSU = VARPSU00, VARSTR=VARSTR00)
  if(year <= 1998) FYC <- FYC %>% rename(PERWT00F = WTDPER00)
  if(year == 1996) FYC <- FYC %>% mutate(AGE42X = AGE2X, AGE31X = AGE1X)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE00X, AGE42X, AGE31X))

  FYC$ind = 1  

# Add aggregate sources of payment
  if(year <= 1999)
    FYC <- FYC %>% mutate(TOTTRI00 = TOTCHM00)

  FYC <- FYC %>% mutate(
    TOTOTH00 = TOTOFD00 + TOTSTL00 + TOTOPR00 + TOTOPU00 + TOTOSR00,
    TOTOTZ00 = TOTOTH00 + TOTWCP00 + TOTVA00,
    TOTPTR00 = TOTPRV00 + TOTTRI00)

# Sex
  FYC <- FYC %>%
    mutate(sex = recode_factor(SEX, .default = "Missing",
      "1" = "Male",
      "2" = "Female"))

FYCdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT00F,
  data = FYC,
  nest = TRUE)

# Loop over sources of payment
  sops <- c("EXP", "SLF", "PTR", "MCR", "MCD", "OTZ")
  results <- list()

  for(sp in sops) {
    key <- paste0("TOT", sp, "00")
    formula <- as.formula(sprintf("~%s", key))
    results[[key]] <- svyby(formula, FUN = svymean, by = ~sex, design = subset(FYCdsgn, FYC[[key]] > 0))
  }

  print(results)
