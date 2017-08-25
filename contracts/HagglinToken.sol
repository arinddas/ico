pragma solidity ^0.4.13;

/**
 * Originally from https://github.com/TokenMarketNet/ico
 * Modified by https://www.coinfabrik.com/
 */

import "./FractionalERC20.sol";
import "./ReleasableToken.sol";
import "./MintableToken.sol";
import "./UpgradeableToken.sol";

/**
 * A crowdsale token.
 *
 * An ERC-20 token designed specifically for crowdsales with investor protection and further development path.
 *
 * - The token transfer() is disabled until the crowdsale is over
 * - The token contract gives an opt-in upgrade path to a new contract
 * - The same token can be part of several crowdsales through the approve() mechanism
 * - The token can be capped (supply set in the constructor) or uncapped (crowdsale contract can mint new tokens)
 *
 */
contract HagglinToken is ReleasableToken, MintableToken, UpgradeableToken, FractionalERC20 {

  string constant public name = "Ribbits";
  string constant public symbol = "RBT";

  /**
   * Construct the token.
   *
   * This token must be created through a team multisig wallet, so that it is owned by that wallet.
   *
   * @param _name Token name
   * @param _symbol Token symbol - typically it's all caps
   * @param _initialSupply How many tokens we start with
   * @param _decimals Number of decimal places
   * @param _mintable Are new tokens created over the crowdsale or do we distribute only the initial supply? Note that when the token becomes transferable the minting always ends.
   */
  function HagglinToken(string _name, string _symbol, uint _initialSupply, uint8 _decimals, address _multisig)
    UpgradeableToken(_multisig) MintableToken(_initialSupply, msg.sender, false) {
    decimals = _decimals;
  }

  /**
   * When token is released to be transferable, prohibit new token creation.
   */
  function releaseTokenTransfer() public onlyReleaseAgent {
    mintingFinished = true;
    super.releaseTokenTransfer();
  }

  /**
   * Allow upgrade agent functionality to kick in only if the crowdsale was a success.
   * TODO: Are there any other conditions when giving out dividends? Perhaps we should stop all movements.
   */
  function canUpgrade() public constant returns(bool) {
    return released && super.canUpgrade();
  }

}