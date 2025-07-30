setwd("/set/your/directory/here/")
library(data.table)
library(tidyverse)
library(ggthemes)
library(moments)

cc <- list.files(pattern = "*.csv") %>%
  map_df(~fread(.))

# Get terminal states with all variables
terminal_data <- cc %>%
  group_by(eta, lambda, seed) %>%
  slice_tail(n = 1) %>%  # Get the last row for each simulation
  ungroup() %>%
  mutate(
    # Adjust generation count for runs that hit tech_complexity limit
    generations_reached = if_else(tech_complexity >= 10000, 9999, generation)
  )

# Calculate number of runs that failed to reached generation 9999
mean(terminal_data$generations_reached != 9999)

# Calculate the proportion reaching 9999 for each parameter combination
proportion_9999 <- terminal_data %>%
  group_by(eta, lambda) %>%
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
  group_by(variable, eta, lambda) %>%
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
  left_join(proportion_9999, by = c("eta", "lambda"))

# Export summary statistics
fwrite(summary_stats,"summaries.csv")

# Survival dataset
survival_summary <- cc %>%
  group_by(eta, lambda, seed) %>%
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
  group_by(eta, lambda) %>%
  summarize(
    avg_survival_time = mean(effective_survival_time),
    .groups = 'drop'
  )

# Heatmap for number of generations reached (Figure 2A in Winters & Charbonneau, 2025)
survival_summary %>%
  ggplot(., aes(x = as.factor(eta), y = as.factor(lambda), fill = log2(avg_survival_time) )) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5)) +
  geom_tile(color = "white",lwd = 1.5,linetype = 1) + theme_hc() +
  labs(x = "η", y = "λ") +
  coord_fixed() +
  theme(axis.text=element_text(size=14), 
        axis.title=element_text(size=16,face="bold"), 
        legend.title = element_text(size = 14, face="bold"), 
        legend.text = element_text(size = 12), 
        legend.key.width = unit(4,"line") ) +
  scale_fill_viridis_c(direction = -1, option = "magma")

# Average complexity 
heat_cc <- cc %>%
  group_by(seed, eta, lambda) %>%
  slice_tail(n = 1) %>%
  summarise(max_gen = max(generation),max_tech_complexity = tech_complexity,.groups = "drop") %>%
  group_by(eta, lambda) %>%
  summarise(tech_complexity = mean(max_tech_complexity) )

# Heatmap for tech_complexity (Figure 2B in Winters & Charbonneau, 2025)
heat_cc %>%
  ggplot(., aes(x = as.factor(eta), y = as.factor(lambda), fill = tech_complexity )) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5)) +
  geom_tile(color = "white",lwd = 1.5,linetype = 1) + theme_hc() +
  labs(x = "η", y = "λ") +
  coord_fixed() +
  theme(axis.text=element_text(size=14), axis.title=element_text(size=16,face="bold"), legend.title = element_text(size = 14, face="bold"), legend.text = element_text(size = 12), legend.key.width = unit(4,"line") ) +
  scale_fill_viridis_c(direction = -1, option = "viridis")

# Plot complexity of technological systems and search spaces
plot_complexity <- function(df, seed_param_list, color_option = "natural") {
  # Initialize empty data frame for combined data
  combined_data <- data.frame()
  final_data_all <- data.frame()
  
  # Process each seed/parameter combination
  for (i in seq_along(seed_param_list)) {
    params <- seed_param_list[[i]]
    
    # Extract parameters
    target_seed <- params$seed
    target_eta <- params$eta
    target_lambda <- params$lambda
    
    # Filter data for this specific combination
    subset_data <- df %>%
      filter(seed == target_seed, eta == target_eta, lambda == target_lambda)
    
    # Get the final generation for this run
    final_generation <- max(subset_data$generation)
    final_data <- subset_data %>%
      filter(generation == final_generation)
    
    # Add id for this combination
    combination_id <- paste("Seed:", target_seed, "| eta:", target_eta, "| lambda:", target_lambda)
    subset_data$combination_id <- combination_id
    final_data$combination_id <- combination_id
    final_data$distance <- abs(final_data$tech_complexity - final_data$space_complexity)
    final_data$metrics_text <- paste("Eff:", round(final_data$effectiveness, 2), "| Res:", round(final_data$available_resources, 2))
    
    # Combine with overall data
    combined_data <- rbind(combined_data, subset_data)
    final_data_all <- rbind(final_data_all, final_data)
  }
  
  # Colour palette
  n_combinations <- length(unique(combined_data$combination_id))
  
  # Select colour palette
  if (color_option == "nature") {
    # Nature journal style colors
    base_colors <- c("#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F", "#8491B4", "#91D1C2", "#DC0000")
    if (n_combinations > length(base_colors)) {
      base_colors <- colorRampPalette(base_colors)(n_combinations)
    }
  } else {
    # Default to ColorBrewer
    base_colors <- RColorBrewer::brewer.pal(min(9, max(3, n_combinations)), "Set1")
  }
  
  # Create tech/space complexity colour pairs with different lightness
  color_palette <- c()
  for (i in 1:n_combinations) {
    # Convert base colour to HSL for manipulation
    base_color <- base_colors[i]
    tech_color <- colorspace::darken(base_color, amount = 0.1)
    space_color <- colorspace::lighten(base_color, amount = 0.2)
    
    combo_id <- unique(combined_data$combination_id)[i]
    color_palette[paste(combo_id, "- Tech")] <- tech_color
    color_palette[paste(combo_id, "- Space")] <- space_color
  }
  
  # Create the main plot
  p <- ggplot(combined_data, aes(x = generation, group = combination_id)) +
    # Plot technology complexity
    geom_line(aes(y = tech_complexity, color = paste(combination_id, "- Tech")), 
              linewidth = 1.2, alpha = 0.8) +
    # Plot space complexity
    geom_line(aes(y = space_complexity, color = paste(combination_id, "- Space")), 
              linewidth = 1.2, alpha = 0.8) +
    
    # Add points at the final generation
    geom_point(data = final_data_all, 
               aes(y = tech_complexity, color = paste(combination_id, "- Tech")), 
               size = 3, shape = 21, fill = "white", stroke = 2) +
    geom_point(data = final_data_all, 
               aes(y = space_complexity, color = paste(combination_id, "- Space")), 
               size = 3, shape = 21, fill = "white", stroke = 2) +
    
    coord_cartesian(xlim = c(0,10000) ) +
    
    # Customize the plot
    scale_color_manual(values = color_palette) +
    labs(
      title = "Complexity of technological systems and search spaces for select seeds and parameter combinations",
      x = "Generation",
      y = "Complexity",
      color = "Seed/Parameters"
    ) +
    theme_bw(base_size = 12) +
    theme(
      legend.position = "right",
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(size = 12),
      legend.title = element_text(size = 11),
      legend.text = element_text(size = 9),
      panel.grid.minor = element_blank(),
      legend.key.size = unit(0.4, "cm"),
      legend.spacing.y = unit(0.2, "cm"),
      strip.text = element_text(size = 10),
      axis.text = element_text(size = 10)
    ) +
    # Add some padding to x-axis to accommodate text
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.2)), 
                       breaks = seq(0, 10000, by = 1000),
                       limits = c(0, 10000)) +
    scale_y_continuous(breaks = seq(0, 10000, by = 1000),
                       limits = c(0, 12000))
  
  return(p)
}

