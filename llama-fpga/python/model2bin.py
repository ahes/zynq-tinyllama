import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import torch
from transformers.models.llama.modeling_llama import LlamaDecoderLayer, LlamaForCausalLM
from awq.modules.linear import WQLinear_GEMV

import numpy as np
import torch.nn


PAGE_SIZE = 8192
PACK_BUS_WIDTH = 512


def pack_int32_to_uint8(w):
    out_dim = w.shape[0]
    slice_list = []
    for i in range(8):
        slice = (w >> (i*4)) & 0x0f
        slice_list.append(slice.reshape([-1,1]))
    ret = np.concatenate(slice_list, axis=1).reshape([out_dim,-1])
    return ret


def allgather_roll(x, num_core:int, id:int):
    if num_core == 4:
        # print("all gather pass")
        return x
    else:
        roll_len = x.shape[-1] // num_core
        ret = np.roll(x, -id * roll_len, axis=-1)
        return ret


def pack_uint4_array(x):
    x = x.flatten()
    x = np.pad(x,[0, len(x) % 2 == 1])
    x = x.reshape([-1, 2])
    x = x[:, 0] + (x[:, 1] << 4)
    return x.flatten()


def pack_weight_scale_zero(q, s, z, bankLen:int):
    byte_cnt = bankLen // 2
    qPerS = byte_cnt * byte_cnt // 2
    q_bytes = pack_uint4_array(q).tobytes()
    s_bytes = s.tobytes()
    z_bytes = pack_uint4_array(z).tobytes()
    ret = b''
    z_index = 0
    s_index = 0
    q_index = 0
    for t in range(len(z_bytes) // byte_cnt):
        ret += z_bytes[z_index:z_index + byte_cnt]
        z_index += byte_cnt
        for i in range(16 // 4):
            ret += s_bytes[s_index:s_index + byte_cnt]
            s_index += byte_cnt
            ret += q_bytes[q_index:q_index + qPerS]
            q_index += qPerS
    return ret


def pack_uint4_array_fast(x):
    x = x.flatten()
    if len(x) % 2 == 1:
        x = np.pad(x, (0, 1))
    x = (x[::2] | (x[1::2] << 4))
    return x


def adapt_awq_linear(origin: WQLinear_GEMV):
    group = 128
    ret_in_features = (origin.in_features + group * 4 - 1) // (group * 4) * group * 4
    ret_out_features = (origin.out_features + group * 4 - 1) // (group * 4) * group * 4
    ret = WQLinear_GEMV(w_bit=4, group_size=group, in_features=ret_in_features, out_features=ret_out_features, bias=False, dev=origin.qweight.device)
    ret.qweight.data[:origin.qweight.shape[0], :origin.qweight.shape[1]] = origin.qweight
    ret.scales.data[:origin.scales.shape[0], :origin.scales.shape[1]] = origin.scales
    ret.qzeros.data[:origin.qzeros.shape[0], :origin.qzeros.shape[1]] = origin.qzeros
    return ret


def adapt_linear(origin: torch.nn.Linear):
    group = 128
    ret_in_features = (origin.in_features + group * 4 - 1) // (group * 4) * group * 4
    ret_out_features = (origin.out_features + group * 4 - 1) // (group * 4) * group * 4
    ret = torch.nn.Linear(ret_in_features, ret_out_features, bias=False, dtype=origin.weight.dtype)
    ret.weight.data.fill_(0)
    ret.weight.data[:origin.weight.shape[0], :origin.weight.shape[1]] = origin.weight
    return ret


def pack_weight_scale_zero_fast(q, s, z, bankLen: int):
    # AWQ groups contain 128 weights, while a 128-bit FPGA bank contains
    # 32. Repeat metadata for each physical bank without dropping weights.
    if s.shape != z.shape or q.shape[:-1] != s.shape[:-1] or q.shape[-1] % s.shape[-1]:
        raise ValueError('Incompatible dense weight/scale/zero shapes')
    quant_group = q.shape[-1] // s.shape[-1]
    if quant_group % bankLen:
        raise ValueError('Quantization group must contain whole FPGA banks')
    repeat = quant_group // bankLen
    s = np.repeat(s, repeat, axis=-1)
    z = np.repeat(z, repeat, axis=-1)
    byte_cnt = bankLen // 2
    qPerS = (byte_cnt * byte_cnt) // 2
    q_bytes = pack_uint4_array_fast(q).tobytes()
    s_bytes = s.tobytes()
    z_bytes = pack_uint4_array_fast(z).tobytes()
    total_size = (len(z_bytes) // byte_cnt) * (byte_cnt + 16 // 4 * (byte_cnt + qPerS))
    ret = bytearray(total_size)
    
    z_index = 0
    s_index = 0
    q_index = 0
    offset = 0
    
    for t in range(len(z_bytes) // byte_cnt):
        ret[offset:offset + byte_cnt] = z_bytes[z_index:z_index + byte_cnt]
        z_index += byte_cnt
        offset += byte_cnt
        for i in range(16 // 4):
            ret[offset:offset + byte_cnt] = s_bytes[s_index:s_index + byte_cnt]
            s_index += byte_cnt
            offset += byte_cnt
            ret[offset:offset + qPerS] = q_bytes[q_index:q_index + qPerS]
            q_index += qPerS
            offset += qPerS
    if q_index != len(q_bytes) or s_index != len(s_bytes) or z_index != len(z_bytes):
        raise ValueError('Dense packing did not consume every weight and metadata value')
    return bytes(ret)


def group_by(x, group):
    size = len(x)
    pad = (group - size % group) % group
    x = np.pad(x, [0, pad])
    x = x.reshape([-1, group])
    return x


def sparse_pack(z, s, busWidth: int):
    bank_len = busWidth // 4
    if 128 % bank_len:
        raise ValueError('128-element quantization group must contain whole FPGA banks')
    z = np.repeat(z, 128 // bank_len)
    s = np.repeat(s, 128 // bank_len)
    packCnt = busWidth // 20
    byteCnt = busWidth // 8
    z = np.frombuffer(z.tobytes(), dtype=np.uint32).astype(np.uint32)
    s = np.frombuffer(s.tobytes(), dtype=np.uint16).astype(np.uint32)
    pack = (s << 4) + z
    pack = group_by(pack, packCnt)
    total_bytes = byteCnt * pack.shape[0]
    ret = bytearray(total_bytes)
    for i in range(pack.shape[0]):
        x = 0
        for j in range(pack.shape[1]):
            x += int(pack[i][j]) << (j * 20)
        ret[i * byteCnt:(i + 1) * byteCnt] = x.to_bytes(byteCnt, 'little')
    
    return bytes(ret)


def dma_split_bytes(bytes, busWidth:int, split:int):
    byte_cnt  = busWidth // 8
    split_cnt = byte_cnt // split
    array = np.frombuffer(bytes, dtype=np.uint8).reshape([-1, split, split_cnt])
    array = array.transpose([1, 0, 2])
    return array.tobytes()


def pseudo_quantize_tensor_axpy(w: torch.Tensor, w_bit:int=4, group_size:int=128):
    w = w.T
    org_w_shape = w.shape
    w = w.reshape(-1, group_size)
    max_val = w.amax(dim=1, keepdim=True)
    min_val = w.amin(dim=1, keepdim=True)
    max_int = 2**w_bit - 1
    min_int = 0
    scales = (max_val - min_val).clamp(min=1e-5) / max_int
    zeros = (-torch.round(min_val / scales)).clamp_(min_int, max_int)
    w_uint = torch.clamp(torch.round(w / scales) + zeros, min_int, max_int)
    w = (w_uint - zeros) * scales
    zeros = zeros.view(org_w_shape[0], -1)
    scales = scales.view(org_w_shape[0], -1)
    w = w.reshape(org_w_shape)
    return w, w_uint.to(torch.uint8).reshape(org_w_shape), scales, zeros


def pseudo_quantize_tensor_dot(w: torch.Tensor, w_bit:int=4, group_size:int=128):
    org_w_shape = w.shape
    w = w.reshape(-1, group_size)
    max_val = w.amax(dim=1, keepdim=True)
    min_val = w.amin(dim=1, keepdim=True)
    max_int = 2**w_bit - 1
    min_int = 0
    scales = (max_val - min_val).clamp(min=1e-5) / max_int
    zeros = (-torch.round(min_val / scales)).clamp_(min_int, max_int)
    w_uint = torch.clamp(torch.round(w / scales) + zeros, min_int, max_int)
    w = (w_uint - zeros) * scales
    zeros = zeros.view(org_w_shape[0], -1)
    scales = scales.view(org_w_shape[0], -1)
    w = w.reshape(org_w_shape)
    return w, w_uint.to(torch.uint8).reshape(org_w_shape), scales, zeros


def quantize_dot_linear_for_export(linear: torch.nn.Linear,
                                   group_size: int = 128) -> WQLinear_GEMV:
    """Convert an FP linear to the exact GEMV container consumed by the packer.

    This deliberately uses deterministic per-output-channel min/max groups.  It
    avoids depending on an external AWQ checkpoint while preserving the same
    qweight/qzero/scales representation and therefore the same FPGA image layout.
    """
    if linear.in_features % group_size:
        raise ValueError(
            f"linear input {linear.in_features} is not divisible by group {group_size}"
        )
    _, qweight_u4, scales, zeros = pseudo_quantize_tensor_dot(
        linear.weight.data, w_bit=4, group_size=group_size
    )
    quantized = WQLinear_GEMV.from_linear(
        linear, w_bit=4, group_size=group_size,
        scales=scales, zeros=zeros
    )
    # WQLinear's converter rounds ``weight / scale + zero`` whereas the
    # validated reference rounds ``weight / scale`` before adding zero.  Pack
    # the already-computed nibbles explicitly so the exported image is bit-for-
    # bit the same quantizer that was exercised by software inference.
    nibbles = qweight_u4.to(torch.int64).reshape(linear.out_features, -1, 8)
    shifts = torch.arange(8, device=nibbles.device, dtype=torch.int64) * 4
    quantized.qweight = torch.sum(nibbles << shifts, dim=-1).to(torch.int32)
    return quantized


def prepare_fp_model_for_export(model: LlamaForCausalLM,
                                group_size: int = 128):
    """Quantize FPGA dot-product projections in-place from a trusted FP model."""
    projection_names = (
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj",
    )
    for layer_id, layer in enumerate(model.model.layers):
        for owner in (layer.self_attn, layer.mlp):
            for name in projection_names:
                if not hasattr(owner, name):
                    continue
                linear = getattr(owner, name)
                if not isinstance(linear, torch.nn.Linear):
                    raise TypeError(
                        f"layer {layer_id} {name} must be torch.nn.Linear, "
                        f"got {type(linear).__name__}"
                    )
                setattr(owner, name, quantize_dot_linear_for_export(linear, group_size))
        print(f"FP min/max quantization layer {layer_id} done.")


def pad_to_page_size(pack_bytes:bytearray, page_size:int):
    ret_size = ((len(pack_bytes) + page_size - 1) // page_size) * page_size
    return pack_bytes + bytearray(ret_size - len(pack_bytes))


def split_by_page_size(pack_bytes:bytearray, bus_width:int, dma_split:int, page_size:int):
    if dma_split == 1:
        return pad_to_page_size(pack_bytes, page_size)
    total_len = len(pack_bytes)
    split_cnt = int(math.ceil(total_len / page_size))
    ret = bytearray(split_cnt * page_size)
    for i in range(split_cnt - 1):
        sub_pack = pack_bytes[i * page_size:(i + 1) * page_size]
        sub_pack = dma_split_bytes(sub_pack, bus_width, dma_split)
        ret[i * page_size:(i + 1) * page_size] = sub_pack
    sub_pack = pack_bytes[(split_cnt - 1) * page_size:]
    sub_pack = dma_split_bytes(sub_pack, bus_width, dma_split)
    ret[(split_cnt - 1) * page_size:total_len] = sub_pack
    return ret


def split_by_manual(pack_bytes:bytearray, bus_width:int, dma_split:int, split:int):
    if dma_split == 1:
        return pack_bytes
    if split != 1:
        tot_len = len(pack_bytes)
        split_len = tot_len // split
        pack = b''
        for i in range(split):
            pack += dma_split_bytes(pack_bytes[split_len*i:split_len*(i+1)], bus_width, dma_split)
        ret = pack
    else:
        ret = dma_split_bytes(pack_bytes, bus_width, dma_split)
    return ret


class AttnQKVFromAWQ:
    def __init__(self, linear:WQLinear_GEMV, head:int, in_dim:int, out_dim:int, group:int, num_core:int, dma_split:list, cmd_split:int, scale_up:int):
        self.awq_linear = linear
        self.head = head
        self.head_dim = out_dim // head
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.cmd_split = cmd_split
        self.w_uint8 = pack_int32_to_uint8(self.awq_linear.qweight.cpu().numpy()).reshape([self.head, self.head_dim, -1]).astype(np.uint8)
        self.scale = self.awq_linear.scales.cpu().numpy().reshape([self.head, self.head_dim, -1]) * scale_up
        self.zero = pack_int32_to_uint8(self.awq_linear.qzeros.cpu().numpy()).reshape([self.head, self.head_dim, -1]).astype(np.uint8)
        self.pack_bytes = []
        for i in range(head):
            self.pack_bytes.append(self.pack_head_bytes(i))
        print("AttnQKVFromAWQ init done.")

    def pack_head_bytes(self, head_id:int):
        head_per_core = self.head // self.num_core
        id = head_id // head_per_core
        dma_split = self.dma_split[id]
        cmd_split = self.cmd_split
        bus_width = PACK_BUS_WIDTH
        w = allgather_roll(self.w_uint8[head_id], self.num_core, id)
        s = allgather_roll(self.scale[head_id], self.num_core, id)
        z = allgather_roll(self.zero[head_id], self.num_core, id)
        pack_bytes = pack_weight_scale_zero_fast(w, s, z, PACK_BUS_WIDTH // 4)
        # pack_bytes = split_by_manual(pack_bytes, bus_width, dma_split, cmd_split)
        pack_bytes = split_by_page_size(pack_bytes, bus_width, dma_split, PAGE_SIZE)
        return pack_bytes


class SplitDotFromAWQ:
    def __init__(self, linear:WQLinear_GEMV, in_dim:int, out_dim:int, group:int, num_core:int, dma_split:list, cmd_split:int, scale_up:int, is_out_proj: False):
        self.awq_linear = linear
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.cmd_split = cmd_split
        self.w_uint8 = pack_int32_to_uint8(self.awq_linear.qweight.cpu().numpy()).reshape([self.out_dim, self.num_core, -1]).astype(np.uint8)
        self.scale = self.awq_linear.scales.cpu().numpy().reshape([self.out_dim, self.num_core, -1]) * scale_up
        self.zero = pack_int32_to_uint8(self.awq_linear.qzeros.cpu().numpy()).reshape([self.out_dim, self.num_core, -1]).astype(np.uint8)
        if self.num_core == 4 and is_out_proj:
            self.w_uint8 = self.w_uint8.reshape([self.out_dim // self.num_core, self.num_core, self.num_core, -1]).transpose(1, 0, 2, 3).reshape([self.out_dim, self.num_core, -1])
            self.scale = self.scale.reshape([self.out_dim // self.num_core, self.num_core, self.num_core, -1]).transpose(1, 0, 2, 3).reshape([self.out_dim, self.num_core, -1])
            self.zero = self.zero.reshape([self.out_dim // self.num_core, self.num_core, self.num_core, -1]).transpose(1, 0, 2, 3).reshape([self.out_dim, self.num_core, -1])

        self.pack_bytes = []
        for i in range(num_core):
            self.pack_bytes.append(self.pack_core_bytes(i))
        print("SplitDotFromAWQ init done.")
    
    def pack_core_bytes(self, core_id:int):
        dma_split = self.dma_split[core_id]
        cmd_split = self.cmd_split
        bus_width = PACK_BUS_WIDTH
        pack_bytes = pack_weight_scale_zero_fast(self.w_uint8[:, core_id, :], self.scale[:, core_id, :], self.zero[:, core_id, :], PACK_BUS_WIDTH // 4)
        # pack_bytes = split_by_manual(pack_bytes, bus_width, dma_split, cmd_split)
        pack_bytes = split_by_page_size(pack_bytes, bus_width, dma_split, PAGE_SIZE)
        return pack_bytes


class SplitSparseDotFromAWQ:
    def __init__(self, linear:WQLinear_GEMV, in_dim:int, out_dim:int, group:int, num_core:int, dma_split:list, scale_up:int):
        self.awq_linear = linear
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.w_uint8 = pack_int32_to_uint8(self.awq_linear.qweight.cpu().numpy()).reshape([self.out_dim, self.num_core, -1]).astype(np.uint8)
        self.scale = self.awq_linear.scales.cpu().numpy().reshape([self.out_dim, self.num_core, -1]) * scale_up
        self.zero = pack_int32_to_uint8(self.awq_linear.qzeros.cpu().numpy()).reshape([self.out_dim, self.num_core, -1])
        self.pack_bytes = []
        for i in range(num_core):
            self.pack_bytes.append(self.pack_core_bytes(i))
        print("SplitSparseDotFromAWQ init done.")
    
    def pack_core_bytes(self, core_id:int):
        dma_split = self.dma_split[core_id]

        w_bytes = pack_uint4_array(self.w_uint8[0, 0, :]).tobytes()
        sz_bytes = sparse_pack(self.zero[0, 0, :], self.scale[0, 0, :], PACK_BUS_WIDTH)
        append_bytes = sz_bytes + w_bytes
        len_per_elem = len(append_bytes)
        total_len =  len_per_elem * self.out_dim
        pack = bytearray(total_len)

        offset = 0
        for l in range(self.out_dim):
            w_bytes = pack_uint4_array(self.w_uint8[l, core_id, :]).tobytes()
            sz_bytes = sparse_pack(self.zero[l, core_id, :], self.scale[l, core_id, :], PACK_BUS_WIDTH)
            append_bytes = sz_bytes + w_bytes
            pack[offset:offset+len_per_elem] = append_bytes
            offset += len_per_elem
        pack = split_by_page_size(pack, PACK_BUS_WIDTH, dma_split, PAGE_SIZE)
        return pack


class SplitSparseAxpy:
    def __init__(self, linear:torch.nn.Module, in_dim:int, out_dim:int, group:int, num_core:int, dma_split:list, scale_up:int):
        self.linear = linear
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.scale_up = scale_up
        weight_shape = linear.weight.data.shape
        # The historical four-way output-channel swizzle belongs to the
        # multi-core memory layout.  On the single-core 128-bit target the SG
        # lanes are already reassembled in channel order; applying it here
        # turns every MLP residual into [0,4,8,...,1,5,...] order.
        if num_core != 1:
            linear.weight.data = linear.weight.data.reshape(
                [-1, 4, weight_shape[1]]
            ).permute(1, 0, 2).reshape([-1, weight_shape[1]])
        w, self.w_uint8, self.scale, self.zero = pseudo_quantize_tensor_axpy(linear.weight.data)
        # if num_core != 4:
        self.w_uint8 = self.w_uint8.cpu().numpy().reshape([self.in_dim, self.num_core, -1])
        self.scale = self.scale.cpu().numpy().reshape([self.in_dim, self.num_core, -1]) * scale_up
        self.zero = self.zero.cpu().numpy().reshape([self.in_dim, self.num_core, -1]).astype(np.uint32)
        # else:
        #     self.w_uint8 = self.w_uint8.cpu().numpy().reshape([self.in_dim, -1, self.num_core])
        #     self.w_uint8 = self.w_uint8.transpose([0, 2, 1])
        #     self.scale = self.scale.cpu().numpy().reshape([self.in_dim, -1, self.num_core]) * scale_up
        #     self.scale = self.scale.transpose([0, 2, 1])
        #     self.zero = self.zero.cpu().numpy().reshape([self.in_dim, -1, self.num_core])
        #     self.zero = self.zero.transpose([0, 2, 1]).astype(np.uint32)
        self.pack_bytes = []
        for i in range(num_core):
            self.pack_bytes.append(self.pack_core_bytes(i))
        print("SplitSparseAxpy init done.")

    def pack_core_bytes(self, core_id:int):
        dma_split = self.dma_split[core_id]
        w_bytes = pack_uint4_array(self.w_uint8[0, 0, :]).tobytes()
        sz_bytes = sparse_pack(self.zero[0, 0, :], self.scale[0, 0, :], PACK_BUS_WIDTH)
        append_bytes = sz_bytes + w_bytes
        len_per_elem = len(append_bytes)
        total_len =  len_per_elem * self.out_dim
        pack = bytearray(total_len)

        offset = 0
        for l in range(self.in_dim):
            w_bytes = pack_uint4_array(self.w_uint8[l, core_id, :]).tobytes()
            sz_bytes = sparse_pack(self.zero[l, core_id, :], self.scale[l, core_id, :], PACK_BUS_WIDTH)
            append_bytes = sz_bytes + w_bytes
            pack[offset:offset+len_per_elem] = append_bytes
            offset += len_per_elem
        pack = split_by_page_size(pack, PACK_BUS_WIDTH, dma_split, PAGE_SIZE)
        return pack


class NormFromAWQ:
    def __init__(self, norm:torch.nn.Module, dim:int, group:int, num_core:int, dma_split:list, ext_scale:float=1.0):
        self.norm = norm
        self.dim = dim
        self.dma_split = dma_split
        self.scale = norm.weight.data.cpu().numpy().reshape([num_core, -1])
        self.scale = self.scale * ext_scale
        print(self.scale.dtype)
        self.scale_bytes = [s.tobytes() for s in self.scale]
        for c in range(num_core):
            if dma_split[c] != 1:
                self.scale_bytes[c] = pad_to_page_size(dma_split_bytes(self.scale_bytes[c], group * 4, dma_split[c]), PAGE_SIZE)
            else:
                self.scale_bytes[c] = pad_to_page_size(self.scale_bytes[c], PAGE_SIZE)
        print("NormFromAWQ init done.")


class AttnNormFromAWQ:
    def __init__(self, norm:torch.nn.Module, dim:int, group:int, num_core:int, dma_split:list, ext_scale:float=1.0):
        self.norm = norm
        self.dim = dim
        self.dma_split = dma_split
        self.scale = norm.weight.data.cpu().numpy()
        self.scale = self.scale * ext_scale
        print(self.scale.dtype)
        self.scale_bytes = [allgather_roll(self.scale, num_core, i).tobytes() for i in range(num_core)]
        for c in range(num_core):
            if dma_split[c] != 1:
                self.scale_bytes[c] = pad_to_page_size(dma_split_bytes(self.scale_bytes[c], group * 4, dma_split[c]), PAGE_SIZE)
            else:
                self.scale_bytes[c] = pad_to_page_size(self.scale_bytes[c], PAGE_SIZE)
        print("AttnNormFromAWQ init done.")


class LlammaLayerFromAWQ:
    def __init__(self, layer:LlamaDecoderLayer, group:int, num_core:int, dma_split:list, scale_up:int, attn_norm_scale:float=1.0):
        self.layer = layer
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.scale_up = scale_up
        layer_config = self.layer.self_attn.config
        self.head = getattr(
            self.layer.self_attn, "num_heads", layer_config.num_attention_heads
        )
        self.dim = getattr(layer, "hidden_size", layer_config.hidden_size)
        self.attnQKV_split = 2
        self.attnO_split = 2
        self.mlpG_split = 4

        self.attn_norm = AttnNormFromAWQ(self.layer.input_layernorm, self.dim, self.group, self.num_core, self.dma_split, attn_norm_scale)
        self.attnQ = AttnQKVFromAWQ(self.layer.self_attn.q_proj, self.head, self.dim, self.layer.self_attn.q_proj.out_features, self.group, self.num_core, self.dma_split, self.attnQKV_split, self.scale_up)
        self.attnK = AttnQKVFromAWQ(self.layer.self_attn.k_proj, self.head, self.dim, self.layer.self_attn.k_proj.out_features, self.group, self.num_core, self.dma_split, self.attnQKV_split, self.scale_up)
        self.attnV = AttnQKVFromAWQ(self.layer.self_attn.v_proj, self.head, self.dim, self.layer.self_attn.v_proj.out_features, self.group, self.num_core, self.dma_split, self.attnQKV_split, self.scale_up)
        self.attnO = SplitDotFromAWQ(self.layer.self_attn.o_proj, self.dim, self.layer.self_attn.o_proj.out_features, self.group, self.num_core, self.dma_split, self.attnO_split, self.scale_up, is_out_proj=True)
        self.mlp_norm = NormFromAWQ(self.layer.post_attention_layernorm, self.dim, self.group, self.num_core, self.dma_split)

        if num_core != 4:
            self.mlpU = SplitSparseDotFromAWQ(self.layer.mlp.up_proj, self.dim, self.layer.mlp.up_proj.out_features, self.group, self.num_core, self.dma_split, self.scale_up)
            self.mlpG = SplitDotFromAWQ(self.layer.mlp.gate_proj, self.dim, self.layer.mlp.gate_proj.out_features, self.group, self.num_core, self.dma_split, self.mlpG_split, self.scale_up, is_out_proj=False)
            self.mlpD = SplitSparseAxpy(self.layer.mlp.down_proj, self.layer.mlp.down_proj.in_features, self.dim, self.group, self.num_core, self.dma_split, self.scale_up)
        else:
            adapt_mlpU = adapt_awq_linear(self.layer.mlp.up_proj)
            adapt_mlpG = adapt_awq_linear(self.layer.mlp.gate_proj)
            adapt_mlpD = adapt_linear(self.layer.mlp.down_proj)
            self.mlpU = SplitSparseDotFromAWQ(adapt_mlpU, self.dim, adapt_mlpU.out_features, self.group, self.num_core, self.dma_split, self.scale_up)
            self.mlpG = SplitDotFromAWQ(adapt_mlpG, self.dim, adapt_mlpG.out_features, self.group, self.num_core, self.dma_split, self.mlpG_split, self.scale_up, is_out_proj=False)
            self.mlpD = SplitSparseAxpy(adapt_mlpD, adapt_mlpD.in_features, self.dim, self.group, self.num_core, self.dma_split, self.scale_up)

        print("--- Llama layer init done ---")


class LMHeadFromModel:
    def __init__(self, linear:torch.nn.Module, group:int, num_core:int, dma_split:list, cmd_split:int, scale_up:int):
        self.linear = linear
        self.in_dim = linear.in_features
        self.out_dim = linear.out_features
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.cmd_split = cmd_split
        self.scale_up = scale_up
        w, self.w_uint8, self.scale, self.zero = pseudo_quantize_tensor_dot(linear.weight.data)
        self.w_uint8 = self.w_uint8.cpu().numpy().reshape([self.out_dim, self.num_core, -1]).astype(np.uint8)
        self.scale = self.scale.cpu().numpy().reshape([self.out_dim, self.num_core, -1]) * scale_up
        self.zero = self.zero.cpu().numpy().reshape([self.out_dim, self.num_core, -1]).astype(np.uint8)
        self.pack_bytes = []
        for i in range(num_core):
            self.pack_bytes.append(self.pack_core_bytes(i))
        print("LMHeadFromModel init done.")

    def pack_core_bytes(self, core_id:int):
        dma_split = self.dma_split[core_id]
        cmd_split = self.cmd_split
        bus_width = PACK_BUS_WIDTH
        pack_bytes = pack_weight_scale_zero_fast(self.w_uint8[:, core_id, :], self.scale[:, core_id, :], self.zero[:, core_id, :], PACK_BUS_WIDTH // 4)
        # pack_bytes = split_by_manual(pack_bytes, bus_width, dma_split, cmd_split)
        pack_bytes = split_by_page_size(pack_bytes, bus_width, dma_split, PAGE_SIZE)
        return pack_bytes


class LlamaEmbedding:
    def __init__(self, embed:torch.nn.Embedding, group:int, num_core:int, dma_split:list):
        self.embed = embed
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.table = embed.weight.data.cpu().numpy()
        self.vocab_size = self.table.shape[0]
        if num_core != 4:
            self.pack = self.table.reshape([self.vocab_size, num_core, -1])
        else:
            self.pack = self.table.reshape([self.vocab_size, -1, num_core])
            self.pack = self.pack.transpose([0, 2, 1])
        self.pack_bytes = []
        self.len_per_token = len(self.pack[0][0].tobytes())
        self.total_len = self.len_per_token * self.vocab_size
        for c in range(num_core):
            ret = bytearray(self.total_len)
            offset = 0
            for i in range(self.vocab_size):
                append_bytes = self.pack[i][c].tobytes()
                if dma_split[c] != 1:
                    append_bytes = dma_split_bytes(append_bytes, group * 4, dma_split[c])
                ret[offset:offset+self.len_per_token] = append_bytes
                offset += self.len_per_token
            self.pack_bytes.append(ret)
        print("Embedding init done.")


class LlamaModelFromAWQ:
    def __init__(self, model:LlamaForCausalLM, group:int, num_core:int, dma_split:list, scale_up:int):
        self.model = model
        self.group = group
        self.num_core = num_core
        self.dma_split = dma_split
        self.scale_up = scale_up
        self.lmhead_split = 16
        self.head = model.config.num_attention_heads
        self.dim = model.lm_head.in_features
        self.head_dim = self.dim // self.head
        self.embed = LlamaEmbedding(model.model.embed_tokens, group, num_core, dma_split)
        self.norm = NormFromAWQ(model.model.norm, self.dim, group, num_core, dma_split)
        self.lmhead = LMHeadFromModel(model.lm_head, group, num_core, dma_split, self.lmhead_split, scale_up)
        self.layer = []
        self.total_layer = len(model.model.layers)
        kv_heads = getattr(model.config, "num_key_value_heads", self.head)
        if kv_heads != self.head:
            raise ValueError(
                f"FPGA layout requires full MHA ({self.head} KV heads), got "
                f"{kv_heads}. Run expand_gqa_to_mha.py before AWQ export."
            )
        if self.dim % (self.group * self.num_core) != 0:
            raise ValueError(
                f"hidden size {self.dim} must be divisible by "
                f"group*num_core={self.group * self.num_core}"
            )
        for i in range(self.total_layer):
            print(i)
            decode_layer = self.model.model.layers[i]
            attn_norm_scale = 1.0
            ret = LlammaLayerFromAWQ(decode_layer, group, num_core, dma_split, scale_up, attn_norm_scale)
            self.layer.append(ret)

    def gen_head_bin(self, max_token: int, layer_id: int, head_id: int):
        qkv_size = len(self.layer[layer_id].attnQ.pack_bytes[head_id])
        kv_cache_size = self.head_dim * max_token
        kv_cache_sz_size = 4 * max_token
        total_size = 3 * qkv_size + 2 * (kv_cache_size + kv_cache_sz_size)
        head_pack = bytearray(total_size)
        offset = 0
        head_pack[offset:offset + qkv_size] = self.layer[layer_id].attnQ.pack_bytes[head_id]
        offset += qkv_size
        head_pack[offset:offset + qkv_size] = self.layer[layer_id].attnK.pack_bytes[head_id]
        offset += qkv_size
        head_pack[offset:offset + qkv_size] = self.layer[layer_id].attnV.pack_bytes[head_id]
        offset += qkv_size
        head_pack[offset:offset + 2 * (kv_cache_size + kv_cache_sz_size)] = np.zeros(2 * (kv_cache_size + kv_cache_sz_size), dtype=np.uint8).tobytes()
        return head_pack
    
    def gen_layer_bin(self, max_token: int, layer_id: int, core_id:int):
        layer_pack = b''
        layer_pack += self.layer[layer_id].attn_norm.scale_bytes[core_id]
        head_per_core = self.head // self.num_core
        for h in range(head_per_core):
            head_id = core_id * head_per_core + h
            layer_pack += self.gen_head_bin(max_token, layer_id, head_id)
        layer_pack += self.layer[layer_id].attnO.pack_bytes[core_id]
        layer_pack += self.layer[layer_id].mlp_norm.scale_bytes[core_id]
        layer_pack += self.layer[layer_id].mlpG.pack_bytes[core_id]
        layer_pack += self.layer[layer_id].mlpU.pack_bytes[core_id]
        layer_pack += self.layer[layer_id].mlpD.pack_bytes[core_id]
        return layer_pack
    
    def gen_model_bin(self, max_token: int, core_id:int):
        model_pack = b''
        model_pack += self.embed.pack_bytes[core_id]
        for i in range(self.total_layer):
            model_pack += self.gen_layer_bin(max_token, i, core_id)
        model_pack += self.norm.scale_bytes[core_id]
        model_pack += self.lmhead.pack_bytes[core_id]
        return model_pack
    
    def gen_model_bin_first_half(self, max_token: int, core_id:int):
        model_pack = b''
        model_pack += self.embed.pack_bytes[core_id]
        for i in range(self.total_layer//2):
            model_pack += self.gen_layer_bin(max_token, i, core_id)
        return model_pack
    
    def gen_model_bin_second_half(self, max_token: int, core_id:int):
        model_pack = b''
        for i in range(self.total_layer//2, self.total_layer):
            model_pack += self.gen_layer_bin(max_token, i, core_id)
        model_pack += self.norm.scale_bytes[core_id]
        model_pack += self.lmhead.pack_bytes[core_id]
        return model_pack


def restore_fp_down_projections(model, fp_model_dir: Path):
    """Restore the FPGA-specific unquantized MLP down projections.

    AutoAWQ 0.2.9 cannot quantize with ``mlp.down_proj`` excluded because its
    Llama scaling recipe still indexes the excluded activation.  Loading the
    regular AWQ checkpoint and replacing exactly these tensors is equivalent
    to the exclusion used by the original gen_bin notebook.
    """
    from safetensors import safe_open

    checkpoint = fp_model_dir / "model.safetensors"
    if not checkpoint.is_file():
        raise FileNotFoundError(f"FP source checkpoint not found: {checkpoint}")

    with safe_open(str(checkpoint), framework="pt", device="cpu") as tensors:
        for layer_id, layer in enumerate(model.model.layers):
            key = f"model.layers.{layer_id}.mlp.down_proj.weight"
            weight = tensors.get_tensor(key)
            linear = torch.nn.Linear(
                weight.shape[1], weight.shape[0], bias=False, dtype=weight.dtype
            )
            linear.weight = torch.nn.Parameter(weight, requires_grad=False)
            layer.mlp.down_proj = linear


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def export_from_layout(quant_path: Path | None, fp_model_path: Path,
                       layout_path: Path, output_dir: Path,
                       source: str = "awq"):
    global PACK_BUS_WIDTH
    from awq import AutoAWQForCausalLM

    with layout_path.open("r", encoding="utf-8") as stream:
        layout = json.load(stream)

    packing = layout["packing"]
    model_layout = layout["model"]
    images = layout["images"]
    group = int(packing["quant_group"])
    num_core = int(packing["cores"])
    dma_split = [int(value) for value in packing["dma_split"]]
    PACK_BUS_WIDTH = int(packing.get("axi_bits", 512))
    max_tokens = int(model_layout["max_tokens"])

    supported_topology = ((num_core == 2 and dma_split == [4, 1] and PACK_BUS_WIDTH == 512) or
                          (num_core == 1 and dma_split == [1] and PACK_BUS_WIDTH == 128))
    if group != 128 or not supported_topology:
        raise ValueError(
            "Supported FPGA layouts are the legacy 2-core/512-bit [4,1] target "
            "and the Zynq-7035 1-core/128-bit [1] target; got "
            f"group={group}, cores={num_core}, axi_bits={PACK_BUS_WIDTH}, dma_split={dma_split}"
        )
    if len(images) != num_core:
        raise ValueError(f"layout has {len(images)} images for {num_core} cores")

    if source == "awq":
        if quant_path is None:
            raise ValueError("--quant-path is required when --source=awq")
        wrapper = AutoAWQForCausalLM.from_quantized(
            str(quant_path), fuse_layers=False, device_map={"": "cpu"},
            safetensors=True
        )
        model = wrapper.model
        restore_fp_down_projections(model, fp_model_path)
    elif source == "fp-minmax":
        model = LlamaForCausalLM.from_pretrained(
            str(fp_model_path), torch_dtype=torch.float16,
            device_map={"": "cpu"}, low_cpu_mem_usage=True
        )
        prepare_fp_model_for_export(model, group)
    else:
        raise ValueError(f"unsupported quantization source: {source}")
    config = model.config
    expected = {
        "num_hidden_layers": int(model_layout["layers"]),
        "hidden_size": int(model_layout["hidden_size"]),
        "num_attention_heads": int(model_layout["attention_heads"]),
        "num_key_value_heads": int(model_layout["kv_heads_after_expansion"]),
        "intermediate_size": int(model_layout["intermediate_size"]),
        "vocab_size": int(model_layout["vocab_size"]),
    }
    for name, value in expected.items():
        actual = int(getattr(config, name))
        if actual != value:
            raise ValueError(f"model {name}={actual}, layout requires {value}")

    packed = LlamaModelFromAWQ(model, group, num_core, dma_split, scale_up=4)
    output_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for core_id, image in enumerate(images):
        payload = packed.gen_model_bin(max_tokens, core_id)
        expected_size = image.get("size_bytes")
        if expected_size is not None and len(payload) != int(expected_size):
            raise ValueError(
                f"core {core_id} natural packed size is {len(payload)} bytes; "
                f"layout requires {expected_size}. Refusing to pad or truncate."
            )
        destination = output_dir / image["file"]
        temporary = destination.with_suffix(destination.suffix + ".tmp")
        with temporary.open("wb") as stream:
            stream.write(payload)
        os.replace(temporary, destination)
        results.append((destination, len(payload), sha256_file(destination)))
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Export TinyLlama weights to FPGA core images"
    )
    parser.add_argument(
        "--source", choices=("awq", "fp-minmax"), default="awq",
        help="use an AWQ checkpoint or deterministically quantize the FP model"
    )
    parser.add_argument("--quant-path", type=Path)
    parser.add_argument("--fp-model-path", type=Path, required=True)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    results = export_from_layout(
        args.quant_path, args.fp_model_path, args.layout, args.output_dir,
        source=args.source
    )
    for path, size, digest in results:
        print(f"{path}: {size} bytes, SHA-256 {digest}")


if __name__ == "__main__":
    main()
