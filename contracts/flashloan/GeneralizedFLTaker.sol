pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../interfaces/ILendingPool.sol";
import "./DydxFlashLoanBase.sol";
import "../utils/SafeERC20.sol";

contract GeneralizedFLTaker is DydxFlashLoanBase {

    enum LoanType { AAVE, DYDX }

    using SafeERC20 for ERC20;

    address public constant AAVE_LENDING_POOL_ADDRESSES = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // TODO: should we check if _amount request is avail. ?
    // TODO: Should AaveLendingPoolAddr be mutable?
    function takeLoan(
        address payable _receiver,
        address _token,
        uint _amount,
        bytes memory _data,
        LoanType _type
    ) public {
        if (_type == LoanType.AAVE) {
            ILendingPool(AAVE_LENDING_POOL_ADDRESSES).flashLoan(_receiver, _token, _amount, _data);
        } else if (_type == LoanType.DYDX) {
            dydxFlashLoan(_receiver, _token, _amount, _data);
        }
    }

    function dydxFlashLoan(address payable _receiver,
        address _token,
        uint _amount,
        bytes memory _data
    ) internal {

        if (_token == ETH_ADDR) {
            _token = WETH_ADDR;
        }

        ISoloMargin solo = ISoloMargin(SOLO_MARGIN_ADDRESS);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(SOLO_MARGIN_ADDRESS, _token);

        uint256 repayAmount = _getRepaymentAmountInternal(_amount);

        ERC20(_token).safeApprove(SOLO_MARGIN_ADDRESS, 0);
        ERC20(_token).safeApprove(SOLO_MARGIN_ADDRESS, repayAmount);

        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount, _receiver);
        operations[1] = _getCallAction(
            _data,
            _receiver
        );
        operations[2] = _getDepositAction(marketId, repayAmount, address(this));

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }
}

