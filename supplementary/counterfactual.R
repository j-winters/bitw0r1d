# Counterfactual scenario for different resource endowments
setwd("/set/your/directory/here/")
library(data.table)
library(tidyverse)
library(ggthemes)
library(moments)
library(purrr)

cc <- list.files(pattern = "*.csv") %>%
  map_df(~fread(.))

# Function to create counterfactual scenarios
create_counterfactual <- function(df, original_start = 100, counterfactual_start, scenario_name = NULL) {
  # If no scenario name provided, create one
  if (is.null(scenario_name)) {
    scenario_name <- paste0("start_", counterfactual_start)
  }
  
  # Calculate the adjustment amount
  adjustment <- original_start - counterfactual_start
  
  df_counterfactual <- df %>%
    group_by(seed) %>%
    mutate(
      # Adjust resource_store to counterfactual values
      resource_store_adj = resource_store - adjustment
    ) %>%
    # Keep only rows where adjusted resource_store >= 0
    filter(resource_store_adj >= 0) %>%
    # Replace original resource_store with adjusted values
    mutate(
      resource_store = resource_store_adj,
      # Add scenario identifier
      scenario = scenario_name,
      initial_resource = counterfactual_start
    ) %>%
    select(-resource_store_adj) %>%
    ungroup()
  
  return(df_counterfactual)
}

# Create multiple scenarios to combine them
counterfactual_starts <- c(1, 25, 50, 75, 100)

# Run counterfactual scenarios
# N.B. If too large for memory, break up into separate chunks
cc_counterfactual <- map_dfr(
  counterfactual_starts,
  ~ create_counterfactual(
    cc, 
    original_start = 100, 
    counterfactual_start = .x
  )
)

# Get terminal states with all variables
terminal_data <- cc_counterfactual %>%
  group_by(eta, lambda, seed, scenario) %>%
  slice_tail(n = 1) %>%  # Get the last row for each simulation
  ungroup() %>%
  mutate(
    # Adjust generation count for runs that hit tech_complexity limit
    generations_reached = if_else(tech_complexity >= 10000, 9999, generation)
  )

# Calculate the proportion reaching 9999 for each parameter combination in each scenario
proportion_9999 <- terminal_data %>%
  group_by(eta, lambda, scenario) %>%
  summarise(
    proportion_reached_9999 = mean(generations_reached == 9999),
    .groups = 'drop'
  )

# Calculate summary statistics
summary_stats <- terminal_data %>%
  # Reshape data to long format
  pivot_longer(cols = c(effectiveness, tech_complexity, space_complexity, generations_reached),
               names_to = "variable", 
               values_to = "value") %>%
  # Group by eta, lambda, and variable
  group_by(variable, eta, lambda, scenario) %>%
  # Calculate all summary statistics at once
  summarise(
    n_runs = n(),
    mean = mean(value, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    kurtosis = kurtosis(value, na.rm = TRUE),
    skewness = skewness(value, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  # Join with the proportion data
  left_join(proportion_9999, by = c("eta", "lambda", "scenario"))

# Write summmaries to output file
fwrite(summary_stats, "counterfactual.csv")

# Survival, i.e., number of generations reached
survival_summary <- cc_counterfactual %>%
  group_by(eta, lambda, seed, scenario) %>%
  mutate(scenario = as.numeric(gsub("start_", "", scenario))) %>%
  summarize(
    # Check if tech_complexity ever reached 10000
    reached_complexity_threshold = any(tech_complexity >= 10000),
    # Get the max generation actually reached
    actual_max_gen = max(generation),
    # Calculate effective survival time:
    # - If complexity threshold was reached, count as 9999 generations
    # - Otherwise, use the actual max generation
    effective_survival_time = ifelse(reached_complexity_threshold, 9999, actual_max_gen),
    .groups = 'keep'
  ) %>%
  # Average across all runs for each parameter combination
  group_by(eta, lambda, scenario) %>%
  summarize(
    avg_survival_time = mean(effective_survival_time),
    .groups = 'drop'
  )

# Heatplot of survival by endowment scenarios
survival_summary %>%
  ggplot(aes(x = as.factor(eta), y = as.factor(lambda), fill = avg_survival_time)) +
  geom_tile() +
  facet_wrap(~ scenario, ncol = 5,
             labeller = labeller(scenario = function(x) paste("Endowment:", x))) +
  scale_fill_viridis_c(name = "Mean\nGenerations", 
                       option = "mako",
                       trans = "log10",
                       labels = scales::comma) +
  labs(title = "Generations Reached Across Endowment Scenarios",
       x = "η", y = "λ") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 10, face = "bold"))

# Average complexity of technological systems
heat_cc <- cc_counterfactual %>%
  group_by(seed, eta, lambda, scenario) %>%
  mutate(scenario = as.numeric(gsub("start_", "", scenario))) %>%
  slice_tail(n = 1) %>%
  summarise(max_gen = max(generation),max_tech_complexity = tech_complexity,.groups = "drop") %>%
  group_by(eta, lambda, scenario) %>%
  summarise(tech_complexity = mean(max_tech_complexity) )

# Heatplot of complexity by endowment scenarios
heat_cc %>%
  ggplot(aes(x = as.factor(eta), y = as.factor(lambda), fill = tech_complexity)) +
  geom_tile() +
  facet_wrap(~ scenario, ncol = 5,
             labeller = labeller(scenario = function(x) paste("Endowment:", x))) +
  scale_fill_viridis_c(name = "Mean Tech\nComplexity", option = "plasma") +
  labs(title = "Terminal Tech Complexity Across Endowment Scenarios",
       x = "η", y = "λ") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 10, face = "bold"))
