Contract chính của giao thức.
Một hệ thống Collateralized Debt Position (Vị thế nợ thế chấp)

CDP là một vị thế nợ thế chấp có nghĩa là một khoản vay được tạo ra bằng cách đặt tài sản thế chấp (collateral) và nhận về debt token.



User → deposit USDC → Morpho Vault → receive MYT shares --> deposit MYT shares --> AlchemistV3 --> recieve NFT --> mint debt token dựa trên số MYT đã nạp.

Có 2 cách để nhận lại collateral là: 
- Burn debt token (alUSDC) nhận lại MYT shares
- Redemption thông qua transmuter.
- Khi có người tạo redemption thì tất cacr các CDP sẽ bị earmark một phần debt theo tính toán (dựa the weight) để buộc họ phải repay bằng MYT shares (chuyển trực tiếp vào transmuter trả cho người tạo redemption ở trên)



## Yeild-bearing Collateral là tài sản thế chấp tự sinh lời ở đây chính là MYT shares

## Synthetic Debt Tokens

## Là token được minted không được hỗ trợ bởi USDC mà dduojec back bởi MYT share

ERC721Enumerable là gì

## Transmuter là một contract riêng biệt (src/Transmuter.sol) cho phép users đổi synthetic debt tokens (alUSD, alETH) sang underlying tokens (USDC, WETH) theo thời gian. Đây là cơ chế "exit" chính của protocol.

## Redemption là gì?

Redemption là quá trình đổi synthetic debt tokens sang underlying tokens thông qua Transmuter.
