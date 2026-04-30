# 局部水平

$$
\begin{aligned}
y_t &= \mu_t + e_t, \quad \{e_t\} \sim \text{iid } N(0, \sigma_e^2), \quad t = 1, 2, \dots, n, \\
\mu_{t+1} &= \mu_t + \eta_t, \quad \{\eta_t\} \sim \text{iid } N(0, \sigma_{\eta}^2),
\end{aligned}
$$

$$y_t$$ 稱為觀測方程，代表系統在 t 時刻的輸出值

$$\mu_t$$ 稱為狀態方程，這個不可觀測，他描述系統內在演變規律

# 卡曼慮波

$$
\begin{cases}
v_t = y_t - a_t, \\
F_t = P_t + \sigma_e^2, \\
K_t = P_t / F_t, \\
a_{t+1} = \mu_{t+1|t} = a_t + K_t v_t, \\
P_{t+1} = \Sigma_{t+1|t} = P_t (1 - K_t) + \sigma_\eta^2, \quad t = 1, 2, \dots, n.
\end{cases}
$$

1. 測量殘差 (Measurement Innovation)
2. 預測誤差變異數 (Prediction Error Variance)
3. 卡曼增益 (Kalman Gain)
4. 狀態更新 (State Update)
5. 誤差變異數更新 (Covariance Update)

卡曼慮波屬於遞迴算法，只需要t-1的訊息來估計第t天的水平

但要注意用來更新水平的方差參數 $\sigma_e^2$  (觀測雜訊) $\sigma_\eta^2$ (狀態轉移的雜訊) 是利用全樣本(全局視野)擬和出來的


# 方差參數擬和 (MLE)
#### 似然函數構建
利用卡曼濾波遞歸產出的一步預報誤差 $v_t$ 和預報方差 $F_t$，可以構建出整段時間序列（長度為 $n$）的對數似然函數：

$$ \ln L = -\frac{n}{2} \ln(2\pi) - \frac{1}{2} \sum_{t=1}^{n} \left( \ln F_t + \frac{v_t^2}{F_t} \right) $$

#### 參數的「全局視野」擬合
在實際應用中（如 R 語言的 `statespacer` 或自建的 MLE 優化器），系統會透過數值優化算法不斷調整以下兩個參數，直到 $\ln L$ 達到最大值：

*   **觀測方差:** $\sigma_e^2$ 
*   **狀態轉移方差:** $\sigma_\eta^2$

用來更新水平狀態的方差參數 $\sigma_e^2$ 與 $\sigma_\eta^2$ 是利用 **全樣本** 擬合出來的固定常數。這意味著，模型在任意時間點 $t$ 進行狀態更新時，其依賴的雜訊權重（Kalman Gain）實際上已經隱含了對整段歷史數據全局統計特性的先驗認知，而非僅僅依賴局部的數據變化。


# 全樣本
最後 10 個濾波值
-10.56352, -10.63146, -10.51068, -10.58787, -10.44673, -10.37032, -10.42394, -10.41989, -10.28284, -10.15897

估計的觀測誤差方差 (sigma_e^2): 2.8898 
估計的狀態擾動方差 (sigma_eta^2): 0.01007755 

<img width="745" height="590" alt="image" src="https://github.com/user-attachments/assets/05ed1534-e065-4336-8674-029cf4e9eaf1" />

# 樣本內樣本外
最後 10 個濾波值
-10.54863, -10.62082, -10.49472, -10.57668, -10.42925, -10.35012, -10.40760, -10.40434, -10.26145, -10.13276

訓練集鎖定的 觀測誤差方差 sigma_e^2: 2.928869 
訓練集鎖定的 狀態擾動方差 sigma_eta^2: 0.01128069 

<img width="907" height="589" alt="image" src="https://github.com/user-attachments/assets/8dda20bd-74c0-42f6-a72b-f747309200f2" />

樣本內擬和好的參數固定好後直接套入新的數據，估計出的水平和全樣本差不多



## 安裝包
install.packages("quantmod")

install.packages("rugarch")

install.packages(c("fGarch", "plotly", "dplyr"))

install.packages("statespacer")

