library(quantmod)
library(statespacer)
library(magrittr)

ticker <- "SPY"
start_date <- "2024-01-01"
end_date <- "2026-12-13"
getSymbols(ticker, from = start_date, to = end_date, auto.assign = FALSE) -> aa_data
aa_close <- aa_data[, paste0(ticker , ".Close")]

log_returns <- diff(log(aa_close)) %>% na.omit()

obs_vol <- log(log_returns^2 + 1e-6)

y_matrix <- matrix(as.vector(obs_vol), ncol = 1)

initial_params <- rep(0.5 * log(var(obs_vol)), 2)

ssr_model <- statespacer(
  y = y_matrix,
  local_level_ind = TRUE,
  initial = initial_params,
  verbose = FALSE
)

all_filtered_mu <- ssr_model$filtered$level
smoothed_mu <- ssr_model$smoothed$level

v_vec <- as.vector(ssr_model$predicted$v)
F_vec <- as.vector(ssr_model$predicted$Fmat[1, 1, ])

std_res <- v_vec / sqrt(F_vec)
std_res <- na.omit(std_res)

options(repr.plot.width = 10, repr.plot.height = 16)
par(mfrow = c(4, 1), mar = c(4, 4, 3, 2))

plot(as.vector(obs_vol), type = "l", col = "gray80",
     main = "SPY Log-Volatility: Local Level Model Fit",
     xlab = "", ylab = "Log-Vol Proxy")
lines(as.vector(all_filtered_mu), col = "red", lwd = 1.5)
legend("topright", legend = c("Observed (Noisy)", "Filtered"),
       col = c("gray80", "red", "darkgreen"), lty = c(1, 1, 2), bty = "n", cex = 1)

plot(std_res, type = "h", col = "steelblue",
     main = "Standardized Residuals (z_t)",
     xlab = "", ylab = "z_t")
abline(h = 0, lty = 2)

hist(std_res, breaks = 45, probability = TRUE, col = "gray95",
     main = "Residual Density vs. Standard Normal", xlab = "z_t")
lines(density(std_res), col = "red", lwd = 2)
curve(dnorm(x, mean=0, sd=1), add=TRUE, col="blue", lwd=2, lty=2)
legend("topright", legend=c("Empirical Density", "N(0,1) Theoretical"),
       col=c("red", "blue"), lty=1:2, bty="n", cex = 1)

acf_res <- acf(std_res, lag.max = 30, plot = FALSE)
plot(acf_res[2:31],
     main = "Residual Autocorrelation (ACF)",
     ylab = "ACF",
     xlab = "Lag")

par(mfrow = c(1, 1))

lb_test <- Box.test(std_res, lag = 10, type = "Ljung-Box")
cat("\n--- 標準化殘差統計診斷 --- \n")
cat("Ljung-Box Test p-value:", lb_test$p.value, "\n")

if(lb_test$p.value > 0.05) {
  cat("結論：p > 0.05，無法拒絕 H0。殘差符合白噪聲特性，模型擬合良好。\n")
} else {
  cat("結論：p < 0.05，拒絕 H0。殘差存在自相關，模型可能漏掉了某些趨勢或週期。\n")
}

cat("估計的觀測誤差方差 (sigma_e^2):", ssr_model$system_matrices$H$H, "\n")
cat("估計的狀態擾動方差 (sigma_eta^2):", ssr_model$system_matrices$Q$level, "\n")
cat("信噪比 (Signal-to-Noise Ratio, q):", ssr_model$system_matrices$Q$level / ssr_model$system_matrices$H$H, "\n")

cat("\n最後 10 個濾波值 (Filtered Level mu_t|t):\n")
print(tail(all_filtered_mu, 10))