# List of seeds and parameter combinations
seed_param_combinations <- list(
  list(seed = 26514, eta = 0.99, lambda = 0.99),
  list(seed = 764192, eta = 0.10, lambda = 0.99),
  list(seed = 472106, eta = 0.99, lambda = 0.10),
  list(seed = 758286, eta = 0.80, lambda = 0.80),
  list(seed = 125737, eta = 0.95, lambda = 0.95),
  list(seed = 167360, eta = 0.95, lambda = 0.99),
  list(seed = 328500, eta = 0.99, lambda = 0.95),
  list(seed = 959093, eta = 0.95, lambda = 0.05)
)

# Create the plot (Figure 2C in Winters & Charbonneau, 2025)
plot_complexity(cc, seed_param_combinations, color_option = "nature")

# Figure 3 in winters & Charbonneau (2025)
ggplot(subset(cc, eta %in% c(0.01, 0.99) &
                lambda %in% c(0.01, 0.99)),
       aes(x = generation, y = tech_complexity)) +
  geom_line(aes(colour = as.factor(seed),
                group = interaction(as.factor(seed), as.factor(eta), as.factor(lambda))),
            linewidth = 0.5, alpha = 1.0) +
  facet_wrap(~ eta + lambda,
             scales = "free",
             ncol = 2,  # 2 columns to match your lambda values
             labeller = labeller(eta = function(x) paste("η =", x),lambda = function(x) paste("λ =", x)) ) +
  ylab("Complexity") +
  xlab("Generation") +
  scale_colour_viridis_d(option = "mako") +
  theme_hc() +
  theme(legend.position = "none",
        axis.text = element_text(size = 10),  
        axis.title = element_text(size = 16, face = "bold"),
        strip.text = element_text(size = 10, face = "bold"))


df_com_eff <- cc %>%
  filter(eta %in% c(0.40, 0.90) & lambda %in% c(0.40, 0.90)) %>%
  mutate(params = paste("η =", eta, ", λ =", lambda)) %>%
  select(seed, params, generation, tech_complexity, effectiveness) %>%
  pivot_longer(cols = c(tech_complexity, effectiveness),
               names_to = "metric",
               values_to = "value") %>%
  mutate(metric = factor(metric,
                         levels = c("tech_complexity", "effectiveness"),
                         labels = c("Technological Complexity", "Effectiveness")))

# Figure 4 in winters & Charbonneau (2025)
ggplot(df_com_eff,
       aes(x = generation, y = value)) +
  geom_line(aes(colour = as.factor(seed),
                group = as.factor(seed)),
            linewidth = 0.5, alpha = 1.0) +
  facet_grid(metric ~ params,
             scales = "free") +
  ylab("") +
  xlab("Generation") +
  scale_colour_viridis_d(option = "mako") +
  theme_hc() +
  theme(legend.position = "none",
        axis.text = element_text(size = 10),  
        axis.title = element_text(size = 16, face = "bold"),
        strip.text = element_text(size = 10, face = "bold"),
        strip.background = element_rect(fill = "lightgray"),
        strip.text.y = element_text(angle = 0))
