package top

import spinal.core._

object CoreSoftReset {
  // The AXI-Lite controller stays on external reset. Reset only the compute
  // domain and its DMA so register access and reset-pulse generation survive.
  def synchronousResetN(externalResetN: Bool, request: Bool, requestActiveLow: Boolean): Bool = {
    val inactive = if (requestActiveLow) request else !request
    externalResetN && inactive
  }
}
