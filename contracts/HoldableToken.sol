pragma solidity ^0.4.13;

import './ERC20Basic.sol';
import './Burnable.sol';
import './SafeMath.sol';

/**
 * @title Holdable Token
 * @dev Implementation of the simplified interface in ERC20Basic that provides an incentive to hold tokens for a time after the crowdsale ends. 
 */
contract HoldableToken is ERC20Basic, Burnable {
  using SafeMath for uint;

  uint public constant payments = 14;
  uint public constant blocksBetweenPayments = 25200;

  uint[] public heldTokensPerPayday;
  uint public loyalty_program_paid = 0;
  uint public end;
  address public crowdsale;


  struct Contributor {
    uint primaryBalance;
    uint secondaryBalance;
    uint nextPayday;
  }

  mapping(address => Contributor) public contributors;


  function HoldableToken(uint crowdsale_end) internal {
    heldTokensPerPayday.push(0);
    end = crowdsale_end;
    crowdsale = msg.sender;
  }


  /**
   * @dev transfer tokens to a specified address.
   * @param destination The address to transfer to.
   * @param value The amount to be transferred.
   * @return true on success
   */
  function transfer(address destination, uint value) public returns (bool success) {
    bool result = internalTransfer(msg.sender, destination, value);
    Transfer(msg.sender, destination, value);
    return result;
  }


  /**
   * @dev Gets the balance of the specified address.
   * @param account The address to query the balance of.
   * @return An uint representing the amount owned by the passed address.
   */
  function balanceOf(address account) public constant returns(uint) {
    uint revenue = pendingRevenue(account);
    uint balance = revenue.add(contributors[account].secondaryBalance).add(contributors[account].primaryBalance);
    return balance;
  }

  /**
   * @dev Amount of revenue that is divided among loyal token holders each payday.
   * @return Revenue corresponding to a payday.
   */
  function revenuePerPayday() internal returns (uint);

  /**
   * @dev Calculates the revenue that corresponds to this account since the last transfer.
   * @param account Address to be checked.
   * @return Revenue in tokens for the account since the last transfer.
   */
  function pendingRevenue(address account) private constant returns(uint) {
    if (contributors[account].primaryBalance == 0)
      return 0;
    // The current token holder having a primary balance greater than zero implies
    //  that the total held tokens is greater than zero
    uint curPayday = currentPayday();
    uint revenue = 0;
    uint heldTokens;
    uint nextPayday = contributors[account].nextPayday.max256(1);
    // The nextPayday always maps to a valid index in the heldTokensPerPayday dynamic array.
    // This guarantees that heldTokens is initialized in the first iteration at least.
    assert(nextPayday - 1 < heldTokensPerPayday.length);

    for (uint i = nextPayday; i <= curPayday; i++) {
      uint index = i - 1;
      heldTokens = index < heldTokensPerPayday.length ? heldTokensPerPayday[index] : heldTokens;
      // Warning: overflow in the multiplication will block all operations for the account
      // The magnitude of the revenue per payday should be chosen to guarantee the safety of all operations.
      // E.g. if the revenue is taken out of an initial pool of 10^23 units, all operations are safe since
      // 10^23 * 10^23 = 10^46 < 10^77 ~= 2^256
      // heldTokens can't be zero as long as this contributor has a primary balance higher than zero.
      uint pay = contributors[account].primaryBalance.mul(revenuePerPayday()).div(heldTokens);
      revenue = pay.add(revenue);
    }
    return revenue;
  }

  /**
   * @dev Calculates the current payday.
   * @return Current payday.
   * Token balances should reflect the extra tokens for each token held during paydays including the current one.
   */
  function currentPayday() private constant returns (uint) {
    // Return zero if the crowdsale didn't finish yet.
    if (block.number <= end || end == 0) return 0;
    uint curPayday = block.number.sub(end).div(blocksBetweenPayments);
    // Cap the payday at the amount of payments
    curPayday = curPayday.min256(payments);
    return curPayday;
  }

  function internalTransfer(address source, address destination, uint value) internal returns (bool success) {
    require(balanceOf(source) >= value);
    // From this point on we know that the source account has enough tokens for the transfer.

    // Special case: the source is the crowdsale distributing tokens that may be held by loyal supporters
    if ((source == crowdsale) && (block.number <= end)) {
      contributors[crowdsale].secondaryBalance = contributors[crowdsale].secondaryBalance.sub(value);
      contributors[destination].primaryBalance = contributors[destination].primaryBalance.add(value);
      heldTokensPerPayday[0] = heldTokensPerPayday[0].add(value);
      return true;
    }

    updateBalance(source);
    uint secondaryBalance = contributors[source].secondaryBalance;

    if (secondaryBalance < value) {
      uint spentInitialTokens = value.sub(secondaryBalance);
      contributors[source].secondaryBalance = 0;
      contributors[source].primaryBalance = contributors[source].primaryBalance.sub(spentInitialTokens);
      uint curPayday = currentPayday();

      updatePaydayAmounts(curPayday);

      heldTokensPerPayday[curPayday] = heldTokensPerPayday[curPayday].sub(spentInitialTokens);
    } else {
      contributors[source].secondaryBalance = secondaryBalance.sub(value);
      contributors[destination].secondaryBalance = contributors[destination].secondaryBalance.add(value);
    }

    return true;
  }

  /**
   * @dev Updates the balance of an account by transferring to it tokens from the loyalty program if it corresponds.
   * @param account Balance of this address will be updated 
   */
  function updateBalance(address account) private {
    uint revenue = pendingRevenue(account);
    // If the token holder has pending revenue we transfer the corresponding tokens to his account
    if (revenue > 0) {
      internalTransfer(address(this), account, revenue);
      contributors[account].nextPayday = currentPayday().add(1);
      loyalty_program_paid = loyalty_program_paid.add(revenue);
      Transfer(address(this), account, revenue);
    }
  }
  
  /**
   * @dev Updates the amount of primary tokens held until each payday
   * @param curPayday The current payday
   */
  function updatePaydayAmounts(uint curPayday) private {
    if (curPayday == 0) return;
    uint heldTokens = heldTokensPerPayday[heldTokensPerPayday.length.sub(1)];
    for (uint i = heldTokensPerPayday.length; i < curPayday.sub(1); i++) {
      heldTokensPerPayday.push(heldTokens);
    }
  }

  /**
   * Internal function for destroying tokens.
   */
  function burnTokens(address account, uint value) internal {
    internalTransfer(account, address(this), value);
    contributors[address(this)].secondaryBalance = contributors[address(this)].secondaryBalance.sub(value);
    Burned(account, value);
  }

}