# Install and load packages
  package_names <- c("survey","dplyr","foreign","devtools")
  lapply(package_names, function(x) if(!x %in% installed.packages()) install.packages(x))
  lapply(package_names, require, character.only=T)

  install_github("e-mitchell/meps_r_pkg/MEPS")
  library(MEPS)

  options(survey.lonely.psu="adjust")

# Load FYC file
  FYC <- read.xport('C:/MEPS/h138.ssp');
  year <- 2010

  if(year <= 2001) FYC <- FYC %>% mutate(VARPSU = VARPSU10, VARSTR=VARSTR10)
  if(year <= 1998) FYC <- FYC %>% rename(PERWT10F = WTDPER10)
  if(year == 1996) FYC <- FYC %>% mutate(AGE42X = AGE2X, AGE31X = AGE1X)

  FYC <- FYC %>%
    mutate_at(vars(starts_with("AGE")),funs(replace(., .< 0, NA))) %>%
    mutate(AGELAST = coalesce(AGE10X, AGE42X, AGE31X))

  FYC$ind = 1  

# Keep only needed variables from FYC
  FYCsub <- FYC %>% select(ind, DUPERSID, PERWT10F, VARSTR, VARPSU)

# Load event files
  RX <- read.xport('C:/MEPS/h135a.ssp')
  DVT <- read.xport('C:/MEPS/h135b.ssp')
  IPT <- read.xport('C:/MEPS/h135d.ssp')
  ERT <- read.xport('C:/MEPS/h135e.ssp')
  OPT <- read.xport('C:/MEPS/h135f.ssp')
  OBV <- read.xport('C:/MEPS/h135g.ssp')
  HHT <- read.xport('C:/MEPS/h135h.ssp')

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
    summarise_at(vars(RXSF10X:RXXP10X),sum) %>%
    ungroup

# Stack events (dental visits and other medical not collected for events)
  stacked_events <- stack_events(RX, IPT, ERT, OPT, OBV, HHT, keep.vars = c('SEEDOC','event_v2X'))

  stacked_events <- stacked_events %>%
    mutate(event = data,
           PR10X = PV10X + TR10X,
           OZ10X = OF10X + SL10X + OT10X + OR10X + OU10X + WC10X + VA10X)

# Read in event-condition linking file
  clink1 = read.xport('C:/MEPS/h135if1.ssp') %>%
    select(DUPERSID,CONDIDX,EVNTIDX)

# Read in conditions file and merge with condition_codes, link file
  cond <- read.xport('C:/MEPS/h137.ssp') %>%
    select(DUPERSID, CONDIDX, CCCODEX) %>%
    mutate(CCS_Codes = as.numeric(as.character(CCCODEX))) %>%
    left_join(condition_codes, by = "CCS_Codes") %>%
    full_join(clink1, by = c("DUPERSID", "CONDIDX")) %>%
    distinct(DUPERSID, EVNTIDX, Condition, .keep_all=T)

# Merge events with conditions-link file and FYCsub
  all_events <- full_join(stacked_events, cond, by=c("DUPERSID","EVNTIDX")) %>%
    filter(!is.na(Condition),XP10X >= 0) %>%
    mutate(count = 1) %>%
    full_join(FYCsub, by = "DUPERSID")

EVNTdsgn <- svydesign(
  id = ~VARPSU,
  strata = ~VARSTR,
  weights = ~PERWT10F,           
  data = all_events,
  nest = TRUE) 

svyby(~(XP10X > 0) + (SF10X > 0) + (MR10X > 0) + (MD10X > 0) + (PR10X > 0) + (OZ10X > 0),
by = ~Condition, FUN = svytotal, design = EVNTdsgn)
