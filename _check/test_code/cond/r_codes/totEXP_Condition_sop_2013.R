# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h163.ssp');
  year <- 2013

  if(year <= 2001) FYC <- FYC %>% mutate(VARPSU = VARPSU13, VARSTR=VARSTR13)
  if(year <= 1998) FYC <- FYC %>% rename(PERWT13F = WTDPER13)
  if(year == 1996) FYC <- FYC %>% mutate(AGE42X = AGE2X, AGE31X = AGE1X)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE13X, AGE42X, AGE31X))

  FYC$ind = 1  

# Add aggregate sources of payment
  if(year <= 1999)
    FYC <- FYC %>% mutate(TOTTRI13 = TOTCHM13)

  FYC <- FYC %>% mutate(
    TOTOTH13 = TOTOFD13 + TOTSTL13 + TOTOPR13 + TOTOPU13 + TOTOSR13,
    TOTOTZ13 = TOTOTH13 + TOTWCP13 + TOTVA13,
    TOTPTR13 = TOTPRV13 + TOTTRI13)

# Keep only needed variables from FYC
  FYCsub <- FYC %>% select(ind, DUPERSID, PERWT13F, VARSTR, VARPSU)

# Load event files
  RX <- read.xport('C:/MEPS/h160a.ssp')
  DVT <- read.xport('C:/MEPS/h160b.ssp')
  IPT <- read.xport('C:/MEPS/h160d.ssp')
  ERT <- read.xport('C:/MEPS/h160e.ssp')
  OPT <- read.xport('C:/MEPS/h160f.ssp')
  OBV <- read.xport('C:/MEPS/h160g.ssp')
  HHT <- read.xport('C:/MEPS/h160h.ssp')

# Define sub-levels for office-based and outpatient
  OBV <- OBV %>%
    mutate(event_v2X = recode_factor(
      SEEDOC, .default = 'Missing', '1' = 'OBD', '2' = 'OBO'))

  OPT <- OPT %>%
    mutate(event_v2X = recode_factor(
      SEEDOC, .default = 'Missing', '1' = 'OPY', '2' = 'OPZ'))

# Sum RX purchases for each event
  RX <- RX %>%
    rename(EVNTIDX = LINKIDX) %>%
    group_by(DUPERSID,EVNTIDX) %>%
    summarise_at(vars(RXSF13X:RXXP13X),sum) %>%
    ungroup

# Stack events (dental visits and other medical not collected for events)
  stacked_events <- stack_events(RX, IPT, ERT, OPT, OBV, HHT, keep.vars = c('SEEDOC','event_v2X'))

  stacked_events <- stacked_events %>%
    mutate(event = data,
           PR13X = PV13X + TR13X,
           OZ13X = OF13X + SL13X + OT13X + OR13X + OU13X + WC13X + VA13X)

# Read in event-condition linking file
  clink1 = read.xport('C:/MEPS/h160if1.ssp') %>%
    select(DUPERSID,CONDIDX,EVNTIDX)

# Read in conditions file and merge with condition_codes, link file
  cond <- read.xport('C:/MEPS/h162.ssp') %>%
    select(DUPERSID, CONDIDX, CCCODEX) %>%
    mutate(CCS_Codes = as.numeric(as.character(CCCODEX))) %>%
    left_join(condition_codes, by = "CCS_Codes") %>%
    full_join(clink1, by = c("DUPERSID", "CONDIDX")) %>%
    distinct(DUPERSID, EVNTIDX, Condition, .keep_all=T)

# Merge events with conditions-link file and FYCsub
  all_events <- full_join(stacked_events, cond, by=c("DUPERSID","EVNTIDX")) %>%
    filter(!is.na(Condition),XP13X >= 0) %>%
    mutate(count = 1) %>%
    full_join(FYCsub, by = "DUPERSID")

EVNTdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT13F,           
  data = all_events,
  nest = TRUE) 

svyby(~XP13X + SF13X + MR13X + MD13X + PR13X + OZ13X, by = ~Condition, FUN = svytotal, design = EVNTdsgn)
