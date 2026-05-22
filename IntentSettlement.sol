// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IntentSettlement {
    using ECDSA for bytes32;

    struct Intent {
        address user;
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;

    /**
     * @dev Settles a signed intent. Solvers call this after finding the optimal route.
     */
    function fulfillIntent(
        Intent calldata intent,
        bytes calldata signature,
        bytes calldata executionData
    ) external {
        require(block.timestamp <= intent.deadline, "Intent expired");
        require(nonces[intent.user] == intent.nonce, "Invalid nonce");
        
        // Verify user signature (EIP-712 check omitted for brevity)
        nonces[intent.user]++;

        // 1. Pull user tokens
        IERC20(intent.tokenIn).transferFrom(intent.user, address(this), intent.amountIn);
        
        // 2. Execute solver's specialized trade logic (e.g., RWA swap or LST rotation)
        (bool success, ) = msg.sender.call(executionData);
        require(success, "Solver execution failed");

        // 3. Verify constraint satisfaction
        uint256 balanceOut = IERC20(intent.tokenOut).balanceOf(address(this));
        require(balanceOut >= intent.minAmountOut, "Insufficient output");
        IERC20(intent.tokenOut).transfer(intent.user, balanceOut);
    }
}
