package util

import spinal.core._

/** Binary16 power-of-two scaling with signed zero, subnormals and RNE restore.
  * NaN payloads and infinities pass through; finite overflow becomes infinity.
  */
object Fp16Pow2 {
  def apply(src: Bits, shift: Int): Bits = {
    require(src.getWidth == 16 && shift >= -8 && shift <= 8)
    if (shift == 0) src else {
      val out = Bits(16 bits)
      out := src
      val exponent = src(14 downto 10).asUInt
      val fraction = src(9 downto 0).asUInt
      if (shift > 0) {
        val nextExponent = exponent.resize(6) + shift
        when(exponent =/= 31) {
          out := src.msb ## nextExponent.resize(5).asBits ## fraction.asBits
          when(nextExponent >= 31) { out := src.msb ## B(0x7c00, 15 bits) }
          when(exponent === 0) {
            val shifted = fraction.resize(10 + shift) |<< shift
            out := src.msb ## B(0, 5 bits) ## shifted.resize(10).asBits
            // Higher set bits override lower ones, yielding normalized exponent.
            for (bit <- 0 until 10 if bit + shift >= 10) {
              when(fraction(bit)) {
                out := src.msb ## B(bit + shift - 9, 5 bits) ##
                  (shifted >> (bit + shift - 10)).resize(10).asBits
              }
            }
          }
        }
      } else {
        val right = -shift
        def rounded(mantissa: UInt, amount: Int): Bits = {
          val quotient = (mantissa >> amount).resize(12)
          val sticky = if (amount == 1) False else mantissa(amount - 2 downto 0).orR
          val increment = mantissa(amount - 1) && (sticky || quotient(0))
          (quotient + increment.asUInt.resize(12)).asBits.resize(15)
        }
        when(exponent =/= 31) {
          out := src.msb ## (exponent - right).resize(5).asBits ## fraction.asBits
          when(exponent === 0) { out := src.msb ## rounded(fraction.resize(11), right) }
          for (exp <- 1 to right) {
            when(exponent === exp) {
              // A carry to bit10 represents the smallest normal number.
              out := src.msb ## rounded((U(1, 1 bits) ## fraction.asBits).asUInt, right + 1 - exp)
            }
          }
        }
      }
      out
    }
  }

  def vec(src: Bits, shift: Int): Bits = Vec(src.subdivideIn(16 bits).map(apply(_, shift))).asBits
}
