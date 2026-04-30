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

n <- length(obs_vol)
train_size <- floor(n * 0.8)
test_size <- n - train_size

y_train <- matrix(as.vector(obs_vol[1:train_size]), ncol = 1)
initial_params <- rep(0.5 * log(var(y_train)), 2)

model_train <- statespacer(
  y = y_train,
  local_level_ind = TRUE,
  initial = initial_params,
  verbose = FALSE
)

fixed_var_e <- model_train$system_matrices$H$H[1,1]
fixed_var_eta <- model_train$system_matrices$Q$level[1,1]

y_all <- as.vector(obs_vol)
a <- numeric(n + 1)
P <- numeric(n + 1)
v_all <- numeric(n)
F_all <- numeric(n)
mu_filtered <- numeric(n)

a[1] <- y_all[1]
P[1] <- 1e6

for(t in 1:n) {
  v_t <- y_all[t] - a[t]
  v_all[t] <- v_t

  F_t <- P[t] + fixed_var_e
  F_all[t] <- F_t

  K_t <- P[t] / F_t

  mu_filtered[t] <- a[t] + K_t * v_t

  a[t+1] <- mu_filtered[t]
  P[t+1] <- P[t] * (1 - K_t) + fixed_var_eta
}

std_res_all <- v_all / sqrt(F_all)
std_res_oos <- std_res_all[(train_size + 1):n]

options(repr.plot.width = 12, repr.plot.height = 16)
par(mfrow = c(4, 1), mar = c(4, 4, 3, 2))

plot(y_all, type = "l", col = "gray88", lwd = 1,
     main = "Out-of-Sample Filtering",
     xlab = "", ylab = "Log-Vol Proxy", frame.plot = FALSE)
grid(nx = NULL, ny = NULL, col = "gray95")
lines(1:train_size, mu_filtered[1:train_size], col = "#0055ff", lwd = 2)
lines((train_size + 1):n, mu_filtered[(train_size + 1):n], col = "#ff8800", lwd = 2.5)
abline(v = train_size, col = "darkgreen", lty = 4)
legend("topleft", bty = "n", cex = 1,
       legend = c("Observed Data", "Training (Filtered)", "Test (OOS Filtered)"),
       col = c("gray80", "#0055ff", "#ff8800"), lty = 1, lwd = 2.5)

plot(std_res_oos, type = "h", col = "#ff8800",
     main = "OOS Standardized Residuals (z_t)",
     xlab = "", ylab = "z_t")
abline(h = 0, lty = 2)

hist(std_res_oos, breaks = 30, probability = TRUE, col = "gray96",
     main = "OOS Residual Density vs. Standard Normal", xlab = "z_t")
lines(density(std_res_oos), col = "#ff8800", lwd = 2)
curve(dnorm(x, mean=0, sd=1), add=TRUE, col="blue", lwd=2, lty=2)
legend("topright", legend=c("OOS Empirical", "N(0,1) Theoretical"),
       col=c("#ff8800", "blue"), lty=1:2, bty="n", cex = 1)

acf_res <- acf(std_res_oos, lag.max = 30, plot = FALSE)
plot(acf_res[2:31],
     main = "OOS Residual Autocorrelation (ACF)",
     ylab = "ACF",
     xlab = "Lag")

par(mfrow = c(1, 1))

cat("訓練集鎖定的 觀測誤差方差 sigma_e^2:", fixed_var_e, "\n")
cat("訓練集鎖定的 狀態擾動方差 sigma_eta^2:", fixed_var_eta, "\n")
cat("信噪比 (Signal-to-Noise Ratio, q):", fixed_var_eta / fixed_var_e, "\n")

lb_test_oos <- Box.test(std_res_oos, lag = 10, type = "Ljung-Box")
cat("\n--- 樣本外 (OOS) 殘差統計診斷 --- \n")
cat("OOS Ljung-Box Test p-value:", lb_test_oos$p.value, "\n")

if(lb_test_oos$p.value > 0.05) {
  cat("結論：p > 0.05，樣本外殘差符合白噪聲特性，參數固定策略穩健。\n")
} else {
  cat("結論：p < 0.05，樣本外殘差存在序列相關，固定參數可能無法完全捕捉當前市場波動特徵。\n")
}

cat("\n最後 10 個濾波值 (Filtered Level mu_t|t):\n")
print(tail(mu_filtered, 10))