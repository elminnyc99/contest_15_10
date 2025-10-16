## Contract quản lý phân loại rủi ro và giới hạn phân bổ cho các strategy trong MYT. Contract này sử dụng interface IStrategyClassifier để cung cấp thông tin về risk level và caps cho từng loại strategy.

## globalCap: Tổng giới hạn phân bổ cho TẤT CẢ các strategies có cùng risk level

## localCap: Giới hạn phân bổ tối đa cho MỖI strategy riêng lẻ trong cùng risk class đó

## vd: Giả sử bạn có một Morpho V2 Vault (MYT) với tổng tài sản là 1000 ETH, và có risk level 1 (Medium risk) với:

globalCap = 300 ETH
localCap = 100 ETH

Ví dụ: Nếu bạn có 5 strategies khác nhau đều là Medium risk:

Strategy A: 100 ETH
Strategy B: 70 ETH
Strategy C: 30 ETH
Strategy D: 60 ETH
Strategy E: 40 ETH

Tổng bằng 300 và không có strategy nào có cap vượt quá 100

Mỗi riskLevel có RiskClass rieng thông qua riskClasses

Và mỗi strategy có risk class riêng thông qua mapping strategyRiskLevel
