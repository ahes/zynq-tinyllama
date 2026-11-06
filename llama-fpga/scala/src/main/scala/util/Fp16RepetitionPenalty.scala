package util

import spinal.core._

/** Binary16 repetition penalty 9/8, rounded once to nearest, ties to even.
  * Positive logits divide by 9/8; negative logits multiply by 9/8.
  * Signed zero, subnormals and NaN payloads are preserved as IEEE operands.
  * Combinational integer arithmetic avoids another floating-point IP core.
  */
object Fp16RepetitionPenalty {
  def apply(src: Bits): Bits = {
    require(src.getWidth == 16)
    val exponent = src(14 downto 10).asUInt
    val fraction = src(9 downto 0).asUInt
    val mantissa = UInt(11 bits)
    mantissa := ((exponent =/= 0).asBits ## fraction.asBits).asUInt
    val out = Bits(16 bits)
    out := src
    val magnitude = UInt(15 bits)
    magnitude := src(14 downto 0).asUInt

    def rne(value: UInt, shift: Int): UInt = {
      val quotient = (value >> shift).resize(12)
      val sticky = if (shift == 1) False else value(shift-2 downto 0).orR
      quotient + (value(shift-1) && (sticky || quotient(0))).asUInt.resize(12)
    }

    when(exponent =/= 31) {
      when(src.msb) {
        val numerator = (mantissa.resize(15) |<< 3) + mantissa.resize(15)
        val roundedLow = rne(numerator, 3)
        val roundedHigh = rne(numerator, 4)
        val nextExponent = exponent.resize(6) + 1
        when(exponent === 0) {
          magnitude := roundedLow.resize(15)
        } otherwise {
          magnitude := (exponent.asBits ## roundedLow.resize(10).asBits).asUInt
          when(numerator >= 16384) {
            magnitude := (nextExponent.resize(5).asBits ## roundedHigh.resize(10).asBits).asUInt
          } elsewhen(roundedLow >= 2048) {
            magnitude := (nextExponent.resize(5).asBits ## B(0, 10 bits)).asUInt
          }
          when(exponent === 30 && (numerator >= 16384 || roundedLow >= 2048)) {
            magnitude := U(0x7c00, 15 bits)
          }
        }
      } otherwise {
        val numerator = mantissa.resize(16) |<< 3
        val roundedLow = ((numerator + 4) / U(9, 16 bits)).resize(12)
        val roundedHigh = (((mantissa.resize(16) |<< 4) + 4) / U(9, 16 bits)).resize(12)
        when(exponent === 0 || (exponent === 1 && mantissa < 1152)) {
          magnitude := roundedLow.resize(15)
        } otherwise {
          magnitude := (exponent.asBits ## roundedLow.resize(10).asBits).asUInt
          when(mantissa < 1152) {
            magnitude := ((exponent - 1).asBits ## roundedHigh.resize(10).asBits).asUInt
            when(roundedHigh >= 2048) {
              magnitude := (exponent.asBits ## B(0, 10 bits)).asUInt
            }
          }
        }
      }
      out := src.msb ## magnitude.asBits
    }
    out
  }
}
