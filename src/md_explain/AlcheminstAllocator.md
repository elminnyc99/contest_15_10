Hợp đồng này được sử dụng để phân bổ và thu hồi vốn tiền cho và từ các chiến lược MYT
MYT là Morpho V2 Vault, và mỗi chiến lược chỉ là một bộ điều hợp (vault adapter) giao tiếp với giao thức của bên thứ ba.

## Morpho V2 Vaul đóng vai trò là vault chính (core vault) để lưu trữ và quản lý tài sản

## Luồng hoạt động

Users deposit tài sản vào Morpho V2 Vault và nhận MYT tokens
AlchemistAllocator (được điều khiển bởi admin/operator) phân bổ tài sản từ vault vào các strategies/adapters
Mỗi adapter tương tác với một protocol bên thứ ba (Aave, Compound, etc.) để sinh lời
Lợi nhuận được tích lũy và có thể được deallocate về vault khi cần

IVaultV2 : địa chỉ của một vaultV2

Kiểm tra xem tài sản trong VaulV2 có khác địa chỉ không

set quyền cho 2 hàm allocate và deallocate với (function selector của chúng) lấy 4 byte đầu tiên
0x5c9ce04d = keccak256("allocate(address,bytes,uint256)")[:4]
0x4b219d16 = keccak256("deallocate(address,bytes,uint256)")[:4]

Phân bổ (Allocation) là quá trình chuyển vốn từ vault chính vào các strategy cụ thể thông qua hàm allocate (Giống như việc công ty mẹ chuyển tiền sang công ty con)

## absoluteCap là giới hạn tuyệt đối (hard cap) là số lượng tài sản tối đa có thể phân bổ vào strategy

## relativeCap là giới hạn tương dối theo phần trăm theo tổng tài sản có trong vault. Ví dụ relativeCap bằng 20% và vault có 10m thì strategy này có thể nhận tối đa 2m

Mục đích của adjusted
Biến adjusted không được sử dụng trực tiếp trong hàm allocate hiện tại - đây có vẻ là một bug hoặc code chưa hoàn thiện. Logic tính toán adjusted nhưng không validate amount với giá trị này trước khi gọi vault.allocate().

## Thu hồi vốn (deallocate) từ một strategy về vault

Khi muốn rút toàn bộ số tiền từ strategy, bạn không nên truyền trực tiếp số tiền hiện có. Thay vào đó, nên:

Gọi IMYTStrategy(adapter).previewAdjustedWithdraw(amount) trước
Sử dụng giá trị trả về làm tham số amount cho deallocate
Lý do: Khi rút tiền từ các protocol bên thứ ba (Aave, Compound, etc.), có thể phát sinh:

Slippage: Chênh lệch giá khi swap
Protocol fees: Phí của protocol
Rounding differences: Sai số làm tròn trong tính toán

