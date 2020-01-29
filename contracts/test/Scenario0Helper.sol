pragma solidity 0.5.11;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/CTokenInterface.sol";
import "../../interfaces/DTokenInterface.sol";
import "../../interfaces/ERC20Interface.sol";


contract Scenario0Helper {
  using SafeMath for uint256;

  uint256 public timeZero;
  uint256 public blockZero;
  uint256 public underlyingUsedToMintEachToken;
  uint256 public cTokensMinted;
  uint256 public dTokensMinted;

  uint256 public timeOne;
  uint256 public blockOne;
  uint256 public underlyingReturnedFromCTokens;
  uint256 public underlyingReturnedFromDTokens;
  uint256 public interestRateFromCToken;
  uint256 public interestRateFromDToken;
  uint256 public calculatedInterestRateFromDToken;
  uint256 public calculatedSurplus;
  uint256 public dTokenSurplus;

  uint256 private constant _SCALING_FACTOR = 1e18;

  // First approve this contract to transfer underlying for the caller.
  function phaseOne(
    CTokenInterface cToken,
    DTokenInterface dToken,
    ERC20Interface underlying
  ) external {
    timeZero = now;
    blockZero = block.number;

    ERC20Interface dTokenBalance = ERC20Interface(address(dToken));

    // ensure that this address doesn't have any underlying tokens yet.
    require(
      underlying.balanceOf(address(this)) == 0,
      "underlying balance must start at 0."
    );

    // ensure that this address doesn't have any cTokens yet.
    require(
      cToken.balanceOf(address(this)) == 0,
      "cToken balance must start at 0."
    );

    // ensure that this address doesn't have any dTokens yet.
    require(
      dTokenBalance.balanceOf(address(this)) == 0,
      "dToken balance must start at 0."
    );

    // approve cToken to transfer underlying on behalf of this contract.
    require(
      underlying.approve(address(cToken), uint256(-1)), "cToken Approval failed."
    );

    // approve dToken to transfer underlying on behalf of this contract.
    require(
      underlying.approve(address(dToken), uint256(-1)), "dToken Approval failed."
    );

    // get the underlying balance of the caller.
    uint256 underlyingBalance = underlying.balanceOf(msg.sender);

    // ensure that it is at least 1 million.
    require(
      underlyingBalance >= 1000000,
      "Underlying balance is not at least 1 million of lowest-precision units."
    );

    // pull in underlying from caller in multiples of 1 million.
    uint256 balanceIn = (underlyingBalance / 1000000) * 1000000;
    require(
      underlying.transferFrom(msg.sender, address(this), balanceIn),
      "Underlying transfer in failed."
    );

    // use half of the balance in for both operations.
    underlyingUsedToMintEachToken = balanceIn / 2;

    // mint cTokens using underlying.
    require(
      cToken.mint(underlyingUsedToMintEachToken) == 0, "cToken mint failed."
    );

    // get the number of cTokens minted.
    cTokensMinted = cToken.balanceOf(address(this));

    // mint dTokens using underlying.
    dTokensMinted = dToken.mint(underlyingUsedToMintEachToken);
    require(
      dTokensMinted == dTokenBalance.balanceOf(address(this)),
      "dTokens minted do not match returned value."
    );

    // ensure that this address doesn't have any underlying tokens left.
    require(
      underlying.balanceOf(address(this)) == 0,
      "underlying balance must end at 0."
    );
  }

  function phaseTwo(
    CTokenInterface cToken,
    DTokenInterface dToken,
    ERC20Interface underlying
  ) external {
    timeOne = now;
    blockOne = block.number;

    ERC20Interface dTokenBalance = ERC20Interface(address(dToken));

    // ensure that this address doesn't have any underlying tokens yet.
    require(
      underlying.balanceOf(address(this)) == 0,
      "underlying balance must start at 0."
    );

    // ensure that this address doesn't have any cTokens yet.
    require(
      cToken.balanceOf(address(this)) == cTokensMinted,
      "cToken balance must start at cTokensMinted."
    );

    // ensure that this address doesn't have any dTokens yet.
    require(
      dTokenBalance.balanceOf(address(this)) == dTokensMinted,
      "dToken balance must start at dTokensMinted."
    );

    // redeem cTokens for underlying.
    require(
      cToken.redeem(cTokensMinted) == 0, "cToken redeem failed."
    );

    // get balance of underlying returned.
    underlyingReturnedFromCTokens = underlying.balanceOf(address(this));

    // return the underlying balance to the caller.
    require(
      underlying.transfer(msg.sender, underlyingReturnedFromCTokens),
      "Underlying transfer out after cToken redeem failed."
    );

    // redeem dTokens for underlying.
    underlyingReturnedFromDTokens = dToken.redeem(dTokensMinted);
    require(
      underlyingReturnedFromDTokens == underlying.balanceOf(address(this)),
      "underlying redeemed from dTokens do not match returned value."
    );

    // return the underlying balance to the caller.
    require(
      underlying.transfer(msg.sender, underlyingReturnedFromDTokens),
      "Underlying transfer out after dToken redeem failed."
    );

    // interest earned on cTokens
    interestRateFromCToken = underlyingReturnedFromCTokens.sub(underlyingUsedToMintEachToken);

    // interest earned on dTokens
    interestRateFromDToken = underlyingReturnedFromDTokens.sub(underlyingUsedToMintEachToken);

    calculatedInterestRateFromDToken = interestRateFromCToken.sub(interestRateFromCToken.div(10));

    require(
      calculatedInterestRateFromDToken >= interestRateFromDToken,
      "Interest rate earned on dToken is at most 90%."
    );

    // ensure that interest rates earned on dTokens is at least 99.99999% of expected interest rate
    require(
      (
      interestRateFromDToken.mul(_SCALING_FACTOR)
      ).div(calculatedInterestRateFromDToken) >= _SCALING_FACTOR.sub(1e11),
      "Interest rate received from dTokens is 99.99999% of expected."
    );

    // Surplus should be 10% of interest earned
    calculatedSurplus = interestRateFromCToken.div(10);

    // get the surplus on the dToken
    dTokenSurplus = dToken.getSurplus();

    require(
      calculatedSurplus >= dTokenSurplus,
      "Surplus is at most 10% of."
    );

    // ensure that interest rates earned on dTokens is at least 99.99999% of expected interest rate
//    require(
//      (
//      dTokenSurplus.mul(_SCALING_FACTOR)
//      ).div(calculatedSurplus) >= _SCALING_FACTOR.sub(1e11),
//      "Surplus is 99.99999% of expected."
//    );
//
//    require(
//      dTokenSurplus == interestRateFromDToken.div(10),
//      "Surplus is 10% of total interest earned on dTokens."
//    );
  }
}