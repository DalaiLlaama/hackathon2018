package io.nuls.contract.token;

import io.nuls.contract.sdk.Address;
import io.nuls.contract.sdk.Contract;
import io.nuls.contract.sdk.Msg;
import io.nuls.contract.sdk.annotation.Required;
import io.nuls.contract.sdk.annotation.View;
import io.nuls.contract.sdk.Event;

import java.math.BigInteger;
import java.util.HashMap;
import java.util.Map;

import static io.nuls.contract.sdk.Utils.emit;
import static io.nuls.contract.sdk.Utils.require;

public class ReitDaoToken extends SimpleToken implements Contract {

	private BigInteger propNumber;
	private String addressHash;
	private boolean sold = false;
  private BigInteger soldValue;
  private Address owner;

  static final String TOKEN_NAME_PREFIX = "REIT_DAO_";
  static final String TOKEN_SYM_PREFIX = "REITDAO";

  @View
  public BigInteger propNumber() {
    return propNumber;
  }

  @View
  public String addressHash() {
    return addressHash;
  }

  @View
  public boolean sold() {
    return sold;
  }


  @View
  public BigInteger soldValue() {
    return soldValue;
  }

  @View
  public Address owner() {
    return owner;
  }

  public ReitDaoToken(@Required BigInteger propNumber, @Required BigInteger initialAmount, @Required String addressHash) {
      super(TOKEN_NAME_PREFIX+"000000"+propNumber, TOKEN_SYM_PREFIX+"0000000"+propNumber, initialAmount, 18);

      this.propNumber = propNumber;
      this.addressHash = addressHash;
      this.owner = Msg.sender();
  }

/*  private String formatName(String prefix, BigInteger seq) {
     String tmp = "00000000" + seq;
     String fmtNum = tmp.substring(tmp.length()-8);
     return fmtNum;
  } */

  public void sell(@Required BigInteger propValue) {
    require(Msg.sender() == owner);
    require(propValue.compareTo(BigInteger.ZERO)>0);

    this.soldValue = propValue;
    sold = true;

    // Calculate amount to return to owners

    // Revert to owners

    emit(new SoldEvent(propValue));
  }

  class SoldEvent implements Event {

      private BigInteger value;

      public SoldEvent(@Required BigInteger value) {
          this.value = value;
      }

      public BigInteger getValue() {
          return value;
      }

      public void setValue(BigInteger value) {
          this.value = value;
      }

      @Override
      public boolean equals(Object o) {
          if (this == o) return true;
          if (o == null || getClass() != o.getClass()) return false;

          SoldEvent that = (SoldEvent) o;

          return value != null ? value.equals(that.value) : that.value == null;
      }

      @Override
      public int hashCode() {
          int result = value != null ? value.hashCode() : 0;
          return result;
      }

      @Override
      public String toString() {
          return "SoldEvent{" +
                  "value=" + value +
                  '}';
      }
  }
}